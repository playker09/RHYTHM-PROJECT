/* RHYTHM-PROJECT 채보 코어: 포맷 상수, 타이밍, 검증, 통계, 직렬화.
 * 기준: PATTERN_TOOL_GUIDE.md / core/chart_loader.gd / core/timing_map.gd / core/game_const.gd
 * DOM에 의존하지 않는다 (tests.html에서 단독으로 검증 가능). */
(function (root) {
  'use strict';

  const K = {
    LANE_COUNT: 4,
    LANE_KEYS: ['A', 'S', 'D', 'F'],
    PERFECT_MS: 35,
    GREAT_MS: 70,
    FLICK_WINDOW_MS: 130,
    FLICK_MIN_SPEED: 1.0,
    FLICK_X_MARGIN: 0.04,
    TICK_BEAT_FRACTION: 0.125,
    END_PAD_MS: 1500,
    // 게임 코드에 없는 에디터 휴리스틱 (경고 전용)
    FLICK_MIN_GAP_MS: 260,
    FLICK_REVERSE_GAP_MS: 350,
    MAX_CURSOR_SPEED: 3.0,
  };

  const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));
  const round3 = (v) => Math.round(v * 1000) / 1000;
  const isNum = (v) => typeof v === 'number' && isFinite(v);

  /* ---------------- 타이밍 (TimingMap 과 동일한 규칙) ---------------- */
  class Timing {
    constructor(points) {
      this.pts = (points || [])
        .filter((p) => isNum(p.time) && isNum(p.bpm) && p.bpm > 0)
        .map((p) => ({ time: p.time, bpm: p.bpm }))
        .sort((a, b) => a.time - b.time);
      if (!this.pts.length) this.pts = [{ time: 0, bpm: 120 }];
    }
    _idx(t) {
      let i = 0;
      for (let k = 0; k < this.pts.length; k++) {
        if (this.pts[k].time <= t) i = k; else break;
      }
      return i;
    }
    bpmAt(t) { return this.pts[this._idx(t)].bpm; }
    beatMsAt(t) { return 60000 / this.bpmAt(t); }
    /** (start, end] 구간 tick 시각. 마지막 tick은 항상 end. */
    tickTimes(start, end, frac) {
      const out = [];
      let t = start;
      for (let guard = 0; guard < 1e6; guard++) {
        t += this.beatMsAt(t) * frac;
        if (t >= end - 0.5) break;
        out.push(t);
      }
      out.push(end);
      return out;
    }
    /** 해당 시각이 속한 BPM 구간 { start, end(없으면 Infinity), bpm } */
    segment(t) {
      const i = this._idx(t);
      const next = this.pts[i + 1];
      return {
        start: i === 0 && t < this.pts[0].time ? t : this.pts[i].time,
        end: next ? next.time : Infinity,
        bpm: this.pts[i].bpm,
        index: i,
      };
    }
    /** 구간 시작 기준으로 1/div 음표 그리드에 스냅 (div=4 → 4분음표). */
    snap(t, div) {
      const s = this.segment(t);
      const origin = this.pts[s.index].time;
      const stepMs = (60000 / s.bpm) * (4 / div);
      let r = origin + Math.round((t - origin) / stepMs) * stepMs;
      if (r >= s.end - 1e-6) r = s.end;
      return r;
    }
    /** [t0, t1] 안의 그리드 선. 반환: { t, beat(구간 내 박 번호), strong } */
    gridLines(t0, t1, div) {
      const out = [];
      for (let si = 0; si < this.pts.length; si++) {
        const origin = this.pts[si].time;
        const end = si + 1 < this.pts.length ? this.pts[si + 1].time : Infinity;
        const bpm = this.pts[si].bpm;
        const stepMs = (60000 / bpm) * (4 / div);
        const lo = si === 0 ? t0 : Math.max(t0, origin);
        const hi = Math.min(t1, end);
        if (hi < lo) continue;
        let k = Math.ceil((lo - origin) / stepMs - 1e-9);
        for (let guard = 0; guard < 5000; guard++, k++) {
          const t = origin + k * stepMs;
          if (t > hi + 1e-6) break;
          if (t >= end - 1e-6 && end !== Infinity) break;
          const beatPos = (k * 4) / div; // 구간 시작부터의 박 수
          const onBeat = Math.abs(beatPos - Math.round(beatPos)) < 1e-6;
          out.push({
            t,
            beat: Math.round(beatPos),
            onBeat,
            strong: onBeat && Math.round(beatPos) % 4 === 0,
          });
        }
      }
      return out;
    }
  }

  /* ---------------- 노트 도우미 ---------------- */
  const noteStart = (n) => (n.type === 'field' ? n.keys[0].time : n.time);
  const noteEnd = (n) =>
    n.type === 'hold' ? n.end : n.type === 'field' ? n.keys[n.keys.length - 1].time : n.time;

  /** 필드 보간 (field_interp 와 동일: 키프레임 사이 선형, 범위 밖은 양 끝값). */
  function fieldAt(note, t) {
    const k = note.keys;
    if (t <= k[0].time) return { center: k[0].center, width: k[0].width };
    const last = k[k.length - 1];
    if (t >= last.time) return { center: last.center, width: last.width };
    for (let i = 0; i < k.length - 1; i++) {
      const a = k[i], b = k[i + 1];
      if (t >= a.time && t <= b.time) {
        const u = b.time === a.time ? 0 : (t - a.time) / (b.time - a.time);
        return { center: a.center + (b.center - a.center) * u, width: a.width + (b.width - a.width) * u };
      }
    }
    return { center: last.center, width: last.width };
  }

  /* ---------------- 채보 객체 ---------------- */
  let _id = 1;
  const newId = () => _id++;

  function defaultChart() {
    return {
      meta: { title: '', artist: '', audio: '', offset: 0, level: 1, difficulty: 'NORMAL' },
      timing: [{ time: 0, bpm: 120 }],
      notes: [],
      extra: {},
    };
  }

  /** 파일에서 읽은 JSON → 에디터 내부 표현 (알 수 없는 최상위 키는 extra 로 보존). */
  function fromJSON(obj) {
    const c = defaultChart();
    if (!obj || typeof obj !== 'object' || Array.isArray(obj)) return c;
    const { meta, timing, notes, ...extra } = obj;
    c.meta = Object.assign(c.meta, meta || {});
    c.timing = Array.isArray(timing) && timing.length
      ? timing.filter((p) => p && isNum(+p.time) && isNum(+p.bpm)).map((p) => ({ time: +p.time, bpm: +p.bpm }))
      : c.timing;
    if (!c.timing.length) c.timing = [{ time: 0, bpm: 120 }];
    c.timing.sort((a, b) => a.time - b.time);
    c.notes = (Array.isArray(notes) ? notes : [])
      .filter((n) => n && typeof n === 'object')
      .map((n) => Object.assign({}, n, { id: newId() }));
    c.extra = extra;
    return c;
  }

  /** 저장용 객체. 시간은 정수 ms, 노트/필드 키 정렬, 에디터 전용 id 제거. */
  function toJSON(chart) {
    const r = Math.round;
    const notes = chart.notes.map((n) => {
      const { id, ...o } = n;
      if (o.type === 'tap') { o.time = r(o.time); o.lane = r(o.lane); }
      else if (o.type === 'hold') { o.time = r(o.time); o.end = r(o.end); o.lane = r(o.lane); }
      else if (o.type === 'flick') { o.time = r(o.time); o.x = round3(o.x); }
      else if (o.type === 'field') {
        o.keys = o.keys
          .map((k) => ({ time: r(k.time), center: round3(k.center), width: round3(k.width) }))
          .sort((a, b) => a.time - b.time);
      }
      return o;
    });
    notes.sort((a, b) => noteStart(a) - noteStart(b));
    const meta = Object.assign({}, chart.meta, {
      offset: r(+chart.meta.offset || 0),
      level: r(+chart.meta.level || 0),
    });
    const timing = chart.timing
      .map((p) => ({ time: r(p.time), bpm: p.bpm }))
      .sort((a, b) => a.time - b.time);
    return Object.assign({ meta, timing, notes }, chart.extra || {});
  }

  /* ---------------- 검증 ---------------- */
  /** 반환: [{ level:'error'|'warn'|'info', msg, t, ids }]. error 가 있으면 저장 불가. */
  function validate(chart, opts) {
    opts = opts || {};
    const out = [];
    const add = (level, msg, t, ids) => out.push({ level, msg, t: t == null ? null : t, ids: ids || [] });
    const R = Math.round;
    const fmt = (ms) => `${(ms / 1000).toFixed(3)}s`;

    // timing
    if (!chart.timing.length) add('error', 'BPM(timing)이 하나도 없습니다. 최소 1개(time 0) 필요');
    chart.timing.forEach((p, i) => {
      if (!isNum(p.time) || !isNum(p.bpm) || !(p.bpm > 0)) add('error', `BPM #${i + 1}: time/bpm 이 올바르지 않습니다 (bpm > 0)`);
    });
    if (chart.timing.length && chart.timing[0].time !== 0) add('warn', '첫 BPM 의 time 이 0 이 아닙니다 (권장: 0)');
    for (let i = 1; i < chart.timing.length; i++) {
      if (R(chart.timing[i].time) === R(chart.timing[i - 1].time)) add('warn', `BPM 시각 중복: ${fmt(chart.timing[i].time)}`, chart.timing[i].time);
    }

    const timing = new Timing(chart.timing);
    const lanes = Array.from({ length: K.LANE_COUNT }, () => []);
    const fields = [];
    const flicks = [];

    for (const n of chart.notes) {
      const where = `${n.type} @${isNum(n.time) ? fmt(noteStart(n)) : '?'}`;
      if (n.type === 'tap' || n.type === 'hold') {
        if (!isNum(n.time)) { add('error', `${n.type}: time 이 없습니다`, null, [n.id]); continue; }
        if (!Number.isInteger(n.lane) || n.lane < 0 || n.lane >= K.LANE_COUNT) { add('error', `${where}: lane 은 0~3 정수`, n.time, [n.id]); continue; }
        if (n.type === 'hold' && !(isNum(n.end) && R(n.end) > R(n.time))) { add('error', `${where}: hold 는 end > time 이어야 합니다`, n.time, [n.id]); continue; }
        if (n.time < 0) add('warn', `${where}: 음수 시간`, n.time, [n.id]);
        lanes[n.lane].push(n);
      } else if (n.type === 'flick') {
        if (!isNum(n.time)) { add('error', 'flick: time 이 없습니다', null, [n.id]); continue; }
        if (!(isNum(n.x) && n.x >= 0 && n.x <= 1)) add('error', `${where}: x 는 0~1`, n.time, [n.id]);
        if (n.dir !== 'left' && n.dir !== 'right') add('error', `${where}: dir 은 left/right`, n.time, [n.id]);
        if (n.time < 0) add('warn', `${where}: 음수 시간`, n.time, [n.id]);
        flicks.push(n);
      } else if (n.type === 'field') {
        if (!Array.isArray(n.keys) || n.keys.length < 2) { add('error', 'field: 키프레임이 2개 이상 필요합니다', null, [n.id]); continue; }
        let ok = true;
        n.keys.forEach((k, i) => {
          if (!isNum(k.time)) { add('error', `field 키 #${i + 1}: time 이 없습니다`, null, [n.id]); ok = false; return; }
          if (!(isNum(k.center) && k.center >= 0 && k.center <= 1)) { add('error', `field @${fmt(k.time)}: center 는 0~1`, k.time, [n.id]); ok = false; }
          if (!(isNum(k.width) && k.width >= 0 && k.width <= 1)) { add('error', `field @${fmt(k.time)}: width 는 0~1`, k.time, [n.id]); ok = false; }
          else if (k.width === 0) add('warn', `field @${fmt(k.time)}: width 0 (영역이 없음)`, k.time, [n.id]);
          if (i > 0 && R(k.time) <= R(n.keys[i - 1].time)) { add('error', `field @${fmt(k.time)}: 키프레임 시간은 엄격히 오름차순이어야 합니다`, k.time, [n.id]); ok = false; }
        });
        if (n.keys[0].time < 0) add('warn', `field @${fmt(n.keys[0].time)}: 음수 시간`, n.keys[0].time, [n.id]);
        if (ok) fields.push(n);
      } else {
        add('error', `알 수 없는 노트 종류: ${n.type}`, n.time, [n.id]);
      }
    }

    // 같은 레인 tap/hold 겹침 (경고)
    lanes.forEach((list, lane) => {
      list.sort((a, b) => a.time - b.time);
      for (let i = 1; i < list.length; i++) {
        const prev = list[i - 1], cur = list[i];
        if (R(cur.time) <= R(noteEnd(prev))) {
          add('warn', `레인 ${K.LANE_KEYS[lane]}: ${prev.type}(${fmt(prev.time)})와 ${cur.type}(${fmt(cur.time)})가 겹칩니다`, cur.time, [prev.id, cur.id]);
        }
      }
    });

    // 필드끼리 겹침 (에러)
    fields.sort((a, b) => noteStart(a) - noteStart(b));
    for (let i = 1; i < fields.length; i++) {
      if (R(noteStart(fields[i])) <= R(noteEnd(fields[i - 1]))) {
        add('error', `field 끼리 시간이 겹칩니다 (${fmt(noteStart(fields[i - 1]))}~${fmt(noteEnd(fields[i - 1]))} / ${fmt(noteStart(fields[i]))}~)`, noteStart(fields[i]), [fields[i - 1].id, fields[i].id]);
      }
    }

    // 필드 첫 center 도달 가능성 (휴리스틱)
    let curX = 0.5, curT = 0;
    for (const f of fields) {
      const gap = (noteStart(f) - curT) / 1000;
      const dist = Math.abs(f.keys[0].center - curX);
      if (dist > 0.25 && (gap <= 0 || dist / gap > K.MAX_CURSOR_SPEED)) {
        add('warn', `field @${fmt(noteStart(f))}: 직전 위치(${curX.toFixed(2)})에서 첫 center(${f.keys[0].center.toFixed(2)})까지 ${gap.toFixed(2)}s — 도달하기 어려울 수 있음`, noteStart(f), [f.id]);
      }
      curX = f.keys[f.keys.length - 1].center;
      curT = noteEnd(f);
    }

    // flick: 필드 안 배치 / 간격 / 방향 급변
    flicks.sort((a, b) => a.time - b.time);
    for (const fl of flicks) {
      const host = fields.find((f) => fl.time >= noteStart(f) && fl.time <= noteEnd(f));
      if (!host) add('info', `flick @${fmt(fl.time)}: 같은 시각의 field 영역 밖에 있습니다 (동작은 하지만 의도된 패턴이 아님)`, fl.time, [fl.id]);
      else {
        const a = fieldAt(host, fl.time);
        if (Math.abs(fl.x - a.center) > a.width / 2 + K.FLICK_X_MARGIN) {
          add('info', `flick @${fmt(fl.time)}: x(${fl.x.toFixed(2)})가 그 시각 field 영역(중심 ${a.center.toFixed(2)})에서 벗어났습니다`, fl.time, [fl.id]);
        }
      }
    }
    for (let i = 1; i < flicks.length; i++) {
      const a = flicks[i - 1], b = flicks[i];
      const gap = b.time - a.time;
      if (gap < K.FLICK_MIN_GAP_MS) add('warn', `flick 간격 ${R(gap)}ms (${fmt(a.time)}→${fmt(b.time)}): 판정 창 ±${K.FLICK_WINDOW_MS}ms 가 겹쳐 치기 어렵습니다`, b.time, [a.id, b.id]);
      else if (a.dir !== b.dir && gap < K.FLICK_REVERSE_GAP_MS) add('warn', `flick 방향 급변 ${R(gap)}ms (${fmt(a.time)}→${fmt(b.time)})`, b.time, [a.id, b.id]);
    }

    if (opts.durationMs && chart.notes.length) {
      const end = chart.notes.reduce((m, n) => Math.max(m, noteEnd(n)), 0);
      if (end > opts.durationMs + (+chart.meta.offset || 0)) add('warn', `마지막 노트(${fmt(end)})가 오디오 길이(${fmt(opts.durationMs + (+chart.meta.offset || 0))})를 넘습니다`, end);
    }
    if (!chart.notes.length) add('info', '노트가 없습니다');
    if (!chart.meta.audio) add('warn', 'meta.audio 가 비어 있습니다');
    if (!chart.meta.title) add('info', 'meta.title 이 비어 있습니다 (선곡 화면에는 폴더명이 표시됨)');
    return out;
  }

  /* ---------------- 통계 (가이드 5절) ---------------- */
  function stats(chart) {
    const timing = new Timing(chart.timing);
    const s = { tap: 0, hold: 0, flick: 0, field: 0, judgments: 0, holdTicks: 0, fieldTicks: 0, endTime: 0, notes: chart.notes.length };
    for (const n of chart.notes) {
      if (n.type === 'tap' && isNum(n.time)) { s.tap++; s.judgments += 1; }
      else if (n.type === 'flick' && isNum(n.time)) { s.flick++; s.judgments += 1; }
      else if (n.type === 'hold' && isNum(n.time) && isNum(n.end) && n.end > n.time) {
        s.hold++;
        const t = timing.tickTimes(n.time, n.end, K.TICK_BEAT_FRACTION).length;
        s.holdTicks += t; s.judgments += 1 + t;
      } else if (n.type === 'field' && Array.isArray(n.keys) && n.keys.length >= 2) {
        s.field++;
        const t = timing.tickTimes(n.keys[0].time, n.keys[n.keys.length - 1].time, K.TICK_BEAT_FRACTION).length;
        s.fieldTicks += t; s.judgments += t;
      } else continue;
      s.endTime = Math.max(s.endTime, noteEnd(n));
    }
    s.gameEnd = s.notes ? s.endTime + K.END_PAD_MS : 0;
    return s;
  }

  root.Core = { K, Timing, clamp, round3, isNum, noteStart, noteEnd, fieldAt, newId, defaultChart, fromJSON, toJSON, validate, stats };
})(typeof window !== 'undefined' ? window : globalThis);
