/* 자동 채보 초안: 오디오 분석(onset/세기/음색) → BPM·첫 박 추정 → 난이도별 노트 생성.
 * 결과는 "고쳐 쓰라고 주는 초안"이다. DOM 에 의존하지 않는다 (core_tests.js 에서 합성 신호로 검증).
 * 시간: 분석은 오디오 시각(ms), 생성 결과는 곡 시간(ms) = 오디오 시각 + meta.offset. */
(function (root) {
  'use strict';
  const { K, clamp, fieldAt } = root.Core;

  const HOP_MS = 10;
  const FFT_N = 1024;
  const LOW_HZ = 200;

  // 난이도 프리셋. div = 격자(1/div 음표), nps = 초당 노트 목표, chord = 동시치기 비율, holdBeats = 홀드로 바꿀 최소 빈 박,
  // width = Field 폭, fieldBars = Field 길이(마디), flicksPerBar = Field 안 플릭 밀도, keyBeats = Field 키프레임 간격(박), step = 키 사이 최대 이동
  const PRESET = {
    EZ: { div: 4, nps: 1.4, minGap: 1, chord: 0, holdBeats: 2.5, width: 0.36, fieldBars: 4, cooldownBars: 4, flicksPerBar: 0.25, keyBeats: 2, step: 0.12 },
    NM: { div: 8, nps: 2.8, minGap: 1, chord: 0.07, holdBeats: 2, width: 0.28, fieldBars: 2, cooldownBars: 2, flicksPerBar: 1, keyBeats: 1, step: 0.15 },
    HD: { div: 16, nps: 4.6, minGap: 2, chord: 0.14, holdBeats: 2, width: 0.22, fieldBars: 2, cooldownBars: 2, flicksPerBar: 1.5, keyBeats: 1, step: 0.2 },
  };

  /* ---------------- 분석 ---------------- */
  function fft(re, im) {
    const n = re.length;
    for (let i = 1, j = 0; i < n; i++) {
      let bit = n >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) { let t = re[i]; re[i] = re[j]; re[j] = t; t = im[i]; im[i] = im[j]; im[j] = t; }
    }
    for (let len = 2; len <= n; len <<= 1) {
      const ang = (-2 * Math.PI) / len, wr = Math.cos(ang), wi = Math.sin(ang);
      for (let i = 0; i < n; i += len) {
        let cr = 1, ci = 0;
        for (let k = 0; k < len / 2; k++) {
          const a = i + k, b = a + len / 2;
          const tr = re[b] * cr - im[b] * ci, ti = re[b] * ci + im[b] * cr;
          re[b] = re[a] - tr; im[b] = im[a] - ti; re[a] += tr; im[a] += ti;
          const nr = cr * wr - ci * wi; ci = cr * wi + ci * wr; cr = nr;
        }
      }
    }
  }

  /** channels = [Float32Array...] (AudioBuffer.getChannelData). 프레임(10ms)마다 onset 세기/저음 onset/음량/음색 중심. */
  function analyze(channels, sampleRate) {
    const ds = Math.max(1, Math.round(sampleRate / 22050));
    const sr = sampleRate / ds;
    const n = Math.floor(channels[0].length / ds);
    const x = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      let s = 0;
      for (const ch of channels) for (let k = 0; k < ds; k++) s += ch[i * ds + k];
      x[i] = s / (ds * channels.length);
    }
    const hop = (sr * HOP_MS) / 1000;
    const frames = Math.max(0, Math.floor((n - FFT_N) / hop) + 1);
    const win = new Float32Array(FFT_N);
    for (let i = 0; i < FFT_N; i++) win[i] = 0.5 - 0.5 * Math.cos((2 * Math.PI * i) / (FFT_N - 1));
    const half = FFT_N / 2, lowK = Math.max(2, Math.round((LOW_HZ * FFT_N) / sr));
    const re = new Float32Array(FFT_N), im = new Float32Array(FFT_N);
    let prev = new Float32Array(half), cur = new Float32Array(half);
    const prevLow = new Float32Array(half); // 저음은 로그가 아닌 실제 세기 변화로 본다 (넓은 대역 잡음에 덜 섞이게)
    const onset = new Float32Array(frames), low = new Float32Array(frames), rms = new Float32Array(frames), centroid = new Float32Array(frames);
    for (let f = 0; f < frames; f++) {
      const o = Math.floor(f * hop);
      let e = 0;
      for (let i = 0; i < FFT_N; i++) { const v = x[o + i]; e += v * v; re[i] = v * win[i]; im[i] = 0; }
      rms[f] = Math.sqrt(e / FFT_N);
      fft(re, im);
      let flux = 0, lflux = 0, num = 0, den = 0;
      for (let k = 1; k < half; k++) {
        const m = Math.hypot(re[k], im[k]);
        const lm = Math.log1p(100 * m);
        cur[k] = lm;
        const d = lm - prev[k];
        if (d > 0) flux += d;
        if (k < lowK) { if (m > prevLow[k]) lflux += m - prevLow[k]; prevLow[k] = m; }
        num += k * m; den += m;
      }
      onset[f] = flux; low[f] = lflux; centroid[f] = den > 0 ? num / den : 0;
      const t = prev; prev = cur; cur = t;
    }
    const novelty = detrend(onset, 50), lowN = detrend(low, 50);
    // 박 찾기용 곡선: 전체 onset + 저음 onset(킥/베이스) 가중. 하이햇 엇박에 위상이 끌려가지 않게
    const mN = avgOf(novelty) || 1, mL = avgOf(lowN) || 1;
    const beatCurve = new Float32Array(frames);
    for (let i = 0; i < frames; i++) beatCurve[i] = novelty[i] / mN + (1.5 * lowN[i]) / mL;
    return { hopMs: HOP_MS, delayMs: ((FFT_N / 2) / sr) * 1000, frames, onset, novelty, low: lowN, beatCurve, rms, centroid, durationMs: (n / sr) * 1000 };
  }

  const avgOf = (a) => { let s = 0; for (const v of a) s += v; return a.length ? s / a.length : 0; };

  /** 이동 평균(±w 프레임)을 빼고 음수는 0 → 배경 소음에 덜 휘둘리는 onset 곡선 */
  function detrend(a, w) {
    const out = new Float32Array(a.length);
    let sum = 0, lo = 0, hi = -1;
    for (let i = 0; i < a.length; i++) {
      while (hi < Math.min(a.length - 1, i + w)) sum += a[++hi];
      while (lo < i - w) sum -= a[lo++];
      out[i] = Math.max(0, a[i] - sum / (hi - lo + 1));
    }
    return out;
  }

  /** 오디오 시각(ms)의 곡선 값 (선형 보간) */
  function at(arr, f, ms) {
    const p = (ms - f.delayMs) / f.hopMs;
    const i = Math.floor(p);
    if (i < 0 || i + 1 >= arr.length) return 0;
    return arr[i] + (arr[i + 1] - arr[i]) * (p - i);
  }
  /** [ms-r, ms+r] 구간 최댓값 */
  function peak(arr, f, ms, r) {
    const a = Math.max(0, Math.floor((ms - r - f.delayMs) / f.hopMs)), b = Math.min(arr.length - 1, Math.ceil((ms + r - f.delayMs) / f.hopMs));
    let m = 0;
    for (let i = a; i <= b; i++) if (arr[i] > m) m = arr[i];
    return m;
  }
  function mean(arr, f, ms0, ms1) {
    const a = Math.max(0, Math.floor((ms0 - f.delayMs) / f.hopMs)), b = Math.min(arr.length - 1, Math.floor((ms1 - f.delayMs) / f.hopMs));
    if (b < a) return 0;
    let s = 0;
    for (let i = a; i <= b; i++) s += arr[i];
    return s / (b - a + 1);
  }

  /* ---------------- BPM / 첫 박 ---------------- */
  /** 박 간격 P(ms)의 빗(comb) 점수: 가장 잘 맞는 위상에서 박 위치 onset 평균. */
  function comb(f, P, phaseStep) {
    let best = 0, bestPh = 0;
    const end = f.durationMs - f.delayMs;
    for (let ph = 0; ph < P; ph += phaseStep) {
      let s = 0, c = 0;
      for (let t = ph; t < end; t += P) { s += at(f.beatCurve, f, t); c++; }
      const v = c ? s / c : 0;
      if (v > best) { best = v; bestPh = ph; }
    }
    return [best, bestPh];
  }

  // 리듬게임 곡은 빠른 편이라 150 근처를 선호 (반 템포로 잘못 읽는 것 방지)
  const tempoPrior = (bpm) => Math.exp(-0.5 * Math.pow(Math.log2(bpm / 150) / 0.8, 2));

  /** 반환: { bpm, firstBeatMs(오디오 시각, 마디 첫 박), confidence }. fixedBpm 을 주면 BPM 은 그대로 두고 첫 박만 찾는다. */
  function estimateTempo(f, fixedBpm) {
    let best = { score: -1 };
    if (fixedBpm > 0) best = { score: comb(f, 60000 / fixedBpm, 10)[0], bpm: fixedBpm };
    else {
      for (let bpm = 60; bpm <= 230; bpm += 0.5) {
        const [s] = comb(f, 60000 / bpm, 10);
        if (s * tempoPrior(bpm) > best.score) best = { score: s * tempoPrior(bpm), bpm };
      }
      for (let bpm = best.bpm - 0.5; bpm <= best.bpm + 0.5; bpm += 0.02) {
        const [s] = comb(f, 60000 / bpm, 2);
        if (s * tempoPrior(bpm) > best.score) best = { score: s * tempoPrior(bpm), bpm };
      }
    }
    const bpm = fixedBpm > 0 ? fixedBpm : Math.abs(best.bpm - Math.round(best.bpm)) < 0.08 ? Math.round(best.bpm) : Math.round(best.bpm * 100) / 100;
    const P = 60000 / bpm;
    const [, ph] = comb(f, P, 1);
    // 마디 첫 박: 4가지 위상 중 저음 onset 이 가장 센 것
    let bar = 0, barScore = -1;
    for (let j = 0; j < 4; j++) {
      let s = 0;
      for (let t = ph + j * P; t < f.durationMs; t += 4 * P) s += peak(f.low, f, t, 20);
      if (s > barScore) { barScore = s; bar = j; }
    }
    const avg = avgOf(f.beatCurve);
    return { bpm, firstBeatMs: (ph + bar * P) % (4 * P), confidence: avg > 0 ? best.score / avg : 0 };
  }

  /* ---------------- 생성 ---------------- */
  function rng(seed) { // mulberry32
    let a = seed >>> 0;
    return () => { a = (a + 0x6d2b79f5) >>> 0; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  function percentile(vals, p) {
    if (!vals.length) return 0;
    const s = [...vals].sort((a, b) => a - b);
    return s[Math.min(s.length - 1, Math.floor(p * s.length))];
  }

  /**
   * f = analyze() 결과, timing = Core.Timing, offset = meta.offset.
   * opts: { diff:'EZ'|'NM'|'HD', from, to (곡 시간 ms), air: bool, density: 배율(1 = 기본), seed }
   * 반환: { notes, level, nps }
   */
  function generate(f, timing, offset, opts) {
    const P = PRESET[opts.diff] || PRESET.NM;
    const R = rng(opts.seed || 1);
    const audioEnd = f.durationMs + offset - 300;
    const from = Math.max(0, opts.from || 0), to = Math.min(opts.to == null ? Infinity : opts.to, audioEnd);
    const notes = [];
    if (!(to > from)) return { notes, level: 1, nps: 0 };
    const A = (t) => t - offset; // 곡 시간 → 오디오 시각

    // 1) 격자 칸마다 onset 세기. 마디 첫 박/박/8분/16분 순으로 가중치
    const slots = timing.gridLines(from, to, P.div).map((g) => {
      const seg = timing.segment(g.t), beat = 60000 / seg.bpm, pos = ((g.t - seg.start) / beat) % 1;
      const eighth = Math.abs(pos - 0.5) < 0.01;
      const w = g.strong ? 1.25 : g.onBeat ? 1.1 : eighth ? 0.95 : 0.78;
      return { t: g.t, beat, onBeat: g.onBeat, raw: peak(f.novelty, f, A(g.t), 30), w };
    });
    const p95 = percentile(slots.map((s) => s.raw), 0.95) || 1;
    // 조용한 구간도 비지 않게: 주변 ±4초 최댓값과 전체 기준을 섞어 정규화
    for (let i = 0, lo = 0, hi = 0; i < slots.length; i++) {
      while (slots[lo].t < slots[i].t - 4000) lo++;
      while (hi + 1 < slots.length && slots[hi + 1].t <= slots[i].t + 4000) hi++;
      let lm = 0;
      for (let k = lo; k <= hi; k++) lm = Math.max(lm, slots[k].raw);
      slots[i].s = (slots[i].raw / (0.6 * lm + 0.4 * p95 + 1e-9)) * slots[i].w;
      slots[i].i = i;
    }

    // 2) 센 칸부터 고르기 (목표 개수, 최소 간격)
    const target = Math.round(((to - from) / 1000) * P.nps * (opts.density || 1));
    const taken = new Uint8Array(slots.length);
    const picked = [];
    for (const s of [...slots].sort((a, b) => b.s - a.s)) {
      if (picked.length >= target || s.s < 0.12) break;
      const gap = s.s > 0.85 ? 1 : P.minGap;
      let ok = true;
      for (let k = Math.max(0, s.i - gap + 1); k <= Math.min(slots.length - 1, s.i + gap - 1); k++) if (taken[k]) { ok = false; break; }
      if (!ok) continue;
      taken[s.i] = 1; picked.push(s);
    }
    picked.sort((a, b) => a.t - b.t);

    // 3) 레인: 음색이 밝을수록 오른쪽. 같은 레인 연타는 피하고, 홀드 중인 레인은 비운다
    const cents = picked.map((s) => peak(f.centroid, f, A(s.t), 20));
    const sortedC = [...cents].sort((a, b) => a - b);
    const rank = (c) => (sortedC.length > 1 ? sortedC.findIndex((v) => v >= c) / (sortedC.length - 1) : 0.5);
    const chordCut = P.chord ? percentile(picked.map((s) => s.s), 1 - P.chord) : Infinity;
    const busy = [-1, -1, -1, -1];
    let prevLane = -1, prevT = -1e9;
    const recent = []; // 최근 레인 — 한쪽에 몰리지 않게
    picked.forEach((s, i) => {
      const t = Math.round(s.t);
      const desired = clamp(Math.round(rank(cents[i]) * 3 + (R() < 0.3 ? (R() < 0.5 ? -1 : 1) : 0)), 0, 3);
      const free = [0, 1, 2, 3].filter((l) => busy[l] < t);
      if (!free.length) return;
      const gap = t - prevT;
      const score = (l) => -Math.abs(l - desired) + (l === prevLane ? (gap < s.beat * 0.75 ? -10 : -1.5) : 0)
        - 0.3 * recent.filter((x) => x === l).length + R() * 0.6;
      const lane = free.reduce((a, b) => (score(b) > score(a) ? b : a));
      // 홀드: 다음 노트까지 충분히 비고 소리가 이어지면
      const next = picked[i + 1];
      const nextT = next ? next.t : to;
      const level0 = peak(f.rms, f, A(t), 30);
      if (nextT - t >= P.holdBeats * s.beat && level0 > 0 && mean(f.rms, f, A(t), A(nextT - s.beat * 0.5)) >= 0.55 * level0) {
        const end = Math.round(timing.snap(nextT - s.beat * 0.5, P.div));
        if (end - t >= s.beat * 0.5) {
          notes.push({ type: 'hold', time: t, end, lane });
          busy[lane] = end;
        } else notes.push({ type: 'tap', time: t, lane });
      } else notes.push({ type: 'tap', time: t, lane });
      if (s.s >= chordCut && s.onBeat) {
        const other = [0, 1, 2, 3].filter((l) => l !== lane && busy[l] < t).sort((a, b) => Math.abs(b - lane) - Math.abs(a - lane))[0];
        if (other != null) notes.push({ type: 'tap', time: t, lane: other });
      }
      if (busy[lane] < t) busy[lane] = t;
      prevLane = lane; prevT = t;
      recent.push(lane); if (recent.length > 6) recent.shift();
    });

    // 4) 공중: 시끄러운 마디에 Field, 그 안의 센 박에 Flick
    if (opts.air) addAir(f, timing, P, R, A, from, to, slots, notes);

    const nps = notes.filter((n) => n.type !== 'field').length / Math.max(1, (to - from) / 1000);
    return { notes, nps, level: clamp(Math.round(nps * 2.4 + (opts.air ? 0.5 : 0)), 1, 15) };
  }

  function addAir(f, timing, P, R, A, from, to, slots, notes) {
    const bars = timing.gridLines(from, to, 1).map((g) => g.t);
    if (bars.length < P.fieldBars + 1) return;
    const loud = bars.slice(0, -1).map((t, i) => mean(f.rms, f, A(t), A(bars[i + 1])));
    const thresh = percentile(loud, 0.6) * 0.95; // 음량이 고른 곡이면 대부분 후보
    const cents = [];
    for (let t = from; t <= to; t += 250) cents.push(at(f.centroid, f, A(t)));
    const cs = [...cents].sort((a, b) => a - b);
    const crank = (t) => { const c = at(f.centroid, f, A(t)); return cs.length > 1 ? cs.findIndex((v) => v >= c) / (cs.length - 1) : 0.5; };
    let curX = 0.5, nextFree = 0;
    for (let b = 0; b + P.fieldBars < bars.length; b++) {
      if (b < nextFree) continue;
      const seg = loud.slice(b, b + P.fieldBars);
      if (loud[b] < thresh || seg.reduce((a, v) => a + v, 0) / seg.length < thresh) continue;
      const t0 = Math.round(bars[b]), beat = timing.beatMsAt(t0);
      const t1 = Math.round(bars[b + P.fieldBars] - beat);
      const keys = [];
      let c = curX;
      const times = [];
      for (let t = t0; t < t1 - beat * 0.25; t += beat * P.keyBeats) times.push(Math.round(t));
      times.push(t1); // 마지막 키는 항상 끝 시각 (시간은 엄격히 증가)
      for (const t of times) {
        const want = 0.2 + 0.6 * crank(t);
        const lim = keys.length ? P.step : 0.25; // 첫 키는 직전 커서 위치에서 너무 멀지 않게
        c = clamp(c + clamp(want - c, -lim, lim), P.width / 2, 1 - P.width / 2);
        keys.push({ time: t, center: Math.round(c * 100) / 100, width: P.width });
      }
      if (keys.length < 2) continue;
      const field = { type: 'field', keys };
      notes.push(field);
      // 플릭: Field 안 박 위치 중 센 곳, 2박 이상 간격, 방향은 번갈아
      const inside = slots.filter((s) => s.onBeat && s.t > t0 + beat && s.t < t1 - beat * 0.5).sort((a, b) => b.s - a.s);
      const want = Math.max(1, Math.round(P.flicksPerBar * P.fieldBars));
      const chosen = [];
      for (const s of inside) {
        if (chosen.length >= want) break;
        if (chosen.some((o) => Math.abs(o.t - s.t) < 2 * beat)) continue;
        chosen.push(s);
      }
      chosen.sort((a, b) => a.t - b.t);
      let dir = R() < 0.5 ? 'left' : 'right';
      for (const s of chosen) {
        const tt = Math.round(s.t);
        notes.push({ type: 'flick', time: tt, x: Math.round(fieldAt(field, tt).center * 100) / 100, dir });
        dir = dir === 'left' ? 'right' : 'left';
      }
      curX = keys[keys.length - 1].center;
      nextFree = b + P.fieldBars + P.cooldownBars;
    }
  }

  root.AutoChart = { analyze, estimateTempo, generate, PRESET };
})(typeof window !== 'undefined' ? window : globalThis);
