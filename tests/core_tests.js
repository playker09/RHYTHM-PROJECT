// 브라우저(헤드리스 Chrome)에서 실행되는 코어 테스트. window.__SAMPLE 은 게임의 charts/sample/nm.json.
(function () {
  const results = [];
  const eq = (a, b) => JSON.stringify(a) === JSON.stringify(b);
  const t = (name, fn) => {
    try { const r = fn(); results.push({ name, ok: r === true || r === undefined, detail: r === true || r === undefined ? '' : String(r) }); }
    catch (e) { results.push({ name, ok: false, detail: 'throw ' + e.message }); }
  };
  const C = Core;
  const sample = window.__SAMPLE;

  t('샘플 왕복(load→save)이 원본과 동일', () => {
    const out = C.toJSON(C.fromJSON(sample));
    // 원본은 배열 순서가 곡 진행순이 아닐 수 있으므로 시간 정렬 후 비교
    const key = (n) => C.noteStart(n) + '|' + n.type + '|' + JSON.stringify(n);
    const norm = (o) => JSON.stringify({ ...o, notes: o.notes.map((n) => JSON.stringify(n)).sort() });
    const o2 = JSON.parse(JSON.stringify(sample));
    return norm(out) === norm(o2) || 'mismatch';
  });
  t('샘플 통계: tap60 hold6 flick8 field3', () => {
    const s = C.stats(C.fromJSON(sample));
    return (s.tap === 60 && s.hold === 6 && s.flick === 8 && s.field === 3) || JSON.stringify(s);
  });
  t('샘플 검증: 오류 없음', () => {
    const errs = C.validate(C.fromJSON(sample)).filter((i) => i.level === 'error');
    return errs.length === 0 || JSON.stringify(errs);
  });
  t('hold 1500ms @120BPM tick = 24 (1/8박=62.5ms, 마지막=end)', () => {
    const tm = new C.Timing([{ time: 0, bpm: 120 }]);
    const ticks = tm.tickTimes(10500, 12000, 0.125);
    return (ticks.length === 24 && ticks[0] === 10562.5 && ticks[23] === 12000) || JSON.stringify(ticks.slice(-2));
  });
  t('짧은 구간도 끝 tick 은 항상 존재', () => {
    const tm = new C.Timing([{ time: 0, bpm: 120 }]);
    return eq(tm.tickTimes(0, 10, 0.125), [10]);
  });
  t('BPM 구간 안 변화: tick 간격이 그 시점 BPM 으로 바뀜', () => {
    const tm = new C.Timing([{ time: 0, bpm: 120 }, { time: 1000, bpm: 60 }]);
    const ticks = tm.tickTimes(875, 1300, 0.125); // 875 +62.5=937.5, +62.5=1000 (BPM 60 시작) → +125
    return eq(ticks, [937.5, 1000, 1125, 1250, 1300]) || JSON.stringify(ticks);
  });
  t('timing 정렬/기본값', () => eq(new C.Timing([]).pts, [{ time: 0, bpm: 120 }]));
  t('snap 1/4 @120BPM', () => new C.Timing([{ time: 0, bpm: 120 }]).snap(740, 4) === 500 + 0 || new C.Timing([{ time: 0, bpm: 120 }]).snap(740, 4));
  t('snap 은 BPM 변화 지점에서 그리드 재시작', () => {
    const tm = new C.Timing([{ time: 0, bpm: 120 }, { time: 1100, bpm: 120 }]);
    return tm.snap(1360, 4) === 1600 || tm.snap(1360, 4);
  });
  t('fieldAt 선형 보간', () => {
    const f = { keys: [{ time: 0, center: 0.2, width: 0.2 }, { time: 1000, center: 0.6, width: 0.4 }] };
    const a = C.fieldAt(f, 500);
    return (Math.abs(a.center - 0.4) < 1e-9 && Math.abs(a.width - 0.3) < 1e-9) || JSON.stringify(a);
  });

  const mk = (notes, timing) => ({ meta: { title: 't', audio: 'a.wav', offset: 0, level: 1, difficulty: 'N' }, timing: timing || [{ time: 0, bpm: 120 }], notes: notes.map((n, i) => ({ id: i + 1, ...n })), extra: {} });
  const lv = (chart, level) => C.validate(chart).filter((i) => i.level === level).map((i) => i.msg);

  t('오류: lane 범위/hold end/flick x,dir/field keys', () => {
    const e = lv(mk([
      { type: 'tap', time: 0, lane: 4 },
      { type: 'hold', time: 100, end: 100, lane: 0 },
      { type: 'flick', time: 0, x: 1.2, dir: 'up' },
      { type: 'field', keys: [{ time: 0, center: 0.5, width: 0.3 }] },
    ]), 'error');
    return e.length >= 5 || e.join(' / ');
  });
  t('오류: 필드 시간 겹침', () => {
    const e = lv(mk([
      { type: 'field', keys: [{ time: 0, center: 0.5, width: 0.3 }, { time: 1000, center: 0.5, width: 0.3 }] },
      { type: 'field', keys: [{ time: 1000, center: 0.5, width: 0.3 }, { time: 2000, center: 0.5, width: 0.3 }] },
    ]), 'error');
    return e.length === 1 || e.join(' / ');
  });
  t('오류: 필드 키 시간이 오름차순이 아님', () => {
    const e = lv(mk([{ type: 'field', keys: [{ time: 1000, center: 0.5, width: 0.3 }, { time: 500, center: 0.5, width: 0.3 }] }]), 'error');
    return e.length >= 1;
  });
  t('경고: 같은 레인 tap-hold 겹침, 다른 레인은 OK', () => {
    const w = lv(mk([{ type: 'hold', time: 0, end: 1000, lane: 0 }, { type: 'tap', time: 500, lane: 0 }, { type: 'tap', time: 500, lane: 1 }]), 'warn');
    return w.filter((m) => m.includes('겹칩니다')).length === 1 || w.join(' / ');
  });
  t('경고: flick 촘촘/방향급변', () => {
    const w = lv(mk([{ type: 'flick', time: 0, x: 0.5, dir: 'left' }, { type: 'flick', time: 200, x: 0.5, dir: 'right' }, { type: 'flick', time: 500, x: 0.5, dir: 'left' }]), 'warn');
    return w.some((m) => m.includes('간격')) && w.some((m) => m.includes('급변')) || w.join(' / ');
  });
  t('경고: 필드 첫 center 도달 불가', () => {
    const w = lv(mk([{ type: 'field', keys: [{ time: 100, center: 0.95, width: 0.2 }, { time: 600, center: 0.9, width: 0.2 }] }]), 'warn');
    return w.some((m) => m.includes('도달')) || w.join(' / ');
  });
  t('toJSON: 정수 ms 반올림, 키 정렬, id 제거, extra 보존', () => {
    const c = mk([{ type: 'tap', time: 150.6, lane: 1 }, { type: 'field', keys: [{ time: 900.4, center: 0.5004, width: 0.3 }, { time: 100.5, center: 0.2, width: 0.3 }] }]);
    c.extra = { editor: { grid: 16 } };
    const o = C.toJSON(c);
    const f = o.notes.find((n) => n.type === 'field');
    return (o.notes[0].type === 'field' && f.keys[0].time === 101 && f.keys[1].time === 900 && f.keys[1].center === 0.5 &&
      o.notes[1].time === 151 && !('id' in o.notes[1]) && o.editor.grid === 16) || JSON.stringify(o);
  });
  t('stats: 판정 수 = tap1 + flick1 + hold(1+tick) + field tick', () => {
    const s = C.stats(mk([
      { type: 'tap', time: 0, lane: 0 }, { type: 'flick', time: 0, x: 0.5, dir: 'left' },
      { type: 'hold', time: 0, end: 1500, lane: 1 },
      { type: 'field', keys: [{ time: 0, center: 0.5, width: 0.3 }, { time: 1000, center: 0.5, width: 0.3 }] },
    ]));
    // hold 24 tick, field 1000ms/62.5 = 16 tick → 1+1+(1+24)+16 = 43
    return s.judgments === 43 || JSON.stringify(s);
  });

  /* ---------------- 플레이 테스트 판정 (judge.gd 와 같은 규칙) ---------------- */
  const PJ = window.PlayTest.PlayJudge, G = window.PlayTest.GRADE;
  const tm120 = new C.Timing([{ time: 0, bpm: 120 }]);
  const judgeOf = (notes, from, opts) => {
    const log = [];
    const j = new PJ(mk(notes), tm120, from == null ? -1e9 : from, Object.assign({ onJudge: (r, g, d, tick) => log.push([r.type, g, tick]) }, opts));
    return [j, log];
  };
  t('[play] 탭: ±35 PERFECT, ±70 GREAT, 너무 이르면 무시, 지나면 MISS', () => {
    const [j, log] = judgeOf([{ type: 'tap', time: 1000, lane: 0 }, { type: 'tap', time: 2000, lane: 0 }, { type: 'tap', time: 3000, lane: 1 }]);
    j.press(0, 1030); j.release(0, 1040);
    j.press(0, 1900); // 이름 → 무시
    j.press(0, 1950); j.release(0, 1960);
    j.advance(3071);
    return eq(log, [['tap', G.PERFECT, false], ['tap', G.GREAT, false], ['tap', G.MISS, false]]) && j.fast === 1 && j.maxCombo === 2 || JSON.stringify([log, j.fast]);
  });
  t('[play] 홀드: 누르고 있으면 tick PERFECT, 놓으면 MISS, 총 판정 수 = stats', () => {
    const notes = [{ type: 'hold', time: 0, end: 500, lane: 2 }];
    const [j, log] = judgeOf(notes);
    j.press(2, 0); j.release(2, 250); j.advance(600);
    const ticks = log.filter((e) => e[2]);
    const p = ticks.filter((e) => e[1] === G.PERFECT).length, m = ticks.filter((e) => e[1] === G.MISS).length;
    return (j.total === C.stats(mk(notes)).judgments && p === 4 && m === 4) || JSON.stringify([j.total, p, m]);
  });
  t('[play] 필드: 이탈 150ms 이내 tick 은 판정 없음, 넘으면 MISS', () => {
    const notes = [{ type: 'field', keys: [{ time: 0, center: 0.5, width: 0.2 }, { time: 1000, center: 0.5, width: 0.2 }] }];
    const [j, log] = judgeOf(notes, null, { graceMs: 150 });
    j.setCursor(0.5, 0); j.advance(250);           // 0~250: 안 → 4 tick PERFECT
    j.setCursor(0.9, 250); j.advance(1000);        // 250 이탈: 312.5/375 skip, 437.5부터 MISS
    const g = log.map((e) => e[1]);
    const perf = g.filter((x) => x === G.PERFECT).length, miss = g.filter((x) => x === G.MISS).length;
    return (perf === 4 && miss === 10 && j.total === 16) || JSON.stringify([perf, miss, j.total]);
  });
  t('[play] 플릭: 방향+속도로 통과해야 인정, 윈도우 밖 MISS', () => {
    const [j, log] = judgeOf([{ type: 'flick', time: 1000, x: 0.5, dir: 'right' }, { type: 'flick', time: 2000, x: 0.5, dir: 'left' }]);
    j.setCursor(0.3, 990); j.setCursor(0.7, 1000);  // 오른쪽으로 빠르게 통과 → PERFECT
    j.setCursor(0.3, 1500);                          // 왼쪽 통과지만 너무 이름 (500ms 전) → 무시
    j.advance(2131);
    return eq(log, [['flick', G.PERFECT, false], ['flick', G.MISS, false]]) || JSON.stringify(log);
  });
  t('[play] 시작 지점 이전 노트는 판정하지 않음', () => {
    const [j] = judgeOf([{ type: 'tap', time: 500, lane: 0 }, { type: 'tap', time: 1500, lane: 0 }], 1000);
    return j.total === 1 || j.total;
  });
  t('[play] 테스트 중 편집: 점수/콤보 유지, 지나간 새 노트는 무시, 옮긴 노트는 새 위치로 판정', () => {
    const chart = mk([{ type: 'tap', time: 1000, lane: 0 }, { type: 'tap', time: 2000, lane: 1 }]);
    const log = [];
    let j = new PJ(chart, tm120, 0, { onJudge: (r, g) => log.push(g) });
    j.press(0, 1000); j.release(0, 1010); j.advance(1200);
    chart.notes[1].time = 2500;                                   // 아직 안 온 노트 옮기기
    chart.notes.push({ id: 99, type: 'tap', time: 600, lane: 2 }); // 이미 지나간 시각에 추가
    j = j.rebuild(chart, tm120);
    j.press(1, 2000); j.release(1, 2010);                         // 옛 위치 → 너무 이름, 무시
    j.press(1, 2500); j.advance(2600);
    return (eq(log, [G.PERFECT, G.PERFECT]) && j.combo === 2 && j.total === 2 && j.score === 1000000) || JSON.stringify([log, j.combo, j.total, j.counts]);
  });
  t('[play] 오토: 샘플 전체 ALL PERFECT, 판정 수 = stats', () => {
    const chart = C.fromJSON(sample);
    const j = new PJ(chart, new C.Timing(chart.timing), -1e9, { auto: true });
    for (let now = 0; now <= j.lastEnd + 200; now += 16) j.advance(now);
    return (j.counts[0] === j.total && j.total === C.stats(chart).judgments && j.score === 1000000) || JSON.stringify([j.counts, j.total, C.stats(chart).judgments]);
  });

  /* ---------------- 자동 생성 (합성 신호: 128 BPM, 첫 박 370ms, 킥 = 박 / 하이햇 = 엇박) ---------------- */
  const AC = window.AutoChart;
  const synth = (() => {
    const sr = 22050, dur = 24, bpm = 128, first = 0.37, x = new Float32Array(sr * dur);
    let seed = 7; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647) * 2 - 1;
    for (let k = 0; ; k++) {
      const t = first + (k * 60) / bpm / 2; if (t > dur - 1) break;
      const i0 = Math.floor(t * sr), kick = k % 2 === 0;
      for (let i = 0; i < sr * 0.15; i++) {
        const tt = i / sr;
        x[i0 + i] += kick ? (k % 8 === 0 ? 0.9 : 0.6) * Math.sin(2 * Math.PI * 60 * tt) * Math.exp(-tt * 25) : 0.25 * rnd() * Math.exp(-tt * 60);
      }
    }
    return AC.analyze([x], sr);
  })();
  const tempo = AC.estimateTempo(synth);
  t('[auto] BPM / 첫 박 추정 (킥 기준, 하이햇 엇박에 안 끌려감)', () => {
    const beat = 60000 / 128, err = Math.abs(((tempo.firstBeatMs - 370) % beat + beat * 1.5) % beat - beat / 2);
    return (tempo.bpm === 128 && err <= 20) || JSON.stringify(tempo);
  });
  t('[auto] 난이도별 생성: EZ < NM < HD, 검사 오류 없음, 노트는 소리 위', () => {
    const off = -Math.round(tempo.firstBeatMs), tm = new C.Timing([{ time: 0, bpm: tempo.bpm }]);
    const counts = [], step = 60000 / 128 / 2;
    for (const diff of ['EZ', 'NM', 'HD']) {
      const r = AC.generate(synth, tm, off, { diff, air: true, seed: 5 });
      const errs = C.validate(mk(r.notes.map((n, i) => ({ ...n, id: i + 1 })))).filter((i) => i.level === 'error');
      if (errs.length) return diff + ' ' + JSON.stringify(errs);
      const offGrid = r.notes.filter((n) => n.type === 'tap').filter((n) => { const m = (((n.time - off - 370) % step) + step) % step; return Math.min(m, step - m) > 25; });
      if (offGrid.length) return diff + ' 소리 없는 곳 노트 ' + offGrid.length;
      if (!r.notes.some((n) => n.type === 'field')) return diff + ' field 없음';
      counts.push(r.notes.filter((n) => n.type !== 'field').length);
    }
    return (counts[0] < counts[1] && counts[1] < counts[2]) || JSON.stringify(counts);
  });

  document.title = results.every((r) => r.ok) ? 'PASS' : 'FAIL';
  const pre = document.createElement('pre');
  pre.id = 'results';
  pre.textContent = JSON.stringify(results);
  document.body.append(pre);
})();
