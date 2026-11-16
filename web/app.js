/* RHYTHM-PROJECT 패턴 툴 UI.
 * 타임라인: 시간이 위로 흐르고(노트가 아래 판정선으로 떨어짐), 왼쪽 = 공중(flick/field, x 0~1), 오른쪽 = 바닥 4레인(A S D F). */
(function () {
  'use strict';
  const { K, FX, FX_TYPES, Timing, clamp, round3, noteStart, noteEnd, fieldAt, newId } = Core;
  const $ = (s) => document.querySelector(s);
  const TOKEN = window.__TOKEN;

  /* ------------------------------------------------------------ 유틸 */
  function h(tag, props, ...kids) {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(props || {})) {
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else if (k === 'value') el.value = v;
      else if (v === true) el.setAttribute(k, '');
      else if (v !== false && v != null) el.setAttribute(k, v);
    }
    for (const c of kids.flat()) if (c != null) el.append(c.nodeType ? c : document.createTextNode(c));
    return el;
  }
  const withToken = (p) => p + (p.includes('?') ? '&' : '?') + 't=' + encodeURIComponent(TOKEN);
  async function api(path, opts) {
    const r = await fetch(withToken(path), opts);
    return r.json();
  }
  const post = (path, body) => api(path, { method: 'POST', body: typeof body === 'string' || body instanceof Blob ? body : JSON.stringify(body) });
  const store = {
    get(k, d) { try { const v = localStorage.getItem('pt.' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } },
    set(k, v) { try { localStorage.setItem('pt.' + k, JSON.stringify(v)); } catch (e) { /* 무시 */ } },
  };
  let toastTimer = 0;
  function toast(msg, ms) {
    const el = $('#toast');
    el.textContent = msg; el.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.remove('show'), ms || 2200);
  }
  const setStatus = (m) => { $('#status').textContent = m; };
  const fmtTime = (ms) => `${(ms / 1000).toFixed(3)}s`;

  /* ------------------------------------------------------------ 상태 */
  const SNAPS = [4, 8, 12, 16, 24, 32, 48, 64, 0]; // 0 = 스냅 끔(1ms 단위)
  const SNAP_NAMES = { 4: '1/4 · 한 박', 8: '1/8 · 반 박', 12: '1/12 · 셋잇단', 16: '1/16 · 반의 반 박', 24: '1/24 · 빠른 셋잇단', 32: '1/32', 48: '1/48', 64: '1/64', 0: '끔 (자유 배치)' };
  const S = {
    songs: [], song: null, diff: store.get('lastDiff', 'NM'), audioFiles: [],
    chart: Core.defaultChart(), timing: null,
    dirty: false, undo: [], redo: [],
    cur: 0, pps: store.get('pps', 320), snap: store.get('snap', 16),
    tool: 'select', flickDir: store.get('flickDir', 'right'), flickWidth: store.get('flickWidth', K.FLICK_DEFAULT_WIDTH), defWidth: store.get('defWidth', 0.3),
    sel: new Set(), draft: null, drag: null, hover: null, clip: null,
    fxSel: null, // 선택한 연출 효과 id
    playing: false, clap: store.get('clap', true), rate: 1,
    metro: store.get('metro', false), rec: false, recLat: store.get('recLat', 0),
    audioDur: 0, peaks: null, peakBucketMs: 10,
    issues: [], stats: null, tab: 'props',
    test: null, // 플레이 테스트 중: { from, view, judge, done }
  };
  const L = {}; // 레이아웃
  let needsDraw = true;
  const invalidate = () => { needsDraw = true; };

  const byId = (id) => S.chart.notes.find((n) => n.id === id);
  const selNotes = () => S.chart.notes.filter((n) => S.sel.has(n.id));

  /* ------------------------------------------------------------ 변경/undo */
  const snapshot = () => JSON.stringify(S.chart);
  function pushUndo(snap) {
    S.undo.push(snap || snapshot());
    if (S.undo.length > 200) S.undo.shift();
    S.redo.length = 0;
  }
  function mutate(fn) { pushUndo(); fn(); changed(); }
  function restore(snap) {
    S.chart = JSON.parse(snap);
    if (!Array.isArray(S.chart.effects)) S.chart.effects = [];
    if (!S.chart.effects.some((f) => f.id === S.fxSel)) S.fxSel = null;
    const ids = new Set(S.chart.notes.map((n) => n.id));
    S.sel = new Set([...S.sel].filter((i) => ids.has(i)));
    changed();
  }
  function undo() { if (!S.undo.length) return; S.redo.push(snapshot()); restore(S.undo.pop()); }
  function redo() { if (!S.redo.length) return; S.undo.push(snapshot()); restore(S.redo.pop()); }

  let panelQueued = false;
  function changed() {
    S.dirty = true;
    S.timing = new Timing(S.chart.timing);
    if (S.test && !S.test.done) S.test.judge = S.test.judge.rebuild(S.chart, S.timing);
    S.issues = Core.validate(S.chart, { durationMs: S.audioDur });
    S.stats = Core.stats(S.chart);
    invalidate();
    if (!panelQueued) { panelQueued = true; requestAnimationFrame(() => { panelQueued = false; renderPanels(); }); }
  }

  /* ------------------------------------------------------------ 좌표 */
  function layout(W, H) {
    L.W = W; L.H = H;
    L.gutter = 150; // 왼쪽 = 파형(넓게) + 마디 번호
    L.waveCx = 52; L.waveHalf = 46;
    L.fxW = 112; // 오른쪽 끝 = 연출 효과 트랙 (종류마다 한 칸)
    const avail = W - L.gutter - 56 - 24 - (L.fxW + 14);
    L.airW = Math.max(220, Math.round(avail * 0.6));
    L.laneW = clamp(Math.floor((avail - L.airW) / 4), 40, 92);
    L.airX = L.gutter;
    L.laneX = L.airX + L.airW + 56;
    L.fxX = L.laneX + L.laneW * 4 + 14;
    L.recY = Math.round(H * 0.8);
  }
  const viewT = () => (S.test ? S.test.view : S.cur);
  const yOf = (t) => L.recY - ((t - viewT()) * S.pps) / 1000;
  const tAt = (y) => viewT() + ((L.recY - y) * 1000) / S.pps;
  const xAir = (v) => L.airX + v * L.airW;
  const laneCx = (l) => L.laneX + L.laneW * (l + 0.5);
  const laneAt = (px) => { const i = Math.floor((px - L.laneX) / L.laneW); return i >= 0 && i < K.LANE_COUNT ? i : -1; };
  const inAir = (px) => px >= L.airX - 6 && px <= L.airX + L.airW + 6;
  const airVal = (px) => clamp((px - L.airX) / L.airW, 0, 1);
  const fxSubW = () => L.fxW / FX_TYPES.length;
  const fxAt = (px) => { const i = Math.floor((px - L.fxX) / fxSubW()); return px >= L.fxX && i >= 0 && i < FX_TYPES.length ? i : -1; };
  const fxEnd = (f) => f.time + (+f.duration || 0);
  const fxById = (id) => S.chart.effects.find((f) => f.id === id);
  /** 연출 트랙 히트 테스트 → { fx, part: 'body' | 'end' } */
  function fxHit(px, py) {
    const i = fxAt(px);
    if (i < 0) return null;
    for (let k = S.chart.effects.length - 1; k >= 0; k--) {
      const f = S.chart.effects[k];
      if (f.type !== FX_TYPES[i]) continue;
      const y0 = yOf(f.time), y1 = yOf(fxEnd(f));
      if (f.duration > 0 && Math.abs(py - y1) <= 5 && y0 - y1 > 12) return { fx: f, part: 'end' };
      if (py <= y0 + 7 && py >= Math.min(y1, y0 - 7)) return { fx: f, part: 'body' };
    }
    return null;
  }
  function deleteFx(id) {
    if (!fxById(id)) return;
    mutate(() => { S.chart.effects = S.chart.effects.filter((f) => f.id !== id); if (S.fxSel === id) S.fxSel = null; });
  }
  const snapDiv = () => S.snap || 16; // 스냅을 꺼도 방향키 이동/한 칸 길이는 1/16 기준
  const snapT = (t) => (S.snap ? Math.max(0, S.timing.snap(Math.max(0, t), S.snap)) : Math.max(0, Math.round(t)));
  const snapX = (v, free) => clamp(free ? Math.round(v * 100) / 100 : Math.round(v * 20) / 20, 0, 1);
  const stepMsAt = (t) => (60000 / S.timing.bpmAt(t)) * (4 / snapDiv());
  /** 시각 -> "12마디 3박 +1/4" (4/4 기준, BPM 구간 시작부터 센다) */
  function beatLabel(t) {
    t = Math.max(0, t);
    const g = S.timing.segment(t);
    const r = Math.round((((t - g.start) * g.bpm) / 60000) * 48) / 48;
    const f = r - Math.floor(r), d = snapDiv() / 4, k = f * d;
    let s = `${Math.floor(r / 4) + 1}마디 ${Math.floor(r % 4) + 1}박`;
    if (f > 1e-6) s += Math.abs(k - Math.round(k)) < 1e-6 ? ` +${Math.round(k)}/${d}` : ` +${f.toFixed(2)}`;
    return s;
  }
  /** 박 안에서의 위치로 격자 선 종류를 가른다: 0 = 박, 8 = 반 박, 16 = 1/16, 12 = 셋잇단, 99 = 그 밖 */
  function gridKind(t) {
    const g = S.timing.segment(t + 0.01);
    const f = (((((t - g.start) * g.bpm) / 60000) % 1) + 1) % 1;
    const near = (v) => Math.abs(f - v) < 0.004;
    if (near(0) || near(1)) return 0;
    if (near(0.5)) return 8;
    if (near(0.25) || near(0.75)) return 16;
    if (near(1 / 3) || near(2 / 3) || near(1 / 6) || near(5 / 6)) return 12;
    return 99;
  }
  const totalMs = () => Math.max(10000, S.audioDur + (+S.chart.meta.offset || 0), (S.stats ? S.stats.endTime : 0) + 3000);

  /* ------------------------------------------------------------ 노트 조작 */
  function laneConflict(lane, a, b, ignore) {
    return S.chart.notes.find((n) =>
      (n.type === 'tap' || n.type === 'hold') && n.lane === lane && !(ignore && ignore.has(n.id)) &&
      Math.round(n.time) <= Math.round(b) && Math.round(noteEnd(n)) >= Math.round(a));
  }
  function fieldConflict(start, end, ignoreId) {
    return S.chart.notes.find((n) => n.type === 'field' && n.id !== ignoreId &&
      Math.round(noteStart(n)) <= Math.round(end) && Math.round(noteEnd(n)) >= Math.round(start));
  }
  function addNote(n) { n.id = newId(); S.chart.notes.push(n); return n; }
  /** 그 자리에 탭이 있으면 지우고, 없으면 찍는다 */
  function toggleTap(lane, t) {
    const same = S.chart.notes.find((n) => n.type === 'tap' && n.lane === lane && Math.round(n.time) === Math.round(t));
    if (same) return mutate(() => { S.chart.notes = S.chart.notes.filter((n) => n !== same); S.sel.delete(same.id); });
    if (laneConflict(lane, t, t)) return toast('같은 레인의 다른 노트와 겹칩니다');
    mutate(() => addNote({ type: 'tap', time: t, lane }));
  }
  /** 선택한 노트(없으면 전부)를 지금 스냅 격자에 붙인다. 귀로 찍었거나 자동 생성한 노트 정리용 */
  function quantizeSelected() {
    if (!S.snap) return toast('스냅이 꺼져 있습니다. 스냅 단위를 고른 뒤 다시 누르세요');
    const list = S.sel.size ? selNotes() : S.chart.notes;
    if (!list.length) return;
    let moved = 0;
    mutate(() => list.forEach((n) => {
      const q = (v) => { const r = snapT(v); if (Math.round(r) !== Math.round(v)) moved++; return r; };
      if (n.type === 'field') {
        n.keys.forEach((k, i) => {
          const r = snapT(k.time);
          const lo = i > 0 ? n.keys[i - 1].time : -Infinity, hi = i < n.keys.length - 1 ? n.keys[i + 1].time : Infinity;
          if (r > lo && r < hi) { if (Math.round(r) !== Math.round(k.time)) moved++; k.time = r; }
        });
      } else {
        n.time = q(n.time);
        if (n.type === 'hold') n.end = Math.max(q(n.end), n.time + stepMsAt(n.time));
      }
    }));
    toast(`${list.length}개 중 ${moved}곳을 ${S.snap ? '1/' + S.snap : ''} 격자에 맞췄습니다`);
  }
  function deleteSelected() {
    if (!S.sel.size) return;
    mutate(() => { S.chart.notes = S.chart.notes.filter((n) => !S.sel.has(n.id)); S.sel.clear(); });
  }
  function mirrorSelected() {
    const list = selNotes();
    if (!list.length) return toast('반전할 노트를 선택하세요');
    mutate(() => list.forEach((n) => {
      if (n.type === 'tap' || n.type === 'hold') n.lane = K.LANE_COUNT - 1 - n.lane;
      else if (n.type === 'flick') { n.x = round3(1 - n.x); n.dir = n.dir === 'left' ? 'right' : 'left'; }
      else if (n.type === 'field') n.keys.forEach((k) => { k.center = round3(1 - k.center); });
    }));
  }
  function shiftSelected(steps) {
    const list = selNotes();
    if (!list.length) return;
    const d = steps * stepMsAt(S.cur);
    mutate(() => list.forEach((n) => {
      if (n.type === 'field') n.keys.forEach((k) => { k.time += d; });
      else { n.time += d; if (n.type === 'hold') n.end += d; }
    }));
  }
  function copySelected() {
    const list = selNotes();
    if (!list.length) return;
    S.clip = { base: Math.min(...list.map(noteStart)), notes: JSON.parse(JSON.stringify(list)) };
    toast(`${list.length}개 복사`);
  }
  function paste() {
    if (!S.clip) return;
    const dt = snapT(S.cur) - S.clip.base;
    mutate(() => {
      S.sel.clear();
      for (const o of S.clip.notes) {
        const n = JSON.parse(JSON.stringify(o));
        if (n.type === 'field') n.keys.forEach((k) => { k.time += dt; }); else { n.time += dt; if (n.type === 'hold') n.end += dt; }
        addNote(n); S.sel.add(n.id);
      }
    });
    toast(`${S.clip.notes.length}개 붙여넣기 (경고는 검사 탭 확인)`);
  }

  /* ------------------------------------------------------------ 히트 테스트 */
  function fieldEdgeX(n, t) { const a = fieldAt(n, t); return [xAir(a.center - a.width / 2), xAir(a.center + a.width / 2)]; }
  function hit(px, py) {
    const notes = S.chart.notes;
    for (let i = notes.length - 1; i >= 0; i--) {
      const n = notes[i];
      if (n.type === 'field') {
        if (!Array.isArray(n.keys)) continue;
        for (let k = 0; k < n.keys.length; k++) {
          const key = n.keys[k], y = yOf(key.time);
          if (Math.abs(py - y) > 8) continue;
          const xl = xAir(key.center - key.width / 2), xr = xAir(key.center + key.width / 2), xc = xAir(key.center);
          if (Math.abs(px - xc) <= 9) return { note: n, part: 'key', idx: k, edge: 'c' };
          if (Math.abs(px - xl) <= 8) return { note: n, part: 'key', idx: k, edge: 'l' };
          if (Math.abs(px - xr) <= 8) return { note: n, part: 'key', idx: k, edge: 'r' };
        }
      } else if (n.type === 'flick') {
        if (Math.abs(py - yOf(n.time)) <= 12) {
          const hw = Core.flickWidth(n) * L.airW / 2, dx = px - xAir(n.x);
          if (Math.abs(Math.abs(dx) - hw) <= 7 && Math.abs(dx) > 14) return { note: n, part: 'flickEdge' }; // 양 끝 눈금 = 폭 조절
          if (Math.abs(dx) <= Math.max(20, hw)) return { note: n, part: 'body' };
        }
      } else if (n.type === 'tap') {
        if (laneAt(px) === n.lane && Math.abs(py - yOf(n.time)) <= 10) return { note: n, part: 'body' };
      } else if (n.type === 'hold') {
        if (laneAt(px) !== n.lane) continue;
        if (Math.abs(py - yOf(n.end)) <= 7) return { note: n, part: 'end' };
        if (py <= yOf(n.time) + 10 && py >= yOf(n.end) - 7) return { note: n, part: 'body' };
      }
    }
    for (let i = notes.length - 1; i >= 0; i--) {
      const n = notes[i];
      if (n.type !== 'field' || !Array.isArray(n.keys)) continue;
      const t = tAt(py);
      if (t < noteStart(n) || t > noteEnd(n)) continue;
      const [xl, xr] = fieldEdgeX(n, t);
      if (px >= xl && px <= xr) return { note: n, part: 'body' };
    }
    return null;
  }
  function noteBBox(n) {
    if (n.type === 'tap') return [L.laneX + n.lane * L.laneW, yOf(n.time) - 8, L.laneW, 16];
    if (n.type === 'hold') return [L.laneX + n.lane * L.laneW, yOf(n.end), L.laneW, yOf(n.time) - yOf(n.end)];
    if (n.type === 'flick') { const hw = Math.max(16, Core.flickWidth(n) * L.airW / 2); return [xAir(n.x) - hw, yOf(n.time) - 10, hw * 2, 20]; }
    const xs = n.keys.flatMap((k) => [k.center - k.width / 2, k.center + k.width / 2]);
    const x0 = xAir(Math.min(...xs)), x1 = xAir(Math.max(...xs));
    return [x0, yOf(noteEnd(n)), x1 - x0, yOf(noteStart(n)) - yOf(noteEnd(n))];
  }

  /* ------------------------------------------------------------ 렌더 */
  const canvas = $('#stage');
  const ctx = canvas.getContext('2d');
  const COL = { tap: '#4cc2ff', hold: '#4cffb0', flick: '#ffb454', field: '#b57bff' };

  function draw() {
    const dpr = window.devicePixelRatio || 1;
    const W = canvas.clientWidth, H = canvas.clientHeight;
    if (canvas.width !== Math.round(W * dpr) || canvas.height !== Math.round(H * dpr)) {
      canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    layout(W, H);
    ctx.clearRect(0, 0, W, H);
    ctx.font = '11px "Segoe UI", sans-serif';
    ctx.textBaseline = 'middle';

    const t0 = tAt(H + 20), t1 = tAt(-20);

    // 패널 배경
    ctx.fillStyle = '#171a24';
    ctx.fillRect(L.airX, 0, L.airW, H);
    ctx.fillRect(L.laneX, 0, L.laneW * K.LANE_COUNT, H);
    ctx.fillStyle = '#c9d0e4'; ctx.textAlign = 'center';
    ctx.fillText('AIR (flick / field)', L.airX + L.airW / 2, 10);
    for (let l = 0; l < K.LANE_COUNT; l++) {
      ctx.fillStyle = l % 2 ? '#1b1f2b' : '#181b26';
      ctx.fillRect(L.laneX + l * L.laneW, 0, L.laneW, H);
      ctx.fillStyle = '#c9d0e4';
      ctx.fillText(K.LANE_KEYS[l], laneCx(l), 10);
    }

    // 연출 트랙 배경
    FX_TYPES.forEach((ty, i) => {
      ctx.fillStyle = i % 2 ? '#1b1f2b' : '#181b26';
      ctx.fillRect(L.fxX + i * fxSubW(), 0, fxSubW(), H);
    });

    drawWaveform(t0, t1);

    // 그리드
    // 선 색으로 박을 구분한다: 마디(밝고 굵게) > 박 > 반 박(파랑) > 1/16(노랑) / 셋잇단(보라)
    const gdiv = S.snap || 4;
    const stepPx = ((60000 / S.timing.bpmAt(S.cur)) * (4 / gdiv) * S.pps) / 1000;
    const beatPx = ((60000 / S.timing.bpmAt(S.cur)) * S.pps) / 1000;
    const GRID_COL = { 8: '#3f78c4', 16: '#8d8440', 12: '#8a55c2', 99: '#2a3042' };
    const barEvery = Math.max(1, Math.ceil(26 / (beatPx * 4))); // 마디 번호가 겹치지 않게 건너뛴다
    for (const g of S.timing.gridLines(t0, t1, gdiv)) {
      if (!g.onBeat && stepPx < 4) continue;
      if (g.onBeat && !g.strong && beatPx < 6) continue;
      const y = Math.round(yOf(g.t)) + 0.5;
      const kind = g.onBeat ? 0 : gridKind(g.t);
      ctx.strokeStyle = g.strong ? '#9aa6d6' : g.onBeat ? '#535d84' : GRID_COL[kind];
      ctx.globalAlpha = g.onBeat ? 1 : kind === 99 ? 1 : 0.6;
      ctx.lineWidth = g.strong ? 2 : 1;
      ctx.beginPath();
      if (g.onBeat) { ctx.moveTo(6, y); ctx.lineTo(L.waveCx + L.waveHalf + 2, y); } // 파형 위에도 박 선
      ctx.moveTo(L.airX, y); ctx.lineTo(L.airX + L.airW, y);
      ctx.moveTo(L.laneX, y); ctx.lineTo(L.laneX + L.laneW * 4, y);
      if (g.onBeat) { ctx.moveTo(L.fxX, y); ctx.lineTo(L.fxX + L.fxW, y); }
      ctx.stroke();
      ctx.globalAlpha = 1; ctx.lineWidth = 1;
      if (g.strong && g.t >= -0.5) {
        const bar = Math.round(g.beat / 4);
        if (bar % barEvery === 0) {
          ctx.textAlign = 'right';
          ctx.fillStyle = '#c9d0e4'; ctx.font = '600 12px "Segoe UI", sans-serif';
          ctx.fillText(String(bar + 1), L.gutter - 6, y - 7);
          ctx.fillStyle = '#6f7896'; ctx.font = '10px "Segoe UI", sans-serif';
          ctx.fillText((g.t / 1000).toFixed(2) + 's', L.gutter - 6, y + 6);
          ctx.font = '11px "Segoe UI", sans-serif';
        }
      }
    }
    // 공중 평면 세로 눈금 (0, .25, .5, .75, 1)
    ctx.strokeStyle = '#262c3d';
    for (let i = 0; i <= 4; i++) {
      const x = Math.round(xAir(i / 4)) + 0.5;
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke();
    }
    // BPM 변화 표시
    ctx.textAlign = 'left';
    for (const p of S.timing.pts) {
      if (p.time < t0 || p.time > t1) continue;
      const y = Math.round(yOf(p.time)) + 0.5;
      ctx.strokeStyle = '#ff7acb'; ctx.beginPath(); ctx.moveTo(L.airX, y); ctx.lineTo(L.laneX + L.laneW * 4, y); ctx.stroke();
      ctx.fillStyle = '#ff7acb'; ctx.textAlign = 'right'; ctx.fillText(`${p.bpm} BPM`, L.airX + L.airW - 6, y - 7); ctx.textAlign = 'left';
    }

    // 노트 (필드 → 홀드 → 탭 → 플릭 순으로 그려 위에 오도록)
    const vis = (n) => noteEnd(n) >= t0 - 100 && noteStart(n) <= t1 + 100;
    const list = S.chart.notes.filter((n) => (n.type !== 'field' || Array.isArray(n.keys)) && vis(n));
    for (const n of list) if (n.type === 'field') drawField(n, S.sel.has(n.id));
    for (const n of list) if (n.type === 'hold') drawHold(n, S.sel.has(n.id));
    for (const n of list) if (n.type === 'tap') drawTap(n, S.sel.has(n.id));
    for (const n of list) if (n.type === 'flick') drawFlick(n.x, yOf(n.time), n.dir, S.sel.has(n.id), 1, Core.flickWidth(n));
    drawFx(t0, t1);

    if (S.hover && S.hover.gutter) { // 시간 눈금 위: 테스트 시작 위치 미리보기
      const y = Math.round(yOf(S.hover.t)) + 0.5;
      ctx.strokeStyle = '#ffffffaa'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(L.laneX + L.laneW * 4 + 6, y); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = '#ffffff'; ctx.textAlign = 'left'; ctx.fillText('▶ 테스트', 4, y - 9);
    } else drawDraftAndGhost();

    // 판정선 (테스트 중 = 곡을 따라 움직이는 흰 선 + 시작 지점 표시)
    if (S.test) {
      const ys = Math.round(yOf(S.test.from)) + 0.5;
      ctx.strokeStyle = '#ff5d6c88'; ctx.setLineDash([6, 5]);
      ctx.beginPath(); ctx.moveTo(L.airX - 6, ys); ctx.lineTo(L.laneX + L.laneW * 4 + 6, ys); ctx.stroke();
      ctx.setLineDash([]);
    }
    const lineY = S.test ? yOf(S.cur) : L.recY;
    ctx.strokeStyle = S.test ? '#ffffff' : '#ff5d6c'; ctx.lineWidth = S.test ? 3 : 2;
    if (S.test) { ctx.shadowColor = '#ffffff'; ctx.shadowBlur = 10; }
    ctx.beginPath();
    ctx.moveTo(L.airX - 6, lineY); ctx.lineTo(L.airX + L.airW + 6, lineY);
    ctx.moveTo(L.laneX - 6, lineY); ctx.lineTo(L.laneX + L.laneW * 4 + 6, lineY);
    ctx.stroke();
    ctx.shadowBlur = 0;
    ctx.lineWidth = 1;

    // 박스 선택
    const d = S.drag;
    if (d && d.type === 'box') {
      ctx.strokeStyle = '#5b8cff'; ctx.fillStyle = '#5b8cff22';
      const x = Math.min(d.x0, d.x1), y = Math.min(d.y0, d.y1), w = Math.abs(d.x1 - d.x0), hh = Math.abs(d.y1 - d.y0);
      ctx.fillRect(x, y, w, hh); ctx.strokeRect(x + 0.5, y + 0.5, w, hh);
    }

    // 스크롤바
    const total = totalMs();
    const frac = clamp(S.cur / total, 0, 1);
    ctx.fillStyle = '#20253a'; ctx.fillRect(W - 12, 0, 12, H);
    ctx.fillStyle = '#5b8cff'; ctx.fillRect(W - 12, (1 - frac) * (H - 26), 12, 26);
  }

  /** 연출 효과 트랙: 종류마다 한 칸. 머리 = 시작 시각, 위로 뻗은 띠 = 길이(duration) */
  function drawFx(t0, t1) {
    const sw = fxSubW();
    const block = (i, time, dur, sel, alpha, live) => {
      const col = FX[FX_TYPES[i]].color, x = L.fxX + i * sw + 2, w = sw - 4, y0 = yOf(time), y1 = yOf(time + dur);
      ctx.globalAlpha = alpha;
      if (dur > 0) {
        ctx.fillStyle = col + '44'; ctx.fillRect(x + 3, y1, w - 6, y0 - y1);
        ctx.fillStyle = col; ctx.fillRect(x + 3, y1 - 1, w - 6, 3);
      }
      ctx.fillStyle = live ? '#ffffff' : col; roundRect(x, y0 - 6, w, 12, 3); ctx.fill();
      if (sel) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke(); if (dur > 0) ctx.strokeRect(x + 3, y1, w - 6, y0 - y1); ctx.lineWidth = 1; }
      ctx.globalAlpha = 1;
    };
    for (const f of S.chart.effects) {
      const i = FX_TYPES.indexOf(f.type);
      if (i < 0 || fxEnd(f) < t0 - 100 || f.time > t1 + 100) continue;
      const live = S.playing && S.cur >= f.time && S.cur <= Math.max(fxEnd(f), f.time + 150); // 재생 중 지나가는 효과는 하얗게
      block(i, f.time, +f.duration || 0, f.id === S.fxSel, 1, live);
    }
    const d = S.drag;
    if (d && d.type === 'newFx') block(FX_TYPES.indexOf(d.kind), Math.min(d.t0, d.t1), Math.abs(d.t1 - d.t0), false, 0.6, false);
    // 머리글
    ctx.fillStyle = '#10121aee'; ctx.fillRect(L.fxX, 0, L.fxW, 20);
    ctx.textAlign = 'center'; ctx.font = '10px "Segoe UI", "Malgun Gothic", sans-serif';
    FX_TYPES.forEach((ty, i) => { ctx.fillStyle = FX[ty].color; ctx.fillText(FX[ty].short, L.fxX + (i + 0.5) * sw, 10); });
    ctx.font = '11px "Segoe UI", sans-serif';
  }

  function drawWaveform(t0, t1) {
    if (!S.peaks) return;
    const off = +S.chart.meta.offset || 0;
    const cx = L.waveCx, half = L.waveHalf, b = S.peakBucketMs;
    ctx.fillStyle = '#0d0f16'; ctx.fillRect(cx - half - 2, 0, half * 2 + 4, L.H);
    ctx.fillStyle = '#4f8fe0';
    const rows = Math.min(L.H, 1200);
    for (let i = 0; i < rows; i++) {
      const y = (i / rows) * L.H;
      const t = tAt(y) - off;
      if (t < 0 || t > S.audioDur) continue;
      const k = Math.floor(t / b);
      // 한 픽셀 행이 덮는 버킷 범위의 최대값
      const span = Math.max(1, Math.ceil((1000 / S.pps / (rows / L.H)) / b));
      let m = 0;
      for (let j = 0; j < span && k + j < S.peaks.length; j++) m = Math.max(m, S.peaks[k + j]);
      if (m > 0) ctx.fillRect(cx - m * half, y, m * half * 2, Math.ceil(L.H / rows) + 1);
    }
  }

  function roundRect(x, y, w, hh, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + hh, r); ctx.arcTo(x + w, y + hh, x, y + hh, r);
    ctx.arcTo(x, y + hh, x, y, r); ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  function drawTap(n, sel, alpha) {
    const x = L.laneX + n.lane * L.laneW + 3, y = yOf(n.time) - 8;
    ctx.globalAlpha = alpha || 1;
    ctx.fillStyle = COL.tap; roundRect(x, y, L.laneW - 6, 16, 4); ctx.fill();
    if (sel) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1; }
    ctx.globalAlpha = 1;
  }
  function drawHold(n, sel, alpha) {
    const x = L.laneX + n.lane * L.laneW + 3, w = L.laneW - 6;
    const yt = yOf(n.time), ye = yOf(n.end);
    ctx.globalAlpha = alpha || 1;
    ctx.fillStyle = '#4cffb055'; ctx.fillRect(x + 6, ye, w - 12, yt - ye);
    ctx.fillStyle = COL.hold; roundRect(x, yt - 8, w, 16, 4); ctx.fill();
    ctx.fillStyle = '#2bd68c'; roundRect(x, ye - 4, w, 8, 3); ctx.fill();
    if (sel) {
      ctx.strokeStyle = '#fff'; ctx.lineWidth = 2;
      ctx.strokeRect(x + 6, ye, w - 12, yt - ye); roundRect(x, yt - 8, w, 16, 4); ctx.stroke(); ctx.lineWidth = 1;
    }
    ctx.globalAlpha = 1;
  }
  function drawFlick(xv, y, dir, sel, alpha, width) {
    const x = xAir(xv), s = dir === 'left' ? -1 : 1;
    ctx.globalAlpha = alpha;
    // 폭: 옅은 띠 + 양 끝 눈금 (커서가 이 안을 화살표 방향으로 지나가면 성공)
    const hw = (width === undefined ? K.FLICK_DEFAULT_WIDTH : width) * L.airW / 2;
    ctx.fillStyle = COL.flick + '38'; ctx.fillRect(x - hw, y - 3, hw * 2, 6);
    ctx.fillStyle = COL.flick; ctx.fillRect(x - hw - 1, y - 7, 2, 14); ctx.fillRect(x + hw - 1, y - 7, 2, 14);
    ctx.fillStyle = COL.flick;
    ctx.beginPath();
    ctx.moveTo(x + s * 18, y); ctx.lineTo(x, y - 11); ctx.lineTo(x, y - 4); ctx.lineTo(x - s * 16, y - 4);
    ctx.lineTo(x - s * 16, y + 4); ctx.lineTo(x, y + 4); ctx.lineTo(x, y + 11);
    ctx.closePath(); ctx.fill();
    if (sel) { ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke(); ctx.lineWidth = 1; }
    ctx.globalAlpha = 1;
  }
  function fieldPath(keys) {
    ctx.beginPath();
    keys.forEach((k, i) => { const x = xAir(k.center - k.width / 2), y = yOf(k.time); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
    for (let i = keys.length - 1; i >= 0; i--) ctx.lineTo(xAir(keys[i].center + keys[i].width / 2), yOf(keys[i].time));
    ctx.closePath();
  }
  function drawField(n, sel) {
    fieldPath(n.keys);
    ctx.fillStyle = sel ? '#b57bff55' : '#b57bff33'; ctx.fill();
    ctx.strokeStyle = sel ? '#fff' : COL.field; ctx.lineWidth = sel ? 2 : 1; ctx.stroke(); ctx.lineWidth = 1;
    ctx.strokeStyle = '#b57bff88'; ctx.beginPath();
    n.keys.forEach((k, i) => { const x = xAir(k.center), y = yOf(k.time); i ? ctx.lineTo(x, y) : ctx.moveTo(x, y); });
    ctx.stroke();
    for (const k of n.keys) {
      const y = yOf(k.time);
      ctx.fillStyle = COL.field; ctx.beginPath(); ctx.arc(xAir(k.center), y, 5, 0, 7); ctx.fill();
      ctx.fillStyle = sel ? '#fff' : '#e3d2ff';
      ctx.fillRect(xAir(k.center - k.width / 2) - 2, y - 5, 4, 10);
      ctx.fillRect(xAir(k.center + k.width / 2) - 2, y - 5, 4, 10);
    }
  }
  function drawDraftAndGhost() {
    const hv = S.hover;
    if (S.drag && S.drag.type === 'newHold') {
      if (S.drag.tapTool && S.drag.t1 === S.drag.t0) drawTap({ lane: S.drag.lane, time: S.drag.t0 }, false, 0.6);
      else {
        const a = Math.min(S.drag.t0, S.drag.t1), b = Math.max(S.drag.t0, S.drag.t1, S.drag.t0 + stepMsAt(S.drag.t0));
        drawHold({ lane: S.drag.lane, time: a, end: b }, false, 0.6);
      }
    }
    // 지금 찍히는 위치(스냅된 시각)를 가로선과 "마디·박" 글자로 보여 준다
    const st = S.drag && (S.drag.type === 'newHold' || S.drag.type === 'newFx') ? S.drag.t1
      : hv && !S.drag && ((S.tool !== 'select' && (hv.lane >= 0 || hv.air)) || hv.fx >= 0) ? hv.t : null;
    if (st != null) {
      const y = Math.round(yOf(st)) + 0.5;
      ctx.strokeStyle = '#ffffff66';
      ctx.beginPath(); ctx.moveTo(6, y); ctx.lineTo(L.fxX + L.fxW, y); ctx.stroke();
      const txt = beatLabel(st);
      ctx.font = '600 11px "Segoe UI", sans-serif'; ctx.textAlign = 'left';
      const tw = ctx.measureText(txt).width;
      ctx.fillStyle = '#000000cc'; ctx.fillRect(L.airX + 4, y - 19, tw + 10, 16);
      ctx.fillStyle = '#ffffff'; ctx.fillText(txt, L.airX + 9, y - 11);
      ctx.font = '11px "Segoe UI", sans-serif';
    }
    if (S.draft) {
      const keys = S.draft.keys;
      if (keys.length >= 2) drawField({ keys }, true);
      else if (keys.length === 1) drawField({ keys: [keys[0], { ...keys[0], time: keys[0].time + 1 }] }, true);
      if (hv && hv.air && S.tool === 'field') {
        const last = keys[keys.length - 1];
        if (last && hv.t > last.time) {
          ctx.setLineDash([4, 4]); ctx.strokeStyle = '#b57bffaa';
          ctx.beginPath(); ctx.moveTo(xAir(last.center), yOf(last.time)); ctx.lineTo(xAir(hv.x), yOf(hv.t)); ctx.stroke(); ctx.setLineDash([]);
        }
      }
    }
    if (!hv || S.drag) return;
    if ((S.tool === 'tap' || S.tool === 'hold') && hv.lane >= 0) {
      drawTap({ lane: hv.lane, time: hv.t }, false, 0.4);
    } else if (S.tool === 'flick' && hv.air) {
      drawFlick(hv.x, yOf(hv.t), S.flickDir, false, 0.5, S.flickWidth);
    } else if (S.tool === 'field' && hv.air) {
      const w = S.defWidth;
      ctx.fillStyle = '#b57bff44'; ctx.fillRect(xAir(hv.x - w / 2), yOf(hv.t) - 3, w * L.airW, 6);
    }
  }

  /* ------------------------------------------------------------ 입력(캔버스) */
  function pos(e) { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; }

  function updateHover(px, py, e) {
    const t = snapT(tAt(py));
    S.hover = { t, lane: laneAt(px), air: inAir(px), x: snapX(airVal(px), e && e.altKey), gutter: px < L.gutter - 4, fx: fxAt(px) };
    canvas.style.cursor = S.hover.gutter ? 'pointer' : S.hover.fx >= 0 ? 'crosshair' : S.tool === 'select' ? 'default' : 'crosshair';
    if (S.hover.fx >= 0) { setStatus(`${beatLabel(t)} · ${Math.round(t)}ms · 연출: ${FX[FX_TYPES[S.hover.fx]].name} — 클릭 = 추가, 위로 끌면 길이, 우클릭 = 삭제`); return invalidate(); }
    if (S.hover.gutter) { setStatus(`클릭: ${(t / 1000).toFixed(2)}s 부터 테스트`); return invalidate(); }
    setStatus(`${beatLabel(t)} · ${Math.round(t)}ms${S.hover.lane >= 0 ? ' · 레인 ' + K.LANE_KEYS[S.hover.lane] : S.hover.air ? ' · x=' + S.hover.x.toFixed(2) : ''}`);
    if (S.tool === 'select' && S.hover.air) {
      const hh = hit(px, py);
      if (hh && hh.part === 'flickEdge') { canvas.style.cursor = 'ew-resize'; setStatus(`플릭 폭 ${Core.flickWidth(hh.note).toFixed(2)} — 끌어서 조절`); }
    }
    invalidate();
  }

  canvas.addEventListener('contextmenu', (e) => e.preventDefault());
  canvas.addEventListener('mousedown', (e) => {
    const [px, py] = pos(e);
    canvas.focus();
    if (px > L.W - 16) { scrubTo(py); S.drag = { type: 'scrub' }; return; }
    if (px < L.gutter - 4 && e.button === 0) return startTest(snapT(tAt(py))); // 시간 눈금 클릭 = 그 위치부터 테스트
    if (e.button === 2) return rightClick(px, py);
    if (e.button !== 0) return;
    if (fxAt(px) >= 0) return fxDown(px, py); // 연출 트랙은 어떤 도구를 들고 있어도 같은 방식으로 다룬다
    const t = snapT(tAt(py));
    switch (S.tool) {
      case 'select': return selectDown(px, py, e);
      case 'tap': {
        const lane = laneAt(px);
        if (lane < 0) return toast('탭은 오른쪽 4레인에 배치합니다');
        S.drag = { type: 'newHold', lane, t0: t, t1: t, tapTool: true }; // 그냥 클릭 = 탭, 위아래로 끌면 홀드
        return;
      }
      case 'hold': {
        const lane = laneAt(px);
        if (lane < 0) return toast('홀드는 오른쪽 4레인에 배치합니다');
        S.drag = { type: 'newHold', lane, t0: t, t1: t };
        return;
      }
      case 'flick': {
        if (!inAir(px)) return toast('플릭은 왼쪽 공중 영역에 배치합니다');
        const h0 = hit(px, py);
        if (h0 && h0.note.type === 'flick') return mutate(() => { S.chart.notes = S.chart.notes.filter((n) => n !== h0.note); });
        return mutate(() => addNote({ type: 'flick', time: t, x: snapX(airVal(px), e.altKey), dir: S.flickDir, width: S.flickWidth }));
      }
      case 'field': {
        if (!inAir(px)) return toast('필드는 왼쪽 공중 영역에 배치합니다');
        const key = { time: t, center: snapX(airVal(px), e.altKey), width: S.defWidth };
        if (!S.draft) S.draft = { keys: [] };
        const keys = S.draft.keys;
        const same = keys.findIndex((k) => Math.round(k.time) === Math.round(t));
        if (same >= 0) keys[same] = key; else { keys.push(key); keys.sort((a, b) => a.time - b.time); }
        setStatus(`필드 키프레임 ${keys.length}개 — Enter 로 확정, 우클릭/Backspace 로 마지막 취소, Esc 로 취소`);
        invalidate();
      }
    }
  });

  function fxDown(px, py) {
    const hh = fxHit(px, py), t = snapT(tAt(py));
    S.sel.clear();
    if (hh) {
      S.fxSel = hh.fx.id;
      S.drag = { type: hh.part === 'end' ? 'fxEnd' : 'fxMove', fx: hh.fx, startT: tAt(py), orig: hh.fx.time, snap0: snapshot() };
      showTab('props'); renderPanels();
      return invalidate();
    }
    S.drag = { type: 'newFx', kind: FX_TYPES[fxAt(px)], t0: t, t1: t };
    invalidate();
  }

  function rightClick(px, py) {
    if (S.draft) { S.draft.keys.pop(); if (!S.draft.keys.length) S.draft = null; return invalidate(); }
    const fh = fxHit(px, py);
    if (fh) return deleteFx(fh.fx.id);
    const h0 = hit(px, py);
    if (!h0) return;
    if (h0.note.type === 'field' && h0.part === 'key' && h0.note.keys.length > 2) {
      return mutate(() => h0.note.keys.splice(h0.idx, 1));
    }
    mutate(() => { S.chart.notes = S.chart.notes.filter((n) => n !== h0.note); S.sel.delete(h0.note.id); });
  }

  function selectDown(px, py, e) {
    S.fxSel = null;
    const h0 = hit(px, py);
    if (!h0) {
      if (!e.shiftKey) S.sel.clear();
      S.drag = { type: 'box', x0: px, y0: py, x1: px, y1: py, base: new Set(S.sel) };
      return renderPanels();
    }
    const n = h0.note;
    if (e.shiftKey) { S.sel.has(n.id) ? S.sel.delete(n.id) : S.sel.add(n.id); }
    else if (!S.sel.has(n.id)) { S.sel.clear(); S.sel.add(n.id); }
    renderPanels(); invalidate();
    const snap0 = snapshot();
    if (h0.part === 'key') S.drag = { type: 'key', note: n, idx: h0.idx, edge: h0.edge, snap0 };
    else if (h0.part === 'end') S.drag = { type: 'holdEnd', note: n, snap0 };
    else if (h0.part === 'flickEdge') S.drag = { type: 'flickW', note: n, snap0 };
    else {
      const orig = new Map(selNotes().map((o) => [o.id, JSON.parse(JSON.stringify(o))]));
      S.drag = { type: 'move', anchor: n, startT: tAt(py), startPx: px, orig, snap0 };
    }
  }

  window.addEventListener('mousemove', (e) => {
    if (S.test && (document.pointerLockElement || e.target === testCanvas)) return testMouse(e);
    const [px, py] = pos(e);
    const d = S.drag;
    if (!d) { if (e.target === canvas) updateHover(px, py, e); return; }
    if (d.type === 'scrub') return scrubTo(py);
    if (d.type === 'newHold' || d.type === 'newFx') { d.t1 = snapT(tAt(py)); return invalidate(); }
    if (d.type === 'box') { d.x1 = px; d.y1 = py; return invalidate(); }
    const touch = () => { if (!d.pushed) { pushUndo(d.snap0); d.pushed = true; } };
    if (d.type === 'fxMove') {
      const nt = Math.max(0, snapT(d.orig + (tAt(py) - d.startT)));
      if (nt !== d.fx.time) { touch(); d.fx.time = nt; changed(); }
    } else if (d.type === 'fxEnd') {
      const nd = Math.max(0, Math.round(snapT(tAt(py)) - d.fx.time));
      if (nd !== d.fx.duration) { touch(); d.fx.duration = nd; changed(); }
    } else if (d.type === 'holdEnd') {
      const end = Math.max(snapT(tAt(py)), d.note.time + 1);
      if (end !== d.note.end) { touch(); d.note.end = end; changed(); }
    } else if (d.type === 'flickW') {
      // 플릭 끝을 끌면 폭이 바뀐다 (중심은 그대로, 필드 폭과 같은 방식). 다음에 찍는 플릭도 이 폭을 쓴다
      const w = clamp(round3(2 * Math.abs(snapX(airVal(px), e.altKey) - d.note.x)), K.FLICK_MIN_WIDTH, 1);
      if (w !== Core.flickWidth(d.note)) { touch(); d.note.width = w; S.flickWidth = w; store.set('flickWidth', w); changed(); }
    } else if (d.type === 'key') {
      const n = d.note, k = n.keys[d.idx];
      if (d.edge === 'c') {
        const lo = d.idx > 0 ? n.keys[d.idx - 1].time + 1 : -Infinity;
        const hi = d.idx < n.keys.length - 1 ? n.keys[d.idx + 1].time - 1 : Infinity;
        const nt = clamp(snapT(tAt(py)), lo, hi), nc = snapX(airVal(px), e.altKey);
        if (nt !== k.time || nc !== k.center) { touch(); k.time = nt; k.center = nc; changed(); }
      } else {
        const edgeV = snapX(airVal(px), e.altKey);
        const w = clamp(round3(2 * Math.abs(edgeV - k.center)), 0.02, 1);
        if (w !== k.width) { touch(); k.width = w; S.defWidth = w; changed(); }
      }
    } else if (d.type === 'move') {
      applyMove(d, px, py, e);
    }
  });
  window.addEventListener('mouseup', () => {
    const d = S.drag;
    if (!d) return;
    S.drag = null;
    if (d.type === 'newFx') {
      const a = Math.min(d.t0, d.t1), b = Math.max(d.t0, d.t1), spec = FX[d.kind];
      mutate(() => {
        const f = Object.assign({ id: newId(), type: d.kind, time: a, duration: b > a ? Math.round(b - a) : spec.dur }, spec.params);
        S.chart.effects.push(f); S.fxSel = f.id;
      });
      S.sel.clear(); showTab('props');
    } else if (d.type === 'newHold' && d.tapTool && d.t1 === d.t0) {
      toggleTap(d.lane, d.t0);
    } else if (d.type === 'newHold') {
      const a = Math.min(d.t0, d.t1);
      let b = Math.max(d.t0, d.t1);
      if (b <= a) b = a + stepMsAt(a);
      if (laneConflict(d.lane, a, b)) toast('같은 레인의 다른 노트와 겹칩니다');
      else mutate(() => addNote({ type: 'hold', time: a, end: Math.round(b), lane: d.lane }));
    } else if (d.type === 'box') {
      const x = Math.min(d.x0, d.x1), y = Math.min(d.y0, d.y1), w = Math.abs(d.x1 - d.x0), hh = Math.abs(d.y1 - d.y0);
      if (w > 3 || hh > 3) {
        for (const n of S.chart.notes) {
          if (n.type === 'field' && !Array.isArray(n.keys)) continue;
          const [bx, by, bw, bh] = noteBBox(n);
          if (bx < x + w && bx + bw > x && by < y + hh && by + bh > y) S.sel.add(n.id);
        }
      }
      renderPanels();
    }
    invalidate();
  });

  function applyMove(d, px, py, e) {
    const origs = [...d.orig.values()];
    const a0 = d.orig.get(d.anchor.id);
    let dt = snapT(noteStart(a0) + (tAt(py) - d.startT)) - noteStart(a0);
    const minStart = Math.min(...origs.map(noteStart));
    dt = Math.max(dt, -minStart);
    const ground = origs.filter((o) => o.type === 'tap' || o.type === 'hold');
    let dl = 0;
    if (ground.length) {
      dl = Math.round((px - d.startPx) / L.laneW);
      dl = clamp(dl, -Math.min(...ground.map((o) => o.lane)), K.LANE_COUNT - 1 - Math.max(...ground.map((o) => o.lane)));
    }
    const air = origs.filter((o) => o.type === 'flick' || o.type === 'field');
    let dx = 0;
    if (air.length) {
      const step = e.altKey ? 0.01 : 0.05;
      dx = Math.round(((px - d.startPx) / L.airW) / step) * step;
      const xs = air.flatMap((o) => (o.type === 'flick' ? [o.x] : o.keys.map((k) => k.center)));
      dx = clamp(dx, -Math.min(...xs), 1 - Math.max(...xs));
    }
    if (!d.pushed && dt === 0 && dl === 0 && dx === 0) return;
    if (!d.pushed) { pushUndo(d.snap0); d.pushed = true; }
    for (const n of selNotes()) {
      const o = d.orig.get(n.id);
      if (!o) continue;
      if (n.type === 'tap') { n.time = o.time + dt; n.lane = o.lane + dl; }
      else if (n.type === 'hold') { n.time = o.time + dt; n.end = o.end + dt; n.lane = o.lane + dl; }
      else if (n.type === 'flick') { n.time = o.time + dt; n.x = round3(o.x + dx); }
      else if (n.type === 'field') n.keys.forEach((k, i) => { k.time = o.keys[i].time + dt; k.center = round3(o.keys[i].center + dx); });
    }
    changed();
  }

  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    if (e.ctrlKey) {
      S.pps = clamp(S.pps * (e.deltaY < 0 ? 1.12 : 1 / 1.12), 60, 1200);
      $('#zoom').value = clamp(S.pps, 80, 900); store.set('pps', S.pps);
    } else if (e.altKey && (S.tool === 'flick' || S.chart.notes.some((n) => n.type === 'flick' && S.sel.has(n.id)))) {
      // Alt+휠: 선택한 플릭의 폭, 선택이 없으면 새로 찍을 플릭의 폭
      const d = e.deltaY < 0 ? 0.05 : -0.05;
      const fit = (w) => clamp(round3(w + d), K.FLICK_MIN_WIDTH, 1);
      const picked = S.chart.notes.filter((n) => n.type === 'flick' && S.sel.has(n.id));
      if (picked.length) mutate(() => { for (const n of picked) n.width = fit(Core.flickWidth(n)); });
      else { S.flickWidth = fit(S.flickWidth); store.set('flickWidth', S.flickWidth); invalidate(); }
    } else if (e.altKey && S.tool === 'field') {
      S.defWidth = clamp(round3(S.defWidth + (e.deltaY < 0 ? 0.02 : -0.02)), 0.02, 1);
      $('#defWidth').value = S.defWidth.toFixed(2); store.set('defWidth', S.defWidth);
    } else if (e.shiftKey) {
      stepCursor(e.deltaY > 0 ? 1 : -1);
    } else {
      setCur(viewT() + (e.deltaY * 1000) / S.pps);
    }
    invalidate();
  }, { passive: false });

  function scrubTo(py) { setCur((1 - clamp(py / (L.H - 26), 0, 1)) * totalMs()); }
  function setCur(t) {
    if (S.test) { // 테스트 중: 재생은 그대로 두고 화면만 옮긴다. 잠시 자동 따라가기를 멈춤
      S.test.view = clamp(t, -3000, totalMs() + 5000);
      S.test.holdFollow = performance.now() + 1500;
      return invalidate();
    }
    S.cur = clamp(t, -3000, totalMs() + 5000);
    if (S.playing) seekPlaying();
    invalidate();
  }
  function stepCursor(dir) {
    const t = viewT();
    const g = S.timing.snap(t, snapDiv());
    if (dir > 0) setCur(g > t + 0.5 ? g : g + stepMsAt(g));
    else setCur(g < t - 0.5 ? g : g - stepMsAt(g));
    setCur(S.timing.snap(viewT(), snapDiv()));
  }

  /* ------------------------------------------------------------ 키보드 */
  const TOOL_KEYS = { 1: 'select', 2: 'tap', 3: 'hold', 4: 'flick', 5: 'field' };
  window.addEventListener('keydown', (e) => {
    const tag = (e.target.tagName || '').toLowerCase();
    const typing = tag === 'input' || tag === 'textarea' || tag === 'select';
    const ctrl = e.ctrlKey || e.metaKey;
    if (S.test && !typing && !ctrl && testKey(e, true)) return;
    if (ctrl && e.key.toLowerCase() === 's') { e.preventDefault(); return save(); }
    if (typing) return;
    if (ctrl && e.key.toLowerCase() === 'z') { e.preventDefault(); return e.shiftKey ? redo() : undo(); }
    if (ctrl && e.key.toLowerCase() === 'y') { e.preventDefault(); return redo(); }
    if (ctrl && e.key.toLowerCase() === 'c') return copySelected();
    if (ctrl && e.key.toLowerCase() === 'v') return paste();
    if (ctrl && e.key.toLowerCase() === 'a') { e.preventDefault(); S.chart.notes.forEach((n) => S.sel.add(n.id)); renderPanels(); return invalidate(); }
    if (TOOL_KEYS[e.key]) return setTool(TOOL_KEYS[e.key]);
    const laneKey = { KeyA: 0, KeyS: 1, KeyD: 2, KeyF: 3 }[e.code];
    if (laneKey != null && !ctrl && !e.altKey) { e.preventDefault(); if (!e.repeat) laneInput(laneKey, e); return; }
    switch (e.key) {
      case 'b': case 'B': return tapTempo(e);
      case 'q': case 'Q': return quantizeSelected();
      case 'r': case 'R': return setRec(!S.rec);
      case ' ': e.preventDefault(); return S.playing ? stop() : play();
      // (테스트 중 Space/R/T/Esc 는 testKey 가 먼저 처리)
      case 'Delete': return S.fxSel != null && !S.sel.size ? deleteFx(S.fxSel) : deleteSelected();
      case 'Escape': if (S.draft) { S.draft = null; invalidate(); } else { S.sel.clear(); S.fxSel = null; renderPanels(); invalidate(); } return;
      case 'Enter': return commitDraft();
      case 'Backspace': if (S.draft) { S.draft.keys.pop(); if (!S.draft.keys.length) S.draft = null; invalidate(); } return;
      case 'Tab': e.preventDefault(); return setFlickDir(S.flickDir === 'left' ? 'right' : 'left');
      case 'm': case 'M': return mirrorSelected();
      case 'ArrowUp': e.preventDefault(); return e.shiftKey ? shiftSelected(1) : stepCursor(1);
      case 'ArrowDown': e.preventDefault(); return e.shiftKey ? shiftSelected(-1) : stepCursor(-1);
      case 'PageUp': return setCur(S.cur + (240000 / S.timing.bpmAt(S.cur)));
      case 'PageDown': return setCur(S.cur - (240000 / S.timing.bpmAt(S.cur)));
      case 'Home': return setCur(0);
      case 'End': return setCur(S.stats && S.stats.endTime ? S.stats.endTime : totalMs());
      case 't': case 'T': return startTest();
      case '[': return cycleSnap(-1);
      case ']': return cycleSnap(1);
    }
  });

  function commitDraft() {
    const dr = S.draft;
    if (!dr) return;
    if (dr.keys.length < 2) return toast('필드는 키프레임이 2개 이상 필요합니다');
    const s = dr.keys[0].time, en = dr.keys[dr.keys.length - 1].time;
    if (fieldConflict(s, en)) return toast('다른 필드와 시간이 겹칩니다 (필드끼리 겹침 금지)');
    S.draft = null;
    mutate(() => { const n = addNote({ type: 'field', keys: dr.keys }); S.sel = new Set([n.id]); });
  }
  function setTool(t) {
    if (S.draft && t !== 'field') { S.draft.keys.length >= 2 ? commitDraft() : (S.draft = null); }
    S.tool = t;
    document.querySelectorAll('#tools button').forEach((b) => b.classList.toggle('on', b.dataset.tool === t));
    canvas.style.cursor = t === 'select' ? 'default' : 'crosshair';
    invalidate();
  }
  function setFlickDir(d) { S.flickDir = d; store.set('flickDir', d); $('#btnFlickDir').textContent = d === 'left' ? '←' : '→'; invalidate(); }
  function cycleSnap(dir) {
    const i = clamp(SNAPS.indexOf(S.snap) + dir, 0, SNAPS.length - 1);
    S.snap = SNAPS[i]; $('#snapSelect').value = S.snap; store.set('snap', S.snap); invalidate();
    toast('스냅: ' + SNAP_NAMES[S.snap], 900);
  }

  /* ------------------------------------------------------------ 오디오/재생 */
  const audioEl = new Audio();
  audioEl.preload = 'auto';
  let actx = null;
  const ac = () => actx || (actx = new (window.AudioContext || window.webkitAudioContext)());
  let playStartReal = 0, playStartCur = 0, audioStarted = false, lastCur = 0, hasAudio = false, drift = 0;
  /** 실제 시각 ts(performance.now 기준)의 곡 시간. 오디오 위치와의 차이(drift)를 천천히 따라간다. */
  const clockAt = (ts) => playStartCur + (ts - playStartReal) * S.rate + drift;

  async function loadAudio(folder, name) {
    S.peaks = null; S.audioDur = 0; hasAudio = false; S.audioBuf = null; S.autoFeat = null;
    audioEl.removeAttribute('src');
    if (!folder || !name) return;
    const url = withToken(`/audio/${encodeURIComponent(folder)}/${encodeURIComponent(name)}`);
    audioEl.src = url; hasAudio = true;
    try {
      const buf = await (await fetch(url)).arrayBuffer();
      const dec = await ac().decodeAudioData(buf);
      S.audioDur = dec.duration * 1000;
      S.audioBuf = dec; // 자동 생성 분석용
      const b = S.peakBucketMs, per = Math.max(1, Math.floor(dec.sampleRate * b / 1000));
      const n = Math.ceil(dec.length / per), peaks = new Float32Array(n);
      for (let c = 0; c < dec.numberOfChannels; c++) {
        const data = dec.getChannelData(c);
        for (let i = 0; i < n; i++) {
          let m = peaks[i];
          const end = Math.min(data.length, (i + 1) * per);
          for (let j = i * per; j < end; j++) { const v = Math.abs(data[j]); if (v > m) m = v; }
          peaks[i] = m;
        }
      }
      S.peaks = peaks;
      const wasDirty = S.dirty; // 오디오 길이로 검사만 다시 한다. 채보는 바뀌지 않았다
      changed();
      S.dirty = wasDirty;
    } catch (err) {
      setStatus('오디오를 불러올 수 없습니다: ' + err);
    }
  }

  /** 정해진 오디오 시각에 짧은 삑 소리 (메트로놈용. 프레임 타이밍에 흔들리지 않게 미리 예약한다) */
  function beepAt(when, freq, gain) {
    const c = ac(), o = c.createOscillator(), g = c.createGain();
    o.frequency.value = freq; o.type = 'sine';
    g.gain.setValueAtTime(gain, when); g.gain.exponentialRampToValueAtTime(0.0005, when + 0.06);
    o.connect(g).connect(c.destination); o.start(when); o.stop(when + 0.07);
  }
  let metroUntil = 0, recHintShown = false;
  const recDown = [null, null, null, null];

  function play() {
    if (S.playing) return;
    ac().resume();
    S.playing = true;
    metroUntil = S.cur - 1; recHintShown = false;
    playStartReal = performance.now(); playStartCur = S.cur; lastCur = S.cur; audioStarted = false; drift = 0;
    audioEl.playbackRate = S.rate;
    $('#btnPlay').textContent = '■ 정지';
  }
  function stop() {
    if (!S.playing) return;
    S.playing = false; audioEl.pause();
    $('#btnPlay').textContent = '▶ 재생';
    invalidate();
  }
  function seekPlaying() { const c = S.cur; stop(); S.cur = c; play(); }

  function click(freq) {
    if (!S.clap) return;
    const c = ac(), o = c.createOscillator(), g = c.createGain();
    o.frequency.value = freq; o.type = 'square';
    g.gain.setValueAtTime(0.08, c.currentTime); g.gain.exponentialRampToValueAtTime(0.0005, c.currentTime + 0.05);
    o.connect(g).connect(c.destination); o.start(); o.stop(c.currentTime + 0.06);
  }
  function tickPlayback() {
    const off = +S.chart.meta.offset || 0;
    const now = performance.now();
    if (hasAudio && !audioStarted) {
      const virtual = clockAt(now);
      if (virtual - off >= 0) {
        audioEl.currentTime = Math.max(0, (virtual - off) / 1000);
        audioEl.play().catch(() => {});
        audioStarted = true;
      }
    } else if (hasAudio && !audioEl.paused && audioEl.currentTime > 0) {
      const err = audioEl.currentTime * 1000 + off - clockAt(now);
      drift += Math.abs(err) > 250 ? err : err * 0.05; // 크게 어긋나면(시킹/멈춤) 바로, 아니면 천천히
    }
    S.cur = Math.max(S.cur, clockAt(now)); // 곡 시간은 되돌아가지 않는다

    if (S.metro && !S.test) { // 메트로놈: 박마다 삑(마디 첫 박은 높은 소리). 박자선이 노래와 맞는지 귀로 확인하는 용도
      const c = ac(), horizon = S.cur + 150 * S.rate;
      if (metroUntil < S.cur - 60) metroUntil = S.cur;
      for (const g of S.timing.gridLines(metroUntil, horizon, 4)) {
        if (g.t <= metroUntil + 1e-6 || g.t < 0) continue;
        beepAt(c.currentTime + Math.max(0, (g.t - S.cur) / (1000 * S.rate)), g.strong ? 1760 : 1175, g.strong ? 0.16 : 0.1);
      }
      metroUntil = Math.max(metroUntil, horizon);
    }

    if (S.cur > lastCur && !(S.test && !S.test.judge.auto)) {
      for (const n of S.chart.notes) {
        const s = noteStart(n);
        if (s > lastCur && s <= S.cur) click(n.type === 'flick' ? 1500 : n.type === 'field' ? 500 : n.type === 'hold' ? 800 : 1000);
      }
    }
    lastCur = S.cur;
    if ((audioEl.ended || S.cur > totalMs() + 2000) && audioStarted) stop();
  }

  /* ------------------------------------------------------------ 박자 맞추기 */
  const tapT = { times: [], bpm: 0 };
  /** 재생 중에 박자에 맞춰 B 를 두드리면 BPM 을 잰다 (두드린 시각의 최소제곱 기울기) */
  function tapTempo(e) {
    if (S.test) return;
    if (!S.playing) return toast('재생(Space) 중에 노래 박자에 맞춰 B 를 두드리세요');
    const now = clockAt(e.timeStamp), a = tapT.times;
    if (a.length && now - a[a.length - 1] > 2500) a.length = 0;
    a.push(now);
    tapT.bpm = 0;
    if (a.length >= 4) {
      const n = a.length, mx = (n - 1) / 2, my = a.reduce((s, v) => s + v, 0) / n;
      let num = 0, den = 0;
      a.forEach((v, i) => { num += (i - mx) * (v - my); den += (i - mx) * (i - mx); });
      if (num > 0) tapT.bpm = 60000 / (num / den);
    }
    if (S.tab !== 'song') showTab('song');
    renderTapTempo();
  }
  function renderTapTempo() {
    const el = $('#tapOut');
    if (!el) return;
    const n = tapT.times.length, v = tapT.bpm;
    if (!n) return el.replaceChildren(h('span', { class: 'hint' }, '재생하면서 박자에 맞춰 B 키를 4번 이상 두드리세요. 많이 두드릴수록 정확합니다.'));
    if (!v) return el.replaceChildren(h('span', { class: 'hint' }, `두드린 횟수 ${n} — 계속 두드리세요 (4번부터 계산)`));
    const round = Math.round(v), fine = Math.round(v * 10) / 10;
    el.replaceChildren(
      h('b', {}, `${v.toFixed(1)} BPM`), h('span', { class: 'dim' }, ` (${n}번)`),
      h('div', { class: 'row' },
        h('button', { class: 'primary', onclick: () => setBpmHere(round) }, `${round} 로 적용`),
        fine !== round ? h('button', { onclick: () => setBpmHere(fine) }, `${fine} 로 적용`) : null,
        h('button', { onclick: () => { tapT.times.length = 0; tapT.bpm = 0; renderTapTempo(); } }, '다시 재기')));
  }
  /** 지금 위치가 속한 BPM 구간의 BPM 을 바꾼다 */
  function setBpmHere(v) {
    if (!(v > 0)) return toast('BPM 은 0보다 커야 합니다');
    const i = S.timing.segment(Math.max(0, S.cur)).index;
    mutate(() => { S.chart.timing[i].bpm = Math.round(v * 1000) / 1000; });
    toast(`BPM ${S.chart.timing[i].bpm} — 메트로놈을 켜고 재생해서 박이 맞는지 들어 보세요`, 3000);
  }
  /** 박자선 전체를 옮긴다(meta.offset). 노트는 박자선에 붙어서 같이 움직인다. 화면은 같은 소리 위치에 둔다 */
  function nudgeOffset(d) {
    mutate(() => { S.chart.meta.offset = Math.round((+S.chart.meta.offset || 0) + d); });
    if (!S.playing) S.cur += d;
    invalidate();
  }
  /** 빨간 선 위치의 소리를 마디 첫 박으로 삼는다 (첫 BPM 구간 기준) */
  function setDownbeatHere() {
    if (S.chart.timing.length > 1 && S.cur >= S.chart.timing[1].time) return toast('BPM 이 바뀐 뒤 구간에서는 쓸 수 없습니다. 곡 앞부분(첫 BPM 구간)에서 맞추세요', 3500);
    stop();
    const off = +S.chart.meta.offset || 0, bar = 240000 / S.chart.timing[0].bpm;
    const audioPos = S.cur - off;
    const nu = Math.round(-(((audioPos % bar) + bar) % bar));
    if (nu === off) return toast('이미 이 위치가 마디 첫 박입니다');
    nudgeOffset(nu - off);
    toast(`박자선을 옮겼습니다 (offset ${off} → ${nu}ms). 메트로놈을 켜고 재생해서 확인하세요`, 3500);
  }
  /** 노래를 분석해서 BPM 과 첫 박을 한 번에 맞춘다 (자동 생성과 같은 분석) */
  async function detectTempo() {
    if (!S.audioBuf) return toast('오디오가 아직 준비되지 않았습니다 (곡 정보의 audio 확인)');
    if (S.chart.timing.length > 1) return toast('BPM 변화가 있는 채보는 자동으로 맞출 수 없습니다 (단일 BPM 만 추정)', 3500);
    if (S.chart.notes.length && !confirm(`노트 ${S.chart.notes.length}개가 박자선과 함께 움직입니다. 계속할까요? (Ctrl+Z 로 되돌릴 수 있음)`)) return;
    stop();
    toast('노래 분석 중… (몇 초 걸릴 수 있습니다)', 15000);
    await new Promise((r) => setTimeout(r, 40));
    if (!S.autoFeat) {
      const b = S.audioBuf, chans = [];
      for (let c = 0; c < b.numberOfChannels; c++) chans.push(b.getChannelData(c));
      S.autoFeat = AutoChart.analyze(chans, b.sampleRate);
      autoTempo = AutoChart.estimateTempo(S.autoFeat);
      autoPhase = {};
    }
    const tp = autoTempo, off = -Math.round(tp.firstBeatMs);
    mutate(() => { S.chart.timing = [{ time: 0, bpm: tp.bpm }]; S.chart.meta.offset = off; });
    toast(`추정: BPM ${tp.bpm}, 첫 박 ${Math.round(tp.firstBeatMs)}ms. 메트로놈을 켜고 재생해서 확인하세요. 두 배/절반으로 들리면 ×2 · ÷2`, 6000);
  }

  /* ------------------------------------------------------------ 키보드로 찍기 / 녹음 */
  function setRec(on) {
    S.rec = on;
    $('#btnRec').classList.toggle('rec', on);
    $('#btnRec').textContent = on ? '● 녹음 중' : '● 녹음';
    if (on) toast('녹음 켜짐 — 재생(Space)하면서 A S D F 를 치면 그 박자에 노트가 찍힙니다. 길게 누르면 홀드', 3500);
  }
  /** 편집 중 A S D F: 멈춰 있으면 빨간 선 위치에 탭을 찍고/지우고, 재생 중 + 녹음이면 누른 순간을 스냅해서 찍는다 */
  function laneInput(lane, e) {
    if (S.test) return;
    if (!S.playing) return toggleTap(lane, snapT(Math.max(0, S.cur)));
    if (!S.rec) {
      if (!recHintShown) { recHintShown = true; toast('재생 중에 찍으려면 녹음(R)을 켜세요'); }
      return;
    }
    const raw = clockAt(e.timeStamp) - S.recLat, t = snapT(raw);
    recDown[lane] = null;
    if (raw < 0 || laneConflict(lane, t, t)) return;
    let note;
    mutate(() => { note = addNote({ type: 'tap', time: t, lane }); });
    recDown[lane] = { note, raw };
    click(1000);
  }
  function laneRelease(lane, e) {
    const d = recDown[lane];
    recDown[lane] = null;
    if (!d || !S.playing || !S.chart.notes.includes(d.note)) return;
    const rawUp = clockAt(e.timeStamp) - S.recLat;
    if (rawUp - d.raw < Math.max(220, stepMsAt(d.note.time) * 1.5)) return; // 짧게 누름 = 탭
    const end = snapT(rawUp);
    if (end <= d.note.time || laneConflict(lane, d.note.time, end, new Set([d.note.id]))) return;
    d.note.type = 'hold'; d.note.end = end;
    changed();
  }

  /* ------------------------------------------------------------ 플레이 테스트 */
  const TEST_LEAD_MS = 1500; // 시작 지점 전에 노트가 내려오는 시간
  const testView = new PlayTest.PlayView($('#testView'));
  const testOpts = { hispeed: store.get('testSpeed', 1), sens: store.get('testSens', 1), grace: 150, auto: store.get('testAuto', false) };
  let testFrom = null;

  /** 지금 편집 위치부터 테스트. 화면 오른쪽에 하이웨이, 왼쪽엔 흰 재생선이 따라간다. */
  function startTest(from) {
    if (!S.song) return toast('먼저 곡을 여세요');
    if (S.draft) S.draft = null;
    stop();
    testFrom = from == null ? (S.test ? S.test.from : S.cur) : from;
    const start = testFrom - TEST_LEAD_MS;
    const judge = new PlayTest.PlayJudge(S.chart, S.timing, start, {
      graceMs: testOpts.grace, auto: testOpts.auto,
      onJudge: (rec, g, d, isTick) => {
        testView.onJudge(rec, g, d, isTick, performance.now(), S.test.judge);
        if (!isTick && g !== PlayTest.GRADE.MISS && !judge.auto) click(rec.type === 'flick' ? 1500 : 1000);
      },
    });
    S.test = { from: testFrom, view: start, judge, done: false };
    $('#main').classList.add('testing');
    $('#testWrap').hidden = false;
    S.cur = start;
    play();
    $('#testView').focus();
    invalidate();
  }

  function closeTest() {
    if (!S.test) return;
    stop();
    S.cur = S.test.from;
    S.test = null;
    $('#main').classList.remove('testing');
    $('#testWrap').hidden = true;
    if (document.pointerLockElement) document.exitPointerLock();
    invalidate();
  }

  function finishTest() {
    stop();
    S.test.done = true;
    if (document.pointerLockElement) document.exitPointerLock();
    const j = S.test.judge;
    setStatus(`테스트 결과: ${j.score.toLocaleString()}점 · P ${j.counts[0]} G ${j.counts[1]} M ${j.counts[2]} · 최대 콤보 ${j.maxCombo}/${j.total}`);
  }

  /** 매 프레임: 판정 진행, 왼쪽 화면 따라가기, 오른쪽 하이웨이 그리기 */
  function tickTest() {
    const T = S.test;
    if (!T.done) {
      T.judge.advance(S.cur);
      if (S.cur > T.judge.lastEnd + 1200 || !S.playing) finishTest();
    }
    // 흰 선이 화면 위쪽 30% 까지 올라가면 그 자리에 두고 채보를 내린다
    const topY = L.H * 0.3;
    if (L.H && !T.done && !(T.holdFollow > performance.now()) && yOf(S.cur) < topY) T.view = S.cur - ((L.recY - topY) * 1000) / S.pps;
    testView.draw(T.judge, S.timing, S.cur, { hispeed: testOpts.hispeed, clock: performance.now(), result: T.done });
  }

  /** 테스트 키 처리. 처리했으면 true (나머지 키는 편집 단축키로 넘어간다). */
  function testKey(e, down) {
    const lane = { KeyA: 0, KeyS: 1, KeyD: 2, KeyF: 3 }[e.code];
    if (lane != null) {
      e.preventDefault();
      if (e.repeat || S.test.done || S.test.judge.auto) return true;
      const t = Math.max(S.cur, clockAt(e.timeStamp));
      if (down) S.test.judge.press(lane, t); else S.test.judge.release(lane, t);
      return true;
    }
    if (!down) return false;
    if (e.key === 'Escape') {
      if (S.draft) return false; // 필드 초안 취소가 먼저
      e.preventDefault(); closeTest(); return true;
    }
    if (e.code === 'KeyR' || e.code === 'KeyT') { e.preventDefault(); startTest(S.test.from); return true; }
    if (e.key === ' ') { e.preventDefault(); S.test.done ? startTest(S.test.from) : finishTest(); return true; }
    return false;
  }
  window.addEventListener('keyup', (e) => {
    if (S.test) return testKey(e, false);
    const lane = { KeyA: 0, KeyS: 1, KeyD: 2, KeyF: 3 }[e.code];
    if (lane != null) laneRelease(lane, e);
  });

  const testCanvas = $('#testView');
  function testMouse(e) {
    if (S.test.done || S.test.judge.auto || !e.movementX) return;
    S.test.judge.moveCursor(e.movementX, Math.max(S.cur, clockAt(e.timeStamp)), testOpts.sens);
  }
  // 하이웨이를 클릭하면 마우스를 잡아 둔다 (게임과 같은 상대 이동, 커서 숨김). Esc 로 풀림
  $('#testView').addEventListener('mousedown', () => { if (S.test && !S.test.done) $('#testView').requestPointerLock?.(); });

  function bindTestUI() {
    const num = (sel, key, lo, hi) => {
      $(sel).value = testOpts[key];
      $(sel).onchange = (e) => { testOpts[key] = clamp(parseFloat(e.target.value) || testOpts[key], lo, hi); e.target.value = testOpts[key]; store.set(key === 'hispeed' ? 'testSpeed' : 'testSens', testOpts[key]); e.target.blur(); };
    };
    num('#testSpeed', 'hispeed', 0.5, 4);
    num('#testSens', 'sens', 0.1, 5);
    $('#testAuto').checked = testOpts.auto;
    $('#testAuto').onchange = (e) => { testOpts.auto = e.target.checked; store.set('testAuto', testOpts.auto); e.target.blur(); if (S.test) startTest(S.test.from); };
    $('#testClose').onclick = closeTest;
    $('#btnTest').onclick = (e) => { e.currentTarget.blur(); startTest(); };
  }

  /** 게임 설정(배속/감도/Field 유예)을 읽어 처음 값으로 쓴다. 툴에서 바꾼 값이 있으면 그걸 우선. */
  async function loadGameSettings() {
    const r = await api('/api/game-settings').catch(() => null);
    if (!r || !r.ok || !r.settings) return;
    const g = r.settings;
    if (g.field_grace_ms != null) testOpts.grace = g.field_grace_ms;
    if (store.get('testSpeed', null) == null && g.hispeed) { testOpts.hispeed = Math.round(g.hispeed * 10) / 10; $('#testSpeed').value = testOpts.hispeed; }
    if (store.get('testSens', null) == null && g.sensitivity) { testOpts.sens = g.sensitivity; $('#testSens').value = testOpts.sens; }
  }

  /* ------------------------------------------------------------ 패널 */
  function numField(value, onSet, attrs) {
    return h('input', Object.assign({ type: 'number', value: String(value), onchange: (e) => { const v = parseFloat(e.target.value); if (isFinite(v)) onSet(v); } }, attrs));
  }
  const NOTE_NAME = { tap: '탭', hold: '홀드', flick: '플릭', field: '필드' };

  function renderPanels() {
    renderProps(); renderSong(); renderCheck();
    document.title = (S.dirty ? '* ' : '') + 'RHYTHM 패턴 툴' + (S.song ? ` — ${S.song} [${S.diff}]` : '');
    renderDiffTabs();
  }

  function renderProps() {
    const el = $('#tab-props');
    const list = selNotes();
    el.replaceChildren();
    const fx = S.fxSel != null ? fxById(S.fxSel) : null;
    if (fx && !list.length) return renderFxProps(el, fx);
    if (!list.length) {
      el.append(
        h('h4', {}, '도움말'),
        h('h4', {}, '처음이라면 이 순서로'),
        h('ol', { class: 'steps' },
          h('li', {}, h('b', {}, '박자선 맞추기'), ' — ', h('a', { href: '#', onclick: (e) => { e.preventDefault(); showTab('song'); } }, '곡 · BPM 탭'), '에서 BPM 과 첫 박을 맞춥니다. 메트로놈을 켜고 재생해서 삑 소리가 노래 박과 겹치면 끝.'),
          h('li', {}, h('b', {}, '찍기'), ' — 흰 가로선이 지금 찍힐 위치입니다(마디·박이 옆에 뜸). 탭 도구로 클릭, 위아래로 끌면 홀드. 또는 ↑↓ 로 빨간 선을 옮기고 A S D F.'),
          h('li', {}, h('b', {}, '귀로 찍기'), ' — 녹음(R)을 켜고 재생하면서 A S D F 를 치면 그 박에 찍힙니다. 어려우면 속도를 0.5 로.'),
          h('li', {}, h('b', {}, '확인'), ' — 🎮 테스트(T)로 직접 쳐 봅니다.'),
          h('li', {}, h('b', {}, '연출'), ' — 오른쪽 끝 트랙(발광·글리치·회전·줌)을 클릭하면 그 박에 연출이 걸립니다. 위로 끌면 길이, 우클릭 삭제.')),
        h('h4', {}, '스냅 = 노트가 달라붙는 칸'),
        h('div', { class: 'hint' },
          '스냅 1/4 = 한 박에 한 칸, 1/8 = 반 박, 1/16 = 그 절반. 숫자가 클수록 칸이 촘촘합니다. [ ] 로 바꿉니다.',
          h('br'), '선 색: ', h('span', { class: 'sw', style: 'background:#9aa6d6' }), ' 마디 ', h('span', { class: 'sw', style: 'background:#535d84' }), ' 박 ',
          h('span', { class: 'sw', style: 'background:#3f78c4' }), ' 반 박 ', h('span', { class: 'sw', style: 'background:#8d8440' }), ' 1/16 ', h('span', { class: 'sw', style: 'background:#8a55c2' }), ' 셋잇단',
          h('br'), '보통은 1/8 이나 1/16 으로 두면 됩니다. 어긋난 노트는 Q 로 격자에 붙입니다.'),
        h('h4', {}, '단축키'),
        h('div', { class: 'hint' },
          '1 선택 · 2 탭(끌면 홀드) · 3 홀드 · 4 플릭(Tab: 방향) · 5 필드',
          h('br'), '필드: 클릭으로 키프레임 추가 → Enter 확정, 우클릭/Backspace 취소, Alt+휠 폭',
          h('br'), '휠: 스크롤 · Shift+휠/↑↓: 한 칸씩 · Ctrl+휠: 줌 · PageUp/Down: 한 마디',
          h('br'), 'Space 재생 · R 녹음 · B 탭 템포 · [ ] 스냅 · Q 격자에 맞추기',
          h('br'), 'M 좌우반전 · Shift+↑↓ 선택 노트 시간이동 · 우클릭 삭제',
          h('br'), 'Ctrl+C/V 복사·붙여넣기 · Ctrl+Z/Y · Ctrl+S 저장',
          h('br'), '공중 x 는 5% 단위로 스냅, Alt 를 누르면 1% 단위'));
      return;
    }
    if (list.length > 1) {
      el.append(h('h4', {}, `${list.length}개 선택됨`),
        h('div', { class: 'row' },
          h('button', { onclick: mirrorSelected }, '좌우 반전 (M)'),
          h('button', { onclick: quantizeSelected }, '격자에 맞추기 (Q)'),
          h('button', { onclick: () => shiftSelected(-1) }, '− 한 칸'),
          h('button', { onclick: () => shiftSelected(1) }, '+ 한 칸'),
          h('button', { onclick: deleteSelected }, '삭제')));
      return;
    }
    const n = list[0];
    el.append(h('h4', {}, NOTE_NAME[n.type] || n.type));
    const form = h('div', { class: 'form' });
    const row = (label, ctl) => form.append(h('label', {}, label), ctl);
    const laneSel = () => h('select', { onchange: (e) => mutate(() => { n.lane = +e.target.value; }) },
      K.LANE_KEYS.map((k, i) => h('option', { value: i, selected: n.lane === i }, `${i} (${k})`)));
    const t = (key, v) => numField(Math.round(v), (x) => mutate(() => { n[key] = Math.round(x); }), { step: 1 });
    if (n.type === 'tap') { row('time (ms)', t('time', n.time)); row('lane', laneSel()); }
    if (n.type === 'hold') { row('time (ms)', t('time', n.time)); row('end (ms)', t('end', n.end)); row('lane', laneSel()); }
    if (n.type === 'flick') {
      row('time (ms)', t('time', n.time));
      row('x (0~1)', numField(n.x, (x) => mutate(() => { n.x = clamp(round3(x), 0, 1); }), { step: 0.01, min: 0, max: 1 }));
      row('width (0.1~1)', numField(Core.flickWidth(n), (x) => mutate(() => { n.width = clamp(round3(x), K.FLICK_MIN_WIDTH, 1); }), { step: 0.05, min: K.FLICK_MIN_WIDTH, max: 1 }));
      row('dir', h('select', { onchange: (e) => mutate(() => { n.dir = e.target.value; }) },
        ['left', 'right'].map((d) => h('option', { value: d, selected: n.dir === d }, d))));
    }
    el.append(form);
    if (n.type === 'field') {
      const tbl = h('table', {}, h('tr', {}, h('th', {}, 'time'), h('th', {}, 'center'), h('th', {}, 'width'), h('th', {})));
      n.keys.forEach((k, i) => {
        const upd = (f, v) => mutate(() => { k[f] = f === 'time' ? Math.round(v) : clamp(round3(v), 0, 1); n.keys.sort((a, b) => a.time - b.time); });
        tbl.append(h('tr', {},
          h('td', {}, numField(Math.round(k.time), (v) => upd('time', v), { step: 1 })),
          h('td', {}, numField(k.center, (v) => upd('center', v), { step: 0.01, min: 0, max: 1 })),
          h('td', {}, numField(k.width, (v) => upd('width', v), { step: 0.01, min: 0, max: 1 })),
          h('td', {}, h('button', { disabled: n.keys.length <= 2, onclick: () => mutate(() => n.keys.splice(i, 1)), title: '키 삭제' }, '✕'))));
      });
      el.append(h('h4', {}, '키프레임 (ms / 0~1)'), tbl,
        h('div', { class: 'row' }, h('button', {
          onclick: () => mutate(() => {
            const last = n.keys[n.keys.length - 1];
            n.keys.push({ time: Math.round(last.time + stepMsAt(last.time) * 4), center: last.center, width: last.width });
          }),
        }, '＋ 키 추가')));
    }
    el.append(h('div', { class: 'row' },
      h('button', { onclick: mirrorSelected }, '좌우 반전'), h('button', { onclick: deleteSelected }, '삭제')));
  }

  /** 선택한 연출 효과의 속성 */
  function renderFxProps(el, f) {
    const spec = FX[f.type] || { name: f.type, params: {}, opts: {}, help: '' };
    const form = h('div', { class: 'form' });
    const row = (label, ctl) => form.append(h('label', {}, label), ctl);
    row('종류', h('select', {
      onchange: (e) => mutate(() => { // 종류를 바꾸면 값은 새 종류의 기본값으로
        for (const k of Object.keys(spec.params)) delete f[k];
        f.type = e.target.value; Object.assign(f, FX[f.type].params);
      }),
    }, FX_TYPES.map((ty) => h('option', { value: ty, selected: ty === f.type }, `${FX[ty].name} (${ty})`))));
    row('time (ms)', numField(Math.round(f.time), (v) => mutate(() => { f.time = Math.max(0, Math.round(v)); }), { step: 1, min: 0 }));
    row('길이 (ms)', numField(Math.round(+f.duration || 0), (v) => mutate(() => { f.duration = Math.max(0, Math.round(v)); }), { step: 10, min: 0, title: '0 = 한 번 터지고 끝' }));
    for (const [k, def] of Object.entries(spec.params)) {
      const opts = (spec.opts || {})[k];
      row(k, opts
        ? h('select', { onchange: (e) => mutate(() => { f[k] = e.target.value; }) }, opts.map((o) => h('option', { value: o, selected: f[k] === o }, o)))
        : numField(f[k] == null ? def : f[k], (v) => mutate(() => { f[k] = round3(v); }), { step: 0.1 }));
    }
    el.append(h('h4', {}, `연출 — ${spec.name}`), form,
      h('div', { class: 'hint' }, `${beatLabel(f.time)} · ${spec.help || ''}`),
      h('div', { class: 'row' }, h('button', { onclick: () => deleteFx(f.id) }, '삭제')),
      h('div', { class: 'hint' }, '연출은 채보 파일의 effects 에 저장됩니다. 게임에는 아직 구현되지 않아서 지금은 플레이에 영향이 없습니다. 종류와 값은 임시입니다.'));
  }

  function renderSong() {
    const el = $('#tab-song'), m = S.chart.meta;
    if (el.contains(document.activeElement) && document.activeElement.tagName === 'INPUT') return; // 입력 중 포커스 유지
    el.replaceChildren();
    const set = (k, conv) => (e) => mutate(() => { m[k] = conv ? conv(e.target.value) : e.target.value; });
    const form = h('div', { class: 'form' });
    const row = (label, ctl) => form.append(h('label', {}, label), ctl);
    row('title', h('input', { value: m.title || '', onchange: set('title') }));
    row('artist', h('input', { value: m.artist || '', onchange: set('artist') }));
    const audioOpts = [...new Set([m.audio, ...S.audioFiles].filter(Boolean))];
    row('audio', h('select', {
      onchange: (e) => { mutate(() => { m.audio = e.target.value; }); loadAudio(S.song, m.audio); },
    }, h('option', { value: '' }, '(없음)'), audioOpts.map((f) => h('option', { value: f, selected: f === m.audio }, f))));
    row('offset (ms)', numField(m.offset || 0, (v) => mutate(() => { m.offset = Math.round(v); }), { step: 1 }));
    row('level', numField(m.level || 0, (v) => mutate(() => { m.level = Math.round(v); }), { step: 1, min: 0 }));
    row('difficulty', h('input', { value: S.diff, disabled: true, title: '난이도는 파일(ez/nm/hd.json)로 정해집니다. 위쪽 EZ/NM/HD 버튼으로 바꾸세요' }));
    const song = curSong();
    const others = DIFFS.filter((d) => d !== S.diff && song && song.charts[d]);
    const seg = S.timing.segment(Math.max(0, S.cur)), off = +m.offset || 0;
    el.append(
      h('h4', {}, '박자 맞추기'),
      h('div', { class: 'hint' }, '박자선(가로 격자)이 노래의 박과 맞아야 스냅이 쓸모 있습니다. ① BPM → ② 첫 박 → ③ 메트로놈으로 확인.'),
      h('div', { class: 'row' }, h('button', { class: 'primary', onclick: detectTempo, disabled: !S.song }, '노래에서 자동으로 맞추기')),
      h('div', { class: 'sub' }, '① BPM (빠르기)'),
      h('div', { class: 'row tight' },
        numField(seg.bpm, (v) => setBpmHere(v), { step: 0.01, min: 0.01, title: '지금 위치의 BPM' }),
        h('button', { onclick: () => setBpmHere(seg.bpm / 2), title: '박자선이 두 배로 촘촘할 때' }, '÷2'),
        h('button', { onclick: () => setBpmHere(seg.bpm * 2), title: '박자선이 절반만 있을 때' }, '×2')),
      h('div', { id: 'tapOut', class: 'tapout' }),
      h('div', { class: 'sub' }, '② 첫 박 위치 (박자선을 앞뒤로 옮기기)'),
      h('div', { class: 'hint' }, '왼쪽 파형에서 첫 박(소리가 터지는 곳)을 빨간 선에 맞춘 뒤 누르세요. Ctrl+휠로 확대하면 잘 보입니다.'),
      h('div', { class: 'row' }, h('button', { onclick: setDownbeatHere, disabled: !S.song }, '빨간 선 위치를 마디 첫 박으로')),
      h('div', { class: 'row tight' },
        h('span', { class: 'dim' }, '미세 조정'),
        [-10, -1, 1, 10].map((d) => h('button', { onclick: () => nudgeOffset(d), title: `박자선을 ${Math.abs(d)}ms ${d < 0 ? '앞으로(일찍)' : '뒤로(늦게)'}` }, (d > 0 ? '+' : '') + d)),
        h('span', { class: 'dim' }, `offset ${off}ms`)),
      h('div', { class: 'sub' }, '③ 확인'),
      h('label', { class: 'chk' }, h('input', Object.assign({ type: 'checkbox', onchange: (e) => setMetro(e.target.checked) }, S.metro ? { checked: true } : {})), ' 메트로놈 (재생 중 박마다 삑)'),
      h('div', { class: 'hint' }, '삑 소리가 노래보다 일찍 나면 +, 늦게 나면 − 로 옮기세요. 처음엔 맞다가 점점 어긋나면 BPM 이 틀린 것입니다.'));
    renderTapTempo();
    el.append(h('h4', {}, '곡 정보'), form,
      h('div', { class: 'hint' }, 'title / artist / audio 는 저장할 때 같은 곡의 다른 난이도 파일에도 똑같이 맞춰집니다.'),
      others.length ? h('div', { class: 'row' }, others.map((d) => h('button', { onclick: () => copyNotesFrom(d) }, `${d} 노트 복사해 오기`))) : null,
      h('div', { class: 'hint' }, 'offset: 곡 시간 = 오디오 위치 + 설정 오프셋 + meta.offset. 양수면 같은 오디오 지점에서 게임이 보는 시각이 그만큼 커집니다.'),
      h('div', { class: 'row' }, h('button', { onclick: addAudio, disabled: !S.song }, '오디오 파일 추가…')));

    const tbl = h('table', {}, h('tr', {}, h('th', {}, 'time (ms)'), h('th', {}, 'BPM'), h('th', {})));
    S.chart.timing.forEach((p, i) => {
      tbl.append(h('tr', {},
        h('td', {}, numField(Math.round(p.time), (v) => mutate(() => { p.time = Math.round(v); S.chart.timing.sort((a, b) => a.time - b.time); }), { step: 1, disabled: i === 0 })),
        h('td', {}, numField(p.bpm, (v) => v > 0 ? mutate(() => { p.bpm = v; }) : toast('BPM 은 0보다 커야 합니다'), { step: 0.01, min: 0.01 })),
        h('td', {}, h('button', { disabled: S.chart.timing.length <= 1 || i === 0, onclick: () => mutate(() => S.chart.timing.splice(i, 1)) }, '✕'))));
    });
    el.append(h('h4', {}, 'BPM 변화'), tbl,
      h('div', { class: 'row' }, h('button', {
        onclick: () => {
          const t = Math.round(snapT(S.cur));
          if (S.chart.timing.some((p) => Math.round(p.time) === t)) return toast('그 시각에 이미 BPM 이 있습니다');
          mutate(() => { S.chart.timing.push({ time: t, bpm: S.timing.bpmAt(t) }); S.chart.timing.sort((a, b) => a.time - b.time); });
        },
      }, '＋ 현재 위치에 BPM 추가')),
      h('div', { class: 'hint' }, '노트 시각은 항상 ms 절대값이라 BPM 을 바꿔도 노트는 움직이지 않습니다. BPM 은 그리드와 hold/field tick 간격에만 쓰입니다.'));
  }

  function renderCheck() {
    const el = $('#tab-check');
    const s = S.stats || Core.stats(S.chart);
    const errs = S.issues.filter((i) => i.level === 'error').length;
    $('#issueBadge').textContent = errs ? `(${errs})` : '';
    el.replaceChildren();
    const rows = [
      ['tap', s.tap], ['hold', s.hold], ['flick', s.flick], ['field', s.field], ['연출 효과', s.effects],
      ['총 판정 수', s.judgments], ['  hold tick', s.holdTicks], ['  field tick', s.fieldTicks],
      ['마지막 노트', fmtTime(s.endTime)], ['게임 종료(+1.5s)', fmtTime(s.gameEnd)],
      ['노트/초', s.endTime ? (s.notes / (s.endTime / 1000)).toFixed(2) : '-'],
    ];
    el.append(h('h4', {}, '통계'), h('div', { class: 'stat' }, rows.flatMap(([a, b]) => [h('span', { class: 'dim' }, a), h('b', {}, String(b))])));
    el.append(h('h4', {}, `검증 (${S.issues.length})`));
    if (!S.issues.length) el.append(h('div', { class: 'hint' }, '문제 없음 ✔'));
    const order = { error: 0, warn: 1, info: 2 };
    [...S.issues].sort((a, b) => order[a.level] - order[b.level] || (a.t ?? 0) - (b.t ?? 0)).forEach((i) => {
      el.append(h('div', {
        class: 'issue ' + i.level, title: '클릭하면 해당 위치로 이동',
        onclick: () => { if (i.t != null) setCur(i.t); S.sel = new Set(i.ids); renderPanels(); invalidate(); },
      }, (i.level === 'error' ? '✖ ' : i.level === 'warn' ? '⚠ ' : 'ℹ ') + i.msg));
    });
  }

  document.querySelectorAll('#tabs button').forEach((b) => b.addEventListener('click', () => showTab(b.dataset.tab)));
  function showTab(t) {
    S.tab = t;
    document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('on', b.dataset.tab === t));
    document.querySelectorAll('.tab').forEach((s) => { s.hidden = s.id !== 'tab-' + t; });
  }

  /* ------------------------------------------------------------ 곡 열기/저장 */
  async function refreshSongs(select) {
    const r = await api('/api/songs');
    S.songs = r.songs || [];
    const sel = $('#songSelect');
    sel.replaceChildren(h('option', { value: '' }, S.songs.length ? '곡 선택…' : '(charts 폴더가 비어 있음)'),
      ...S.songs.map((s) => {
        const have = DIFFS.filter((d) => s.charts[d]).join('·');
        return h('option', { value: s.folder }, `${s.title}${s.has_chart ? ` [${have}]` : s.legacy ? ' (chart.json → NM 변환 필요)' : ' (채보 없음)'} — ${s.folder}`);
      }));
    if (select) sel.value = select;
    renderDiffTabs();
  }

  /* 난이도: 곡 폴더 안 ez.json / nm.json / hd.json (게임 ChartLoader.DIFFS 와 같은 순서) */
  const DIFFS = ['EZ', 'NM', 'HD'];
  const curSong = () => S.songs.find((s) => s.folder === S.song);
  const chartUrl = (folder, diff) => `/api/chart?song=${encodeURIComponent(folder)}&diff=${diff}`;

  /** want 난이도에 채보가 없으면 가장 가까운 난이도 (게임 ChartLoader.nearest_diff 와 같은 규칙). */
  function pickDiff(song, want) {
    const i = Math.max(0, DIFFS.indexOf(want));
    for (let dist = 0; dist < DIFFS.length; dist++) {
      for (const j of [i - dist, i + dist]) if (song && j >= 0 && j < DIFFS.length && song.charts[DIFFS[j]]) return DIFFS[j];
    }
    return DIFFS.includes(want) ? want : 'NM';
  }

  function renderDiffTabs() {
    const song = curSong();
    $('#diffTabs').replaceChildren(...DIFFS.map((d) => {
      const c = song && song.charts[d];
      return h('button', {
        class: (d === S.diff ? 'on' : '') + (c ? '' : ' missing'),
        disabled: !S.song,
        title: c ? `${d} — 레벨 ${c.level}, 노트 ${c.notes}개` : `${d} 채보 없음 — 열어서 만들고 저장하면 ${d.toLowerCase()}.json 이 생깁니다`,
        onclick: (e) => { e.currentTarget.blur(); if (d !== S.diff) openSong(S.song, d); },
      }, c ? `${d} ${c.level}` : `${d} ＋`);
    }));
  }

  async function openSong(folder, diff) {
    if (!folder) return;
    diff = diff || pickDiff(S.songs.find((s) => s.folder === folder), S.diff);
    if (S.dirty && !confirm('저장하지 않은 변경 사항이 있습니다. 버리고 열까요?')) { $('#songSelect').value = S.song || ''; return; }
    closeTest();
    stop();
    const r = await api(chartUrl(folder, diff));
    if (!r.ok) { toast(r.error || '열기 실패', 4000); $('#songSelect').value = S.song || ''; return; }
    S.song = folder; S.diff = diff; S.audioFiles = r.audio_files || [];
    S.chart = r.chart ? Core.fromJSON(r.chart) : Core.defaultChart();
    if (!r.chart) await seedFromSibling(folder, diff);
    S.undo = []; S.redo = []; S.sel.clear(); S.fxSel = null; S.draft = null; S.cur = 0;
    changed(); S.dirty = !!r.legacy; renderPanels();
    store.set('lastSong', folder); store.set('lastDiff', diff);
    loadAudio(folder, S.chart.meta.audio); // 디코딩은 백그라운드로 (파형이 준비되면 다시 그려짐)
    if (r.legacy) toast('예전 chart.json 을 NM 으로 불러왔습니다. 저장하면 nm.json 으로 저장됩니다', 5000);
    setStatus(`열림: ${folder} [${diff}] — 노트 ${S.chart.notes.length}개${r.chart ? '' : ' (새 난이도)'}`);
  }

  /** 새 난이도: 같은 곡의 다른 난이도에서 곡 정보·offset·BPM 을 가져온다 (노트는 비움). 없으면 폴더 기본값. */
  async function seedFromSibling(folder, diff) {
    const song = S.songs.find((s) => s.folder === folder);
    const src = song && DIFFS.find((d) => d !== diff && song.charts[d] && !song.charts[d].broken);
    const r = src ? await api(chartUrl(folder, src)) : null;
    if (r && r.ok && r.chart) {
      const o = Core.fromJSON(r.chart);
      Object.assign(S.chart.meta, o.meta, { level: 1 });
      S.chart.timing = o.timing;
    } else {
      S.chart.meta.title = folder; S.chart.meta.audio = S.audioFiles[0] || '';
    }
    S.chart.meta.difficulty = diff;
  }

  /** 다른 난이도의 노트를 통째로 가져온다 (되돌리기 가능). 쉬운/어려운 버전을 만들 때 출발점. */
  async function copyNotesFrom(src) {
    if (S.chart.notes.length && !confirm(`지금 ${S.diff} 노트 ${S.chart.notes.length}개를 ${src} 노트로 바꿀까요? (Ctrl+Z 로 되돌릴 수 있음)`)) return;
    const r = await api(chartUrl(S.song, src));
    if (!r.ok || !r.chart) return toast(r.error || `${src} 채보를 읽지 못했습니다`, 4000);
    const notes = Core.fromJSON(r.chart).notes;
    mutate(() => { S.chart.notes = notes; });
    S.sel.clear();
    toast(`${src} 노트 ${notes.length}개를 가져왔습니다 — 저장해야 ${S.diff.toLowerCase()}.json 에 반영됩니다`, 3500);
  }

  async function save() {
    if (!S.song) return toast('먼저 곡을 선택하거나 새 곡을 만드세요');
    const errs = S.issues.filter((i) => i.level === 'error');
    if (errs.length) { showTab('check'); return toast(`오류 ${errs.length}개를 먼저 고쳐야 저장됩니다`, 3500); }
    S.chart.meta.difficulty = S.diff;
    const obj = Core.toJSON(S.chart);
    const r = await post(chartUrl(S.song, S.diff), JSON.stringify(obj));
    if (!r.ok) { toast(r.error || '저장 실패', 5000); return; }
    S.dirty = false;
    const warns = S.issues.filter((i) => i.level === 'warn').length;
    const synced = (r.synced || []).length ? ` · 곡 정보를 ${r.synced.join('/')} 에도 반영` : '';
    toast(`${S.diff} 저장 완료 — 노트 ${r.saved}개 (로더 검증 통과)${warns ? ` · 경고 ${warns}개` : ''}${synced}`, 3000);
    await refreshSongs(S.song);
    renderPanels();
  }

  function addAudio() {
    if (!S.song) return;
    // DOM 에 붙어 있어야 선택창이 열려 있는 동안 change 이벤트가 유실되지 않는다
    const inp = h('input', { type: 'file', accept: '.wav,.ogg,.mp3,audio/*', style: 'display:none' });
    document.body.append(inp);
    inp.onchange = async () => {
      const f = inp.files[0];
      inp.remove();
      if (!f) return;
      try {
        toast('업로드 중…', 8000);
        const r = await post(`/api/audio?song=${encodeURIComponent(S.song)}&name=${encodeURIComponent(f.name)}`, f);
        if (!r.ok) return toast(r.error || '업로드 실패', 4000);
        if (!S.audioFiles.includes(r.name)) S.audioFiles.push(r.name);
        mutate(() => { S.chart.meta.audio = r.name; });
        renderSong();
        loadAudio(S.song, r.name);
        toast('추가됨 — 저장하세요. Godot 에디터에서 프로젝트를 한 번 열어 import 해야 합니다', 5000);
      } catch (err) {
        toast('업로드 실패: ' + err, 5000);
      }
    };
    inp.addEventListener('cancel', () => inp.remove());
    inp.click();
  }

  /* ------------------------------------------------------------ 자동 생성 */
  let autoTempo = null, autoPhase = {}; // autoPhase[bpm] = 그 BPM 일 때 첫 박 추정
  async function openAuto() {
    if (!S.song) return toast('먼저 곡을 여세요');
    if (!S.audioBuf) return toast('오디오가 아직 준비되지 않았습니다 (meta.audio 확인)');
    closeTest(); stop();
    $('#autoDiff').textContent = `— ${S.diff}`;
    $('#autoGo').disabled = true;
    $('#dlgAuto').showModal();
    if (!S.autoFeat) {
      $('#autoTempo').textContent = '분석 중… (곡 길이에 따라 몇 초)';
      await new Promise((r) => setTimeout(r, 30)); // 대화상자를 먼저 그린다
      const b = S.audioBuf, chans = [];
      for (let c = 0; c < b.numberOfChannels; c++) chans.push(b.getChannelData(c));
      S.autoFeat = AutoChart.analyze(chans, b.sampleRate);
      autoTempo = AutoChart.estimateTempo(S.autoFeat);
      autoPhase = {};
    }
    const tp = autoTempo, cur = S.chart.timing, curBpm = cur[0].bpm;
    const ratio = tp.bpm / curBpm;
    const octave = Math.abs(ratio - 0.5) < 0.02 || Math.abs(ratio - 2) < 0.04;
    $('#autoTempo').textContent = `추정 BPM ${tp.bpm} (현재 ${cur.map((p) => p.bpm).join('→')}${octave ? ' — 현재 BPM 의 절반/두 배로 읽혔습니다. 현재 값 유지 권장' : ''})`;
    $('#autoBpmV').textContent = `${curBpm} → ${tp.bpm}`;
    // 아직 기본값(120)이면 추정 BPM 을 쓰고, 직접 넣은 BPM 이 있으면 그대로 둔다
    const sameBpm = cur.length === 1 && Math.abs(curBpm - tp.bpm) < 0.01;
    $('#autoApplyBpm').checked = cur.length === 1 && curBpm === 120 && !sameBpm;
    $('#autoApplyBpm').disabled = sameBpm;
    $('#autoApplyBpm').onchange = refreshAutoOffset;
    $('#autoAlign').checked = !S.chart.notes.length; // 이미 찍은 노트가 있으면 offset 을 함부로 안 바꾼다
    refreshAutoOffset();
    $('#autoGo').disabled = false;
  }

  /** 지금 선택(BPM 유지/추정)에 맞는 첫 박 → offset 제안 */
  function autoChosen() {
    const bpm = $('#autoApplyBpm').checked && !$('#autoApplyBpm').disabled ? autoTempo.bpm : S.chart.timing[0].bpm;
    if (!autoPhase[bpm]) autoPhase[bpm] = bpm === autoTempo.bpm ? autoTempo : AutoChart.estimateTempo(S.autoFeat, bpm);
    return { bpm, offset: -Math.round(autoPhase[bpm].firstBeatMs) };
  }
  function refreshAutoOffset() {
    const { offset } = autoChosen();
    $('#autoOffV').textContent = `${offset}ms (현재 ${+S.chart.meta.offset || 0})`;
    $('#autoAlign').disabled = S.chart.timing.length > 1 || offset === (+S.chart.meta.offset || 0);
  }

  function runAuto() {
    const applyBpm = $('#autoApplyBpm').checked && !$('#autoApplyBpm').disabled;
    const align = $('#autoAlign').checked && !$('#autoAlign').disabled;
    const chosen = autoChosen();
    const here = document.querySelector('input[name=autoRange]:checked').value === 'here';
    const seed = (Date.now() & 0x7fffffff) || 1;
    mutate(() => {
      if (applyBpm) S.chart.timing = [{ time: 0, bpm: chosen.bpm }];
      if (align) S.chart.meta.offset = chosen.offset;
      const timing = new Timing(S.chart.timing);
      const from = here ? Math.max(0, snapT(S.cur)) : 0;
      const r = AutoChart.generate(S.autoFeat, timing, +S.chart.meta.offset || 0, {
        diff: S.diff, from, air: $('#autoAir').checked, density: $('#autoDensity').value / 100, seed,
      });
      S.chart.notes = S.chart.notes.filter((n) => here && noteStart(n) < from);
      for (const n of r.notes) addNote(n);
      if ($('#autoLevel').checked) S.chart.meta.level = r.level;
      S.sel.clear();
      toast(`${S.diff} 초안 ${r.notes.length}개 생성 (초당 ${r.nps.toFixed(1)}개${$('#autoLevel').checked ? `, 레벨 ${r.level}` : ''}) — 저장해야 파일에 반영됩니다`, 4500);
    });
    renderPanels();
  }
  $('#btnAuto').onclick = (e) => { e.currentTarget.blur(); openAuto(); };
  $('#autoCancel').onclick = () => $('#dlgAuto').close();
  $('#autoDensity').oninput = (e) => { $('#autoDensityV').textContent = e.target.value + '%'; };
  $('#formAuto').addEventListener('submit', (e) => { e.preventDefault(); $('#dlgAuto').close(); runAuto(); });

  /* 새 곡 대화상자 */
  $('#btnNew').onclick = () => $('#dlgNew').showModal();
  $('#newCancel').onclick = () => $('#dlgNew').close();
  $('#formNew').addEventListener('submit', async (e) => {
    e.preventDefault();
    const folder = $('#newFolder').value.trim();
    if (!/^[A-Za-z0-9가-힣._\- ]{1,64}$/.test(folder)) return toast('폴더 이름에 쓸 수 없는 문자가 있습니다');
    if (S.songs.some((s) => s.folder === folder)) return toast('이미 있는 폴더입니다');
    const file = $('#newAudio').files[0];
    let audioName = '';
    if (file) {
      const r = await post(`/api/audio?song=${encodeURIComponent(folder)}&name=${encodeURIComponent(file.name)}`, file);
      if (!r.ok) return toast(r.error || '오디오 업로드 실패', 4000);
      audioName = r.name;
    }
    const c = Core.defaultChart();
    Object.assign(c.meta, { title: $('#newTitle').value || folder, artist: $('#newArtist').value, audio: audioName });
    c.timing = [{ time: 0, bpm: parseFloat($('#newBpm').value) || 120 }];
    const r = await post(chartUrl(folder, 'NM'), JSON.stringify(Core.toJSON(c)));
    if (!r.ok) return toast(r.error || '생성 실패', 4000);
    $('#dlgNew').close();
    S.dirty = false;
    await refreshSongs(folder);
    await openSong(folder, 'NM');
  });

  /* ------------------------------------------------------------ 초기화 */
  function bindUI() {
    $('#snapSelect').replaceChildren(...SNAPS.map((n) => h('option', { value: n }, SNAP_NAMES[n])));
    if (!SNAPS.includes(S.snap)) S.snap = 16;
    $('#chkMetro').checked = S.metro;
    $('#chkMetro').onchange = (e) => { setMetro(e.target.checked); e.target.blur(); };
    $('#btnRec').onclick = (e) => { e.currentTarget.blur(); setRec(!S.rec); };
    $('#snapSelect').value = S.snap;
    $('#snapSelect').onchange = (e) => { S.snap = +e.target.value; store.set('snap', S.snap); invalidate(); e.target.blur(); };
    $('#songSelect').onchange = (e) => { openSong(e.target.value); e.target.blur(); };
    $('#btnSave').onclick = save;
    $('#btnUndo').onclick = undo; $('#btnRedo').onclick = redo;
    $('#btnPlay').onclick = () => (S.playing ? stop() : play());
    $('#btnFlickDir').onclick = () => setFlickDir(S.flickDir === 'left' ? 'right' : 'left');
    $('#defWidth').value = S.defWidth.toFixed(2);
    $('#defWidth').onchange = (e) => { S.defWidth = clamp(parseFloat(e.target.value) || 0.3, 0.02, 1); store.set('defWidth', S.defWidth); };
    $('#chkClap').checked = S.clap;
    $('#chkClap').onchange = (e) => { S.clap = e.target.checked; store.set('clap', S.clap); };
    $('#rateSelect').onchange = (e) => { S.rate = parseFloat(e.target.value); if (S.playing) seekPlaying(); e.target.blur(); };
    $('#zoom').value = clamp(S.pps, 80, 900);
    $('#zoom').oninput = (e) => { S.pps = +e.target.value; store.set('pps', S.pps); invalidate(); };
    document.querySelectorAll('#tools button').forEach((b) => b.addEventListener('click', () => setTool(b.dataset.tool)));
    setFlickDir(S.flickDir);
    setTool('select');
    window.addEventListener('beforeunload', (e) => { if (S.dirty) { e.preventDefault(); e.returnValue = ''; } });
    new ResizeObserver(invalidate).observe(canvas);
  }

  function updateClock() {
    $('#clock').textContent = `${beatLabel(S.cur)} · ${fmtTime(S.cur)} · ${S.timing.bpmAt(S.cur)}BPM`;
  }
  function setMetro(on) {
    S.metro = on; store.set('metro', on);
    $('#chkMetro').checked = on;
    document.querySelectorAll('#tab-song input[type=checkbox]').forEach((c) => { c.checked = on; });
  }

  function loop() {
    if (S.playing) { tickPlayback(); needsDraw = true; }
    if (needsDraw || S.test) { needsDraw = false; draw(); updateClock(); }
    if (S.test) tickTest();
    requestAnimationFrame(loop);
  }

  async function init() {
    S.timing = new Timing(S.chart.timing);
    S.stats = Core.stats(S.chart);
    bindUI();
    bindTestUI();
    showTab('props');
    renderPanels();
    requestAnimationFrame(loop);
    setInterval(() => { post('/api/ping', '{}').catch(() => {}); }, 2000);
    post('/api/ping', '{}').catch(() => {});

    const st = await api('/api/state');
    $('#rootInfo').textContent = st.root ? `게임: ${st.root}` : '게임 폴더 미지정';
    $('#rootInfo').style.cursor = 'pointer';
    $('#rootInfo').title = '클릭: 게임 프로젝트 폴더 변경';
    $('#rootInfo').onclick = chooseRoot;
    if (!st.root) {
      $('#rootBrowse').onclick = async () => { await chooseRoot(); if ($('#dlgRoot').open) $('#dlgRoot').close(); };
      $('#dlgRoot').showModal();
      return;
    }
    loadGameSettings();
    await refreshSongs();
    const last = store.get('lastSong', '');
    const first = S.songs.find((s) => s.folder === last) || S.songs.find((s) => s.has_chart || s.legacy);
    if (first) { $('#songSelect').value = first.folder; await openSong(first.folder); }
    const qp = new URLSearchParams(location.search); // 디버그용: ?cur=12000&tab=check
    if (qp.has('cur')) setCur(+qp.get('cur'));
    if (qp.has('tab')) showTab(qp.get('tab'));
  }

  async function chooseRoot() {
    const r = await post('/api/browse-root', '{}');
    if (r.ok) { location.reload(); } else if (!r.cancelled) toast(r.error || '실패', 4000);
  }

  // 자동 테스트/디버그용 훅
  window.PT = {
    S, L, Core, startTest, closeTest, openAuto, runAuto, addAudio, hit, mutate, changed, canvas, yOf, xAir, laneCx, setTool, save, undo, redo, commitDraft, mirrorSelected, deleteSelected,
    fxHit, fxSubW, quantizeSelected, setBpmHere, nudgeOffset, setDownbeatHere, detectTempo, setRec, setMetro, beatLabel, snapT,
    validate: () => Core.validate(S.chart, { durationMs: S.audioDur }),
  };
  const selftest = new URLSearchParams(location.search).get('selftest'); // --dev 서버에서만 파일이 제공됨
  if (selftest) document.head.append(h('script', { src: withToken('/dev/' + (selftest === '1' ? 'ui_selftest' : selftest) + '.js') }));
  init();
})();
