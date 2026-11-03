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
