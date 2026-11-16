// 실제 페이지 안에서 합성 마우스 이벤트로 에디터 조작을 검증한다 (launcher.py --dev, ?selftest=1).
(async function () {
  const P = window.PT, S = P.S, results = [];
  const ok = (name, cond, detail) => results.push({ name, ok: !!cond, detail: cond ? '' : String(detail === undefined ? '' : detail) });
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const cv = P.canvas;
  const ev = (type, x, y, o) => {
    const r = cv.getBoundingClientRect();
    const e = new MouseEvent(type, Object.assign({ clientX: r.left + x, clientY: r.top + y, button: 0, bubbles: true }, o || {}));
    (type === 'mousedown' ? cv : window).dispatchEvent(e);
  };
  const click = (x, y, o) => { ev('mousedown', x, y, o); ev('mouseup', x, y, o); };
  const last = () => S.chart.notes[S.chart.notes.length - 1];
  const key = (k, o) => window.dispatchEvent(new KeyboardEvent('keydown', Object.assign({ key: k, bubbles: true }, o || {})));

  try {
    for (let i = 0; i < 200 && !(S.song && S.chart.notes.length); i++) await sleep(50);
    await sleep(100);
    S.cur = 40000; await sleep(100); // 빈 구간으로 이동 + 레이아웃 갱신
    const n0 = S.chart.notes.length;
    ok('샘플 로드됨', n0 === 77, n0);

    P.setTool('tap');
    click(P.laneCx(2), P.yOf(40010)); // 스냅되어 40000
    ok('탭 배치(스냅)', S.chart.notes.length === n0 + 1 && last().type === 'tap' && last().time === 40000 && last().lane === 2, JSON.stringify(last()));
    click(P.laneCx(2), P.yOf(40000));
    ok('같은 자리 탭 클릭 = 삭제', S.chart.notes.length === n0);
    click(P.laneCx(2), P.yOf(40000));
    P.undo(); ok('undo', S.chart.notes.length === n0);
    P.redo(); ok('redo', S.chart.notes.length === n0 + 1);

    P.setTool('hold');
    ev('mousedown', P.laneCx(1), P.yOf(41000)); ev('mousemove', P.laneCx(1), P.yOf(42000)); ev('mouseup', P.laneCx(1), P.yOf(42000));
    ok('홀드 드래그 생성', last().type === 'hold' && last().time === 41000 && last().end === 42000 && last().lane === 1, JSON.stringify(last()));
    click(P.laneCx(1), P.yOf(41500));
    ok('겹치는 홀드 시작은 거부', S.chart.notes.length === n0 + 2);

    P.setTool('flick');
    click(P.xAir(0.5), P.yOf(43000));
    ok('플릭 배치', last().type === 'flick' && last().x === 0.5 && last().dir === 'right' && last().time === 43000, JSON.stringify(last()));
    ok('플릭 폭: 새 플릭은 기본 폭', last().width === S.flickWidth && P.Core.flickWidth(last()) === S.flickWidth, JSON.stringify(last()));
    { const fw0 = last(); const w0 = fw0.width; P.setTool('select'); click(P.xAir(0.5), P.yOf(43000));
      P.canvas.dispatchEvent(new WheelEvent('wheel', { deltaY: -100, altKey: true, bubbles: true, cancelable: true }));
      ok('플릭 폭: Alt+휠로 선택한 플릭 폭 조절', Math.abs(fw0.width - Math.min(1, w0 + 0.05)) < 1e-9, JSON.stringify(fw0));
      P.undo(); ok('플릭 폭: 되돌리기', S.chart.notes.find((n) => n.type === 'flick' && n.time === 43000).width === w0); }
    { const f0 = () => S.chart.notes.find((n) => n.type === 'flick' && n.time === 43000); const hw0 = P.Core.flickWidth(f0()) / 2;
      ev('mousedown', P.xAir(0.5 + hw0), P.yOf(43000)); ev('mousemove', P.xAir(0.9), P.yOf(43000)); ev('mouseup', P.xAir(0.9), P.yOf(43000));
      ok('플릭 폭: 끝을 끌어서 조절', f0().width === 0.8 && f0().x === 0.5 && S.flickWidth === 0.8, JSON.stringify(f0()));
      ev('mousedown', P.xAir(0.5 - 0.4), P.yOf(43000)); ev('mousemove', P.xAir(0.35), P.yOf(43000)); ev('mouseup', P.xAir(0.35), P.yOf(43000));
      ok('플릭 폭: 왼쪽 끝도 조절', f0().width === 0.3 && f0().x === 0.5, JSON.stringify(f0()));
      P.undo(); P.undo(); ok('플릭 폭: 드래그 되돌리기', P.Core.flickWidth(f0()) === hw0 * 2, JSON.stringify(f0())); S.flickWidth = hw0 * 2; }

    P.setTool('field'); S.defWidth = 0.3;
    click(P.xAir(0.3), P.yOf(44000)); click(P.xAir(0.7), P.yOf(46000));
    ok('필드 초안(확정 전)', !!S.draft && S.draft.keys.length === 2 && S.chart.notes.length === n0 + 3);
    key('Enter');
    const f = last();
    ok('필드 Enter 확정', f.type === 'field' && f.keys.length === 2 && f.keys[0].center === 0.3 && f.keys[1].time === 46000, JSON.stringify(f));
    click(P.xAir(0.5), P.yOf(45000)); click(P.xAir(0.5), P.yOf(47000)); key('Enter');
    ok('겹치는 필드 확정 거부', S.chart.notes.length === n0 + 4 && !!S.draft);
    key('Escape'); ok('Esc 초안 취소', !S.draft);

    P.setTool('select');
    const h1 = P.hit(P.xAir(0.3), P.yOf(44000));
    ok('필드 키프레임 히트', h1 && h1.part === 'key' && h1.idx === 0, JSON.stringify(h1 && h1.part));
    ev('mousedown', P.xAir(0.3), P.yOf(44000)); ev('mousemove', P.xAir(0.5), P.yOf(44250)); ev('mouseup', P.xAir(0.5), P.yOf(44250));
    ok('키프레임 드래그(시간·중심)', f.keys[0].center === 0.5 && f.keys[0].time === 44250, JSON.stringify(f.keys[0]));
    ev('mousedown', P.xAir(0.5 + 0.15), P.yOf(44250)); ev('mousemove', P.xAir(0.5 + 0.25), P.yOf(44250)); ev('mouseup', 0, 0);
    ok('키프레임 가장자리 드래그 = 폭', Math.abs(f.keys[0].width - 0.5) < 1e-9, f.keys[0].width);

    const tap = S.chart.notes.find((n) => n.type === 'tap' && n.time === 40000 && n.lane === 2);
    ev('mousedown', P.laneCx(2), P.yOf(40000)); ev('mousemove', P.laneCx(3), P.yOf(40250)); ev('mouseup', P.laneCx(3), P.yOf(40250));
    ok('선택 후 이동(레인+시간)', tap.lane === 3 && tap.time === 40250 && S.sel.has(tap.id), JSON.stringify(tap));
    key('m'); ok('M 좌우 반전', tap.lane === 0, tap.lane);

    // 박스 선택 → 복사/붙여넣기
    S.cur = 43000; await sleep(60);
    ev('mousedown', P.xAir(0.2), P.yOf(43500)); ev('mousemove', P.xAir(0.9), P.yOf(42500)); ev('mouseup', P.xAir(0.9), P.yOf(42500));
    const fl = S.chart.notes.find((n) => n.type === 'flick' && n.time === 43000);
    ok('박스 선택', S.sel.size === 1 && S.sel.has(fl.id), [...S.sel]);
    S.cur = 48000; key('c', { ctrlKey: true }); key('v', { ctrlKey: true });
    ok('복사/붙여넣기', last().type === 'flick' && last().time === 48000, JSON.stringify(last()));
    P.deleteSelected();
    ok('삭제', !S.chart.notes.some((n) => n.type === 'flick' && n.time === 48000));

    const errs = P.validate().filter((i) => i.level === 'error');
    ok('편집 후 검증 오류 없음', errs.length === 0, JSON.stringify(errs));

    // 저장 → 서버 로더 검증
    await P.save(); await sleep(300);
    const r = await (await fetch('/api/chart?song=sample&t=' + encodeURIComponent(window.__TOKEN))).json();
    ok('저장 후 파일 노트 수 일치', r.chart && r.chart.notes.length === S.chart.notes.length && S.dirty === false, r.chart && r.chart.notes.length + ' vs ' + S.chart.notes.length);
    const times = r.chart.notes.map((n) => (n.type === 'field' ? n.keys[0].time : n.time));
    ok('저장 파일 노트 시간순 + 정수 ms', times.every((t, i) => i === 0 || times[i - 1] <= t) && times.every(Number.isInteger));

    // 오디오 파일 추가 (파일 선택창을 흉내: input.click 을 가로채 파일을 주입)
    const realClick = HTMLInputElement.prototype.click;
    HTMLInputElement.prototype.click = function () {
      if (this.type !== 'file') return realClick.call(this);
      const dt = new DataTransfer();
      dt.items.add(new File([new Uint8Array(64)], 'extra.ogg', { type: 'audio/ogg' }));
      this.files = dt.files;
      setTimeout(() => this.dispatchEvent(new Event('change')), 0);
    };
    P.addAudio(); await sleep(800);
    HTMLInputElement.prototype.click = realClick;
    ok('오디오 추가: meta.audio 갱신 + 목록 반영', S.chart.meta.audio === 'extra.ogg' && S.audioFiles.includes('extra.ogg'), S.chart.meta.audio);
    ok('오디오 추가: 임시 input 정리', !document.querySelector('input[type=file][style*="none"]'));

    // --- 박자 맞추기 / 스냅 / 키보드로 찍기 (저장된 파일에는 영향 없음)
    P.setTool('select'); S.sel.clear(); S.snap = 16;
    S.cur = 46000; await sleep(60);
    ok('마디·박 표시', P.beatLabel(46000) === '24마디 1박' && P.beatLabel(46250) === '24마디 1박 +2/4', P.beatLabel(46000) + ' / ' + P.beatLabel(46250));
    const nb = S.chart.notes.length;
    key('a', { code: 'KeyA' });
    ok('멈춘 상태 A = 빨간 선에 탭', S.chart.notes.length === nb + 1 && last().lane === 0 && last().time === 46000, JSON.stringify(last()));
    key('a', { code: 'KeyA' });
    ok('같은 자리 A 한 번 더 = 삭제', S.chart.notes.length === nb);
    P.setTool('tap');
    ev('mousedown', P.laneCx(3), P.yOf(46000)); ev('mousemove', P.laneCx(3), P.yOf(46500)); ev('mouseup', P.laneCx(3), P.yOf(46500));
    ok('탭 도구로 끌면 홀드', last().type === 'hold' && last().time === 46000 && last().end === 46500, JSON.stringify(last()));
    P.setTool('select');
    P.mutate(() => { S.chart.notes.push({ id: 8888, type: 'tap', time: 47013, lane: 1 }); });
    S.sel = new Set([8888]); P.quantizeSelected();
    ok('Q = 격자에 맞추기', S.chart.notes.find((n) => n.id === 8888).time === 47000, S.chart.notes.find((n) => n.id === 8888).time);
    S.snap = 0; ok('스냅 끔 = 1ms 단위', P.snapT(47013.4) === 47013, P.snapT(47013.4)); S.snap = 16;
    const off0 = +S.chart.meta.offset || 0;
    S.cur = 46100; P.setDownbeatHere();
    ok('빨간 선을 마디 첫 박으로', (+S.chart.meta.offset || 0) !== off0 && P.beatLabel(S.cur).endsWith('마디 1박'), S.chart.meta.offset + ' / ' + P.beatLabel(S.cur));
    P.undo();
    ok('첫 박 맞추기 되돌리기', (+S.chart.meta.offset || 0) === off0, S.chart.meta.offset);
    P.setBpmHere(150);
    ok('BPM 바꾸기', S.chart.timing[0].bpm === 150, S.chart.timing[0].bpm);
    P.undo();
    S.sel.clear(); S.cur = 40000; await sleep(60);

    // --- 연출 효과 트랙
    const fxX = (i) => P.L.fxX + (i + 0.5) * P.fxSubW();
    click(fxX(0), P.yOf(40000));
    const e0 = S.chart.effects[0];
    ok('연출 트랙 클릭 = 발광 추가', S.chart.effects.length === 1 && e0.type === 'flash' && e0.time === 40000 && e0.duration === 0 && e0.side === 'left', JSON.stringify(S.chart.effects));
    ok('추가한 연출이 선택됨', S.fxSel === e0.id);
    ev('mousedown', fxX(1), P.yOf(40500)); ev('mousemove', fxX(1), P.yOf(41000)); ev('mouseup', fxX(1), P.yOf(41000));
    const e1 = S.chart.effects[1];
    ok('끌어서 길이 있는 글리치', e1 && e1.type === 'glitch' && e1.time === 40500 && e1.duration === 500, JSON.stringify(e1));
    ev('mousedown', fxX(1), P.yOf(40500)); ev('mousemove', fxX(1), P.yOf(40750)); ev('mouseup', fxX(1), P.yOf(40750));
    ok('연출 끌어서 이동', e1.time === 40750 && S.chart.effects.length === 2, e1.time);
    P.undo(); ok('연출 이동 되돌리기', S.chart.effects[1].time === 40500);
    const js = P.Core.toJSON(S.chart);
    ok('저장 형식: effects 배열(id 없음)', Array.isArray(js.effects) && js.effects.length === 2 && js.effects[0].id === undefined && js.effects[1].duration === 500, JSON.stringify(js.effects));
    ok('다시 읽어도 유지', P.Core.fromJSON(js).effects.length === 2);
    await P.save(); await sleep(200);
    const savedFx = (await (await fetch('/api/chart?song=sample&diff=NM&t=' + encodeURIComponent(window.__TOKEN))).json()).chart.effects;
    ok('서버 저장 후 파일에 effects 남음', Array.isArray(savedFx) && savedFx.length === 2, JSON.stringify(savedFx));
    ev('mousedown', fxX(0), P.yOf(40000), { button: 2 });
    ok('우클릭 = 연출 삭제', S.chart.effects.length === 1 && S.chart.effects[0].type === 'glitch', JSON.stringify(S.chart.effects));

    // 오류가 있으면 저장 거부
    P.mutate(() => { S.chart.notes.push({ id: 9999, type: 'tap', time: 1, lane: 7 }); });
    const before = JSON.stringify((await (await fetch('/api/chart?song=sample&t=' + encodeURIComponent(window.__TOKEN))).json()).chart);
    await P.save(); await sleep(200);
    const after = JSON.stringify((await (await fetch('/api/chart?song=sample&t=' + encodeURIComponent(window.__TOKEN))).json()).chart);
    ok('오류 있는 채보는 저장 안 됨', before === after);
  } catch (e) {
    ok('셀프테스트 예외 없음', false, e && e.stack);
  }
  document.title = results.every((x) => x.ok) ? 'PASS' : 'FAIL';
  const pre = document.createElement('pre'); pre.id = 'uiresults'; pre.textContent = JSON.stringify(results); document.body.append(pre);
})();
