// 브라우저(헤드리스 Chrome)에서 실행되는 코어 테스트. window.__SAMPLE 은 게임의 charts/sample/chart.json.
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

  document.title = results.every((r) => r.ok) ? 'PASS' : 'FAIL';
  const pre = document.createElement('pre');
  pre.id = 'results';
  pre.textContent = JSON.stringify(results);
  document.body.append(pre);
})();
