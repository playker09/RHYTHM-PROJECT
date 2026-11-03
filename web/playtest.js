/* 실시간 플레이 테스트: 게임 판정(judge.gd + field_controller.gd + judge_logic.gd)과 3D 하이웨이 구도를 옮긴 것.
 * PlayJudge = 판정(순수 로직, DOM 없음), PlayView = 캔버스 그리기. 시간 단위는 ms.
 * 기준 상수: core/game_const.gd, 카메라: scenes/game.gd (pos 0,3.7,7.4 → 0,0.4,-6, fov 46). */
(function (root) {
  'use strict';
  const { K, noteStart, noteEnd, fieldAt, clamp } = root.Core;

  const GRADE = { PERFECT: 0, GREAT: 1, MISS: 2, SKIP: -1 };
  const GRADE_NAME = ['PERFECT', 'GREAT', 'MISS'];
  const GREAT_WEIGHT = 0.7;
  const PIXELS_FULL_SWEEP = 1000;     // FieldController: 감도 1.0에서 커서 0→1 에 필요한 마우스 이동 픽셀
  const VELOCITY_WINDOW_MS = 60;
  const FALLBACK_DT_MS = 16;
  const GEO = {
    LANE_W: 1.1, SCROLL: 16, VIEW_DEPTH: 34, AIR_Y: 1.5, AIR_Z: 1.0, FIELD_W: 4.4,
    CAM: [0, 3.7, 7.4], AT: [0, 0.4, -6], FOV: 46,
  };

  /* ---------------- 판정 규칙 (judge_logic.gd) ---------------- */
  function gradeFromDelta(d) {
    const a = Math.abs(d);
    return a <= K.PERFECT_MS ? GRADE.PERFECT : a <= K.GREAT_MS ? GRADE.GREAT : GRADE.MISS;
  }
  function flickGrade(d) {
    const a = Math.abs(d);
    return a <= K.PERFECT_MS ? GRADE.PERFECT : a <= K.FLICK_WINDOW_MS ? GRADE.GREAT : GRADE.MISS;
  }
  const fieldInside = (x, a) => Math.abs(x - a.center) <= a.width * 0.5;
  function flickCrossed(prev, next, nx, dir) {
    const m = K.FLICK_X_MARGIN;
    if (dir === 'left') return next < prev && prev > nx - m && next <= nx + m;
    return next > prev && prev < nx + m && next >= nx - m;
  }
  const flickSpeedOk = (v, dir) => (dir === 'left' ? -v : v) >= K.FLICK_MIN_SPEED;

  /* ---------------- 판정기 (judge.gd + field_controller.gd) ----------------
   * fromMs 이후에 시작하는 노트만 판정한다 (테스트 시작 지점 이전 노트는 무시).
   * onJudge(rec, grade, deltaMs, isTick) 로 결과를 알린다. */
  class PlayJudge {
    constructor(chart, timing, fromMs, opts) {
      opts = opts || {};
      this.graceMs = opts.graceMs == null ? 150 : opts.graceMs;
      this.auto = !!opts.auto;
      this.onJudge = opts.onJudge || (() => {});
      this.queues = [[], [], [], []];
      this.ptrs = [0, 0, 0, 0];
      this.pressed = [false, false, false, false];
      this.ticks = []; this.tickPtr = 0;
      this.flicks = []; this.flickPtr = 0;
      this.fields = []; this.fieldFirst = 0;
      this.notes = [];
      this.total = 0;
      for (const n of chart.notes) {
        if (n.type === 'field' && !(Array.isArray(n.keys) && n.keys.length >= 2)) continue;
        if (noteStart(n) < fromMs) continue;
        const rec = { n, type: n.type, time: noteStart(n), end: noteEnd(n), judged: false, headHit: false, missed: false };
        this.notes.push(rec);
        if (n.type === 'tap' || n.type === 'hold') {
          this.queues[n.lane].push(rec);
          this.total += 1;
          if (n.type === 'hold') {
            for (const t of timing.tickTimes(rec.time, rec.end, K.TICK_BEAT_FRACTION)) { this.ticks.push({ time: t, lane: n.lane, rec }); this.total += 1; }
          }
        } else if (n.type === 'flick') {
          this.flicks.push(rec); this.total += 1;
        } else if (n.type === 'field') {
          this.fields.push(rec);
          for (const t of timing.tickTimes(rec.time, rec.end, K.TICK_BEAT_FRACTION)) { this.ticks.push({ time: t, lane: -1, rec }); this.total += 1; }
        }
      }
      for (const q of this.queues) q.sort((a, b) => a.time - b.time);
      this.ticks.sort((a, b) => a.time - b.time);
      this.flicks.sort((a, b) => a.time - b.time);
      this.fields.sort((a, b) => a.time - b.time);
      this.lastEnd = this.notes.reduce((m, r) => Math.max(m, r.end), fromMs);
      // 커서
      this.cursor = 0.5; this.prevCursor = 0.5; this.samples = []; this.outsideSince = -1; this.outside = false;
      // 점수
      this.fromMs = fromMs; this.lastT = -Infinity; this.lastTickT = -Infinity;
      this.counts = [0, 0, 0]; this.skipped = 0; this.combo = 0; this.maxCombo = 0; this.weight = 0; this.fast = 0; this.slow = 0;
    }

    /** 채보가 바뀌었을 때(테스트 중 편집): 지금까지의 점수/콤보/입력 상태는 그대로 두고 새 채보로 판정기를 다시 만든다.
     *  이미 지나간 노트는 그대로 두고(같은 노트 객체면 판정 상태 유지), 아직 안 온 노트만 새 채보를 따른다. */
    rebuild(chart, timing) {
      const nj = new PlayJudge(chart, timing, this.fromMs, { graceMs: this.graceMs, auto: this.auto, onJudge: this.onJudge });
      const old = new Map(this.notes.map((r) => [r.n, r]));
      const t = this.lastT;
      for (const r of nj.notes) {
        const o = old.get(r.n);
        if (o && o.type === r.type && o.time === r.time) { r.judged = o.judged; r.headHit = o.headHit; r.missed = o.missed; }
        else if (r.time < t - (r.type === 'flick' ? K.FLICK_WINDOW_MS : K.GREAT_MS)) r.judged = true; // 이미 지나간 시각에 새로 놓은 노트는 판정 안 함
      }
      for (let l = 0; l < K.LANE_COUNT; l++) { const q = nj.queues[l]; let p = 0; while (p < q.length && q[p].judged) p++; nj.ptrs[l] = p; }
      while (nj.flickPtr < nj.flicks.length && nj.flicks[nj.flickPtr].judged) nj.flickPtr++;
      while (nj.tickPtr < nj.ticks.length && nj.ticks[nj.tickPtr].time <= this.lastTickT) nj.tickPtr++;
      for (const k of ['pressed', 'cursor', 'prevCursor', 'samples', 'outsideSince', 'outside', 'counts', 'combo', 'maxCombo', 'weight', 'fast', 'slow', 'skipped', 'lastT', 'lastTickT']) nj[k] = this[k];
      // 총 판정 수 = 이미 나온 판정(+유예로 건너뛴 tick) + 앞으로 남은 판정. 지나간 시각에 새로 놓은 노트는 빠진다
      const heads = nj.notes.filter((r) => r.type !== 'field' && !r.judged).length;
      nj.total = this.judgedCount + this.skipped + heads + (nj.ticks.length - nj.tickPtr);
      return nj;
    }

    get score() { return this.total ? Math.round((this.weight / this.total) * 1000000) : 0; }
    get judgedCount() { return this.counts[0] + this.counts[1] + this.counts[2]; }

    _emit(rec, grade, delta, isTick) {
      this.counts[grade] += 1;
      if (grade === GRADE.MISS) this.combo = 0;
      else {
        this.combo += 1; this.maxCombo = Math.max(this.maxCombo, this.combo);
        this.weight += grade === GRADE.PERFECT ? 1 : GREAT_WEIGHT;
        if (grade === GRADE.GREAT && !isTick) { if (delta < 0) this.fast += 1; else this.slow += 1; }
      }
      if (grade === GRADE.MISS && !isTick) rec.missed = true;
      this.onJudge(rec, grade, delta, isTick);
    }

    /* 시간 경과: 오토 → 커서 영역 갱신 → 지나간 tick → flick/노트 MISS */
    advance(t) {
      this.lastT = Math.max(this.lastT, t);
      if (this.auto) this._autoplay(t);
      this._refreshField(t);
      this._advanceTicks(t);
      while (this.flickPtr < this.flicks.length) {
        const r = this.flicks[this.flickPtr];
        if (r.judged) this.flickPtr++;
        else if (t - r.time > K.FLICK_WINDOW_MS) { r.judged = true; this.flickPtr++; this._emit(r, GRADE.MISS, 0, false); }
        else break;
      }
      for (let l = 0; l < K.LANE_COUNT; l++) this._expire(l, t);
    }

    press(lane, t) {
      this._advanceTicks(t);
      this.pressed[lane] = true;
      this._expire(lane, t);
      const q = this.queues[lane], p = this.ptrs[lane];
      if (p >= q.length) return;
      const r = q[p], delta = t - r.time, g = gradeFromDelta(delta);
      if (g === GRADE.MISS) return; // 너무 이른 입력은 무시
      r.judged = true; r.headHit = true; this.ptrs[lane] = p + 1;
      this._emit(r, g, delta, false);
    }

    release(lane, t) {
      this._advanceTicks(t);
      this.pressed[lane] = false;
    }

    /** 마우스 이동량(px) → 커서. 감도는 게임 설정과 같은 의미. */
    moveCursor(dxPx, t, sensitivity) {
      this.setCursor(this.cursor + (dxPx / PIXELS_FULL_SWEEP) * (sensitivity || 1), t);
    }

    setCursor(x, t) {
      this._advanceTicks(t); // 움직이기 직전까지의 tick 은 이전 위치로 판정
      const prev = this.cursor;
      this.prevCursor = prev;
      this.cursor = clamp(x, 0, 1);
      this.samples.push([t, this.cursor]);
      while (this.samples.length > 1 && t - this.samples[0][0] > VELOCITY_WINDOW_MS) this.samples.shift();
      this._refreshField(t);
      if (prev !== this.cursor) this._checkFlicks(prev, this.cursor, this._velocity(), t);
    }

    _velocity() {
      if (this.samples.length >= 2) {
        const a = this.samples[0], b = this.samples[this.samples.length - 1], dt = b[0] - a[0];
        if (dt > 0) return ((b[1] - a[1]) / dt) * 1000;
      }
      return ((this.cursor - this.prevCursor) / FALLBACK_DT_MS) * 1000;
    }

    _checkFlicks(prev, next, v, t) {
      for (let i = this.flickPtr; i < this.flicks.length; i++) {
        const r = this.flicks[i];
        if (r.time - t > K.FLICK_WINDOW_MS) break;
        if (r.judged || !flickCrossed(prev, next, r.n.x, r.n.dir) || !flickSpeedOk(v, r.n.dir)) continue;
        const delta = t - r.time, g = flickGrade(delta);
        if (g === GRADE.MISS) continue;
        r.judged = true; r.headHit = true;
        this._emit(r, g, delta, false);
      }
    }

    _expire(lane, t) {
      const q = this.queues[lane];
      let p = this.ptrs[lane];
      while (p < q.length && t - q[p].time > K.GREAT_MS) {
        q[p].judged = true; p++;
        this._emit(q[p - 1], GRADE.MISS, 0, false);
      }
      this.ptrs[lane] = p;
    }

    activeField(t) {
      while (this.fieldFirst < this.fields.length && this.fields[this.fieldFirst].end < t) this.fieldFirst++;
      const r = this.fields[this.fieldFirst];
      return r && r.time <= t ? r : null;
    }

    _refreshField(t) {
      const r = this.activeField(t);
      if (!r) { this.outsideSince = -1; this.outside = false; return; }
      const inside = fieldInside(this.cursor, fieldAt(r.n, t));
      this.outside = !inside;
      if (inside) this.outsideSince = -1;
      else if (this.outsideSince < 0) this.outsideSince = t;
    }

    _advanceTicks(t) {
      this.lastTickT = Math.max(this.lastTickT, t);
      while (this.tickPtr < this.ticks.length && this.ticks[this.tickPtr].time <= t) {
        const e = this.ticks[this.tickPtr++];
        let g;
        if (this.auto) g = GRADE.PERFECT; // 오토 = 완벽한 플레이 (커서 표시는 근사치라 판정에 쓰지 않음)
        else if (e.lane < 0) {
          const inside = fieldInside(this.cursor, fieldAt(e.rec.n, e.time));
          const outFor = this.outsideSince >= 0 ? Math.max(e.time - this.outsideSince, 0) : 0;
          g = inside ? GRADE.PERFECT : outFor <= this.graceMs ? GRADE.SKIP : GRADE.MISS;
          if (g === GRADE.SKIP) { this.skipped++; continue; } // 이탈 유예: 판정 없음
        } else g = this.pressed[e.lane] ? GRADE.PERFECT : GRADE.MISS;
        this._emit(e.rec, g, 0, true);
      }
    }

    /* 오토플레이: 머리/플릭은 정시에 PERFECT, 홀드는 끝까지 누르고, 커서는 Field 중심/플릭 궤적을 따라간다. */
    _autoplay(t) {
      for (let l = 0; l < K.LANE_COUNT; l++) {
        const q = this.queues[l];
        while (this.ptrs[l] < q.length && q[this.ptrs[l]].time <= t) this.press(l, q[this.ptrs[l]].time);
        const holding = q.some((r) => r.type === 'hold' && r.headHit && t < r.end);
        if (this.pressed[l] && !holding) this.release(l, t);
        else if (holding) this.pressed[l] = true;
      }
      for (let i = this.flickPtr; i < this.flicks.length; i++) {
        const r = this.flicks[i];
        if (r.time > t) break;
        if (!r.judged) { r.judged = true; r.headHit = true; this._emit(r, GRADE.PERFECT, 0, false); }
      }
      this._advanceTicks(t - 0.001); // 커서 옮기기 전 tick 정산
      const x = this.autoCursorAt(t);
      this.prevCursor = this.cursor; this.cursor = x;
    }

    /** 오토 커서 위치: 플릭 ±90ms 안이면 그 방향으로 휙, 아니면 활성/다음 Field 중심. */
    autoCursorAt(t) {
      for (const r of this.flicks) {
        if (Math.abs(t - r.time) <= 90) return clamp(r.n.x + (r.n.dir === 'left' ? -1 : 1) * ((t - r.time) / 90) * 0.12, 0, 1);
      }
      const f = this.activeField(t);
      if (f) return fieldAt(f.n, t).center;
      const next = this.fields[this.fieldFirst];
      if (next && next.time - t < 600) {
        const u = clamp(1 - (next.time - t) / 600, 0, 1);
        return this.cursor + (next.n.keys[0].center - this.cursor) * u * 0.25;
      }
      return this.cursor;
    }
  }

  /* ---------------- 3D 투영 (game.gd 카메라와 같은 구도) ---------------- */
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const norm = (a) => { const l = Math.hypot(a[0], a[1], a[2]); return [a[0] / l, a[1] / l, a[2] / l]; };
  const FWD = norm(sub(GEO.AT, GEO.CAM));
  const RIGHT = norm(cross(FWD, [0, 1, 0]));
  const UP = cross(RIGHT, FWD);

  const C = {
    ink: '#08070f', ink2: '#120f1f', violet: '#8f7bff', magenta: '#ff4f9e',
    tap: 'rgb(128,235,255)', hold: 'rgb(255,158,56)', held: 'rgb(255,242,184)', missed: 'rgb(82,82,102)',
    flickL: 'rgb(255,224,51)', flickR: 'rgb(77,255,115)',
    field: [77, 184, 255], fieldOut: [255, 51, 61], cursor: 'rgb(191,247,255)', cursorOut: 'rgb(255,77,82)',
    grade: ['#ffe08a', '#62f2e6', '#ff5a66'],
  };

  class PlayView {
    constructor(canvas) {
      this.cv = canvas; this.ctx = canvas.getContext('2d');
      this.fx = []; this.judgeText = null; this.lanesFlash = [0, 0, 0, 0];
    }

    _size() {
      const dpr = window.devicePixelRatio || 1;
      const W = this.cv.clientWidth, H = this.cv.clientHeight;
      if (this.cv.width !== Math.round(W * dpr) || this.cv.height !== Math.round(H * dpr)) {
        this.cv.width = Math.round(W * dpr); this.cv.height = Math.round(H * dpr);
      }
      this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      this.W = W; this.H = H;
      this.f = (H / 2) / Math.tan((GEO.FOV * Math.PI) / 360);
    }

    /** 월드 좌표 → 화면 [x, y, 깊이]. 카메라 뒤면 null. */
    P(x, y, z) {
      const d = sub([x, y, z], GEO.CAM);
      const zc = dot(d, FWD);
      if (zc < 0.05) return null;
      return [this.W / 2 + (dot(d, RIGHT) / zc) * this.f, this.H / 2 - (dot(d, UP) / zc) * this.f, zc];
    }

    _poly(pts, fill, stroke, lw) {
      const c = this.ctx;
      const ps = pts.map((p) => this.P(p[0], p[1], p[2]));
      if (ps.some((p) => !p)) return;
      c.beginPath(); c.moveTo(ps[0][0], ps[0][1]);
      for (let i = 1; i < ps.length; i++) c.lineTo(ps[i][0], ps[i][1]);
      c.closePath();
      if (fill) { c.fillStyle = fill; c.fill(); }
      if (stroke) { c.strokeStyle = stroke; c.lineWidth = lw || 1; c.stroke(); }
    }

    _line(a, b, color, lw, glow) {
      const c = this.ctx, p = this.P(...a), q = this.P(...b);
      if (!p || !q) return;
      c.save();
      if (glow) { c.shadowColor = color; c.shadowBlur = glow; }
      c.strokeStyle = color; c.lineWidth = lw; c.beginPath(); c.moveTo(p[0], p[1]); c.lineTo(q[0], q[1]); c.stroke();
      c.restore();
    }

    /** 판정 결과 표시 (텍스트 + 타격 이펙트) */
    onJudge(rec, grade, delta, isTick, now, judge) {
      if (!isTick || grade === GRADE.MISS) {
        if (!isTick || !this.judgeText || now - this.judgeText.t > 250) {
          this.judgeText = { g: grade, t: now, fs: !isTick && grade === GRADE.GREAT ? (delta < 0 ? 'FAST' : 'SLOW') : '' };
        }
      }
      if (grade === GRADE.MISS) return;
      let pos;
      if (rec.type === 'tap' || rec.type === 'hold') pos = [(rec.n.lane - 1.5) * GEO.LANE_W, 0.05, 0];
      else if (rec.type === 'flick') pos = [(rec.n.x - 0.5) * GEO.FIELD_W, GEO.AIR_Y, GEO.AIR_Z];
      else pos = [(judge.cursor - 0.5) * GEO.FIELD_W, GEO.AIR_Y, GEO.AIR_Z];
      this.fx.push({ pos, t: now, tick: isTick, color: isTick ? 'rgb(140,230,255)' : C.grade[grade], big: rec.type === 'flick' });
      if (this.fx.length > 40) this.fx.shift();
    }

    /** now = 곡 시간(ms), clock = 실제 시간(ms, 이펙트 수명용) */
    draw(judge, timing, now, opts) {
      this._size();
      const c = this.ctx, W = this.W, H = this.H;
      const speed = (GEO.SCROLL * (opts.hispeed || 1)) / 1000; // m/ms
      const zOf = (t) => -(t - now) * speed;
      const tFar = now + GEO.VIEW_DEPTH / speed;
      const fade = (z) => clamp(1 - (-z - GEO.VIEW_DEPTH * 0.7) / (GEO.VIEW_DEPTH * 0.3), 0, 1);
      const halfW = GEO.LANE_W * 2;

      // 배경
      const bg = c.createLinearGradient(0, 0, 0, H);
      bg.addColorStop(0, C.ink2); bg.addColorStop(1, C.ink);
      c.fillStyle = bg; c.fillRect(0, 0, W, H);

      // 바닥 + 레인
      this._poly([[-halfW, 0, 2], [halfW, 0, 2], [halfW, 0, -GEO.VIEW_DEPTH], [-halfW, 0, -GEO.VIEW_DEPTH]], 'rgba(22,18,40,0.92)');
      for (let l = 0; l < K.LANE_COUNT; l++) {
        const x0 = (l - 2) * GEO.LANE_W, x1 = x0 + GEO.LANE_W;
        const on = judge.pressed[l];
        if (on) this.lanesFlash[l] = 1; else this.lanesFlash[l] *= 0.85;
        const a = this.lanesFlash[l];
        if (a > 0.02) {
          const g0 = this.P(x0, 0, 0), g1 = this.P(x0, 0, -10);
          if (g0 && g1) {
            const gr = c.createLinearGradient(0, g0[1], 0, g1[1]);
            gr.addColorStop(0, `rgba(115,230,255,${0.32 * a})`); gr.addColorStop(1, 'rgba(115,230,255,0)');
            this._poly([[x0, 0, 0.6], [x1, 0, 0.6], [x1, 0, -10], [x0, 0, -10]], gr);
          }
        }
        if (l > 0) this._line([x0, 0, 1.5], [x0, 0, -GEO.VIEW_DEPTH], 'rgba(150,140,255,0.16)', 1);
      }
      // 박자선
      for (const g of timing.gridLines(now, tFar, 4)) {
        if (!g.onBeat) continue;
        const z = zOf(g.t);
        this._line([-halfW, 0, z], [halfW, 0, z], `rgba(184,158,255,${(g.strong ? 0.28 : 0.12) * fade(z)})`, g.strong ? 1.5 : 1);
      }
      // 양쪽 네온 테두리
      this._line([-halfW, 0, 1.5], [-halfW, 0, -GEO.VIEW_DEPTH], C.violet, 2.5, 14);
      this._line([halfW, 0, 1.5], [halfW, 0, -GEO.VIEW_DEPTH], C.magenta, 2.5, 14);
      // 바닥 판정선
      this._line([-halfW, 0, 0], [halfW, 0, 0], 'rgb(184,255,255)', 3, 18);
      for (let l = 0; l < K.LANE_COUNT; l++) {
        const p = this.P((l - 1.5) * GEO.LANE_W, 0, 0.55);
        if (!p) continue;
        c.fillStyle = judge.pressed[l] ? '#0a0b14' : 'rgba(204,219,255,0.75)';
        if (judge.pressed[l]) { c.save(); c.fillStyle = 'rgb(128,235,255)'; c.globalAlpha = 0.9; c.beginPath(); c.arc(p[0], p[1], 13, 0, Math.PI * 2); c.fill(); c.restore(); c.fillStyle = '#0a0b14'; }
        c.font = '600 13px Bahnschrift, "Segoe UI", sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle';
        c.fillText(K.LANE_KEYS[l], p[0], p[1]);
      }

      // 홀드 (머리 → 끝)
      for (const r of judge.notes) {
        if (r.type !== 'hold' || r.end < now - 50 || r.time > tFar) continue;
        const x0 = (r.n.lane - 2) * GEO.LANE_W + 0.14, x1 = x0 + GEO.LANE_W - 0.28;
        const held = r.headHit && judge.pressed[r.n.lane];
        const col = r.missed ? C.missed : held ? C.held : C.hold;
        const zs = r.headHit ? 0 : zOf(r.time), ze = Math.max(zOf(r.end), -GEO.VIEW_DEPTH);
        // 몸통은 조각마다 거리만큼 흐리게 (끝이 멀어도 가까운 쪽은 또렷하게)
        const segs = clamp(Math.ceil((zs - ze) / 1.5), 1, 24);
        for (let i = 0; i < segs; i++) {
          const za = zs - ((zs - ze) * i) / segs, zb = zs - ((zs - ze) * (i + 1)) / segs;
          c.globalAlpha = 0.55 * fade((za + zb) / 2);
          if (c.globalAlpha < 0.01) break;
          this._poly([[x0 + 0.1, 0.02, za], [x1 - 0.1, 0.02, za], [x1 - 0.1, 0.02, zb - 0.02], [x0 + 0.1, 0.02, zb - 0.02]], col);
        }
        c.globalAlpha = 1;
        if (!r.headHit) this._tapBar(x0, x1, zOf(r.time), r.missed ? C.missed : C.hold, fade(zOf(r.time)));
      }
      // 탭
      for (const r of judge.notes) {
        if (r.type !== 'tap' || r.judged && !r.missed || r.time > tFar || r.time < now - 300) continue;
        const x0 = (r.n.lane - 2) * GEO.LANE_W + 0.14, x1 = x0 + GEO.LANE_W - 0.28;
        this._tapBar(x0, x1, zOf(r.time), r.missed ? C.missed : C.tap, fade(zOf(r.time)));
      }

      // 공중: Field 리본
      const ay = GEO.AIR_Y, az = GEO.AIR_Z, fw = GEO.FIELD_W;
      for (const r of judge.fields) {
        if (r.end < now || r.time > tFar) continue;
        const t0 = Math.max(r.time, now), t1 = Math.min(r.end, tFar);
        const pts = [];
        for (let t = t0; ; t = Math.min(t + 40, t1)) {
          pts.push([t, fieldAt(r.n, t)]);
          if (t >= t1) break;
        }
        const live = r.time <= now;
        const rgb = live && judge.outside ? C.fieldOut : C.field;
        const left = pts.map(([t, a]) => [(a.center - a.width / 2 - 0.5) * fw, ay, zOf(t) + az]);
        const right = pts.map(([t, a]) => [(a.center + a.width / 2 - 0.5) * fw, ay, zOf(t) + az]).reverse();
        this._poly([...left, ...right], `rgba(${rgb[0]},${rgb[1]},${rgb[2]},0.26)`);
        c.save(); c.shadowColor = `rgb(${rgb})`; c.shadowBlur = 10;
        for (const edge of [left, right]) {
          const ps = edge.map((p) => this.P(...p)).filter(Boolean);
          c.strokeStyle = `rgba(${rgb[0] + 60 > 255 ? 255 : rgb[0] + 60},${Math.min(255, rgb[1] + 60)},${Math.min(255, rgb[2] + 40)},0.9)`;
          c.lineWidth = 2; c.beginPath();
          ps.forEach((p, i) => (i ? c.lineTo(p[0], p[1]) : c.moveTo(p[0], p[1])));
          c.stroke();
        }
        c.restore();
      }
      // 공중 판정선
      this._line([-fw / 2 - 0.3, ay, az], [fw / 2 + 0.3, ay, az], 'rgba(209,179,255,0.9)', 2, 12);
      // 플릭
      for (const r of judge.flicks) {
        if (r.judged && !r.missed || r.time > tFar || r.time < now - 300) continue;
        const z = zOf(r.time) + az, x = (r.n.x - 0.5) * fw, s = r.n.dir === 'left' ? -1 : 1;
        const col = r.missed ? C.missed : s < 0 ? C.flickL : C.flickR;
        c.globalAlpha = fade(z);
        c.save(); c.shadowColor = col; c.shadowBlur = 12;
        for (const k of [0, 0.32]) {
          this._poly([[x - s * (0.3 - k), ay, z - 0.25], [x + s * (0.12 + k), ay, z], [x - s * (0.3 - k), ay, z + 0.25], [x - s * (0.12 - k), ay, z]], col);
        }
        c.restore(); c.globalAlpha = 1;
      }
      // 커서 (기둥 + 마름모)
      const cx = (judge.cursor - 0.5) * fw;
      const ccol = judge.outside ? C.cursorOut : C.cursor;
      this._line([cx, 0, az], [cx, ay, az], 'rgba(191,247,255,0.28)', 2);
      const cp = this.P(cx, ay, az);
      if (cp) {
        c.save(); c.shadowColor = ccol; c.shadowBlur = 16; c.fillStyle = ccol;
        c.beginPath(); c.moveTo(cp[0], cp[1] - 11); c.lineTo(cp[0] + 9, cp[1]); c.lineTo(cp[0], cp[1] + 11); c.lineTo(cp[0] - 9, cp[1]); c.closePath(); c.fill();
        c.restore();
      }

      // 타격 이펙트
      const clock = opts.clock;
      this.fx = this.fx.filter((e) => clock - e.t < 320);
      for (const e of this.fx) {
        const p = this.P(...e.pos);
        if (!p) continue;
        const u = (clock - e.t) / 320;
        c.save(); c.globalAlpha = (1 - u) * (e.tick ? 0.5 : 0.95);
        c.strokeStyle = e.color; c.shadowColor = e.color; c.shadowBlur = 18; c.lineWidth = e.tick ? 2 : 3;
        c.beginPath(); c.arc(p[0], p[1], (e.tick ? 10 : e.big ? 26 : 20) + u * (e.tick ? 14 : 40), 0, Math.PI * 2); c.stroke();
        c.restore();
      }

      // HUD: 판정 / 콤보 / 점수
      c.textAlign = 'center'; c.textBaseline = 'middle';
      const jt = this.judgeText;
      const jp = this.P(0, 0.3, -3.2);
      if (jt && clock - jt.t < 450 && jp) {
        const u = (clock - jt.t) / 450;
        c.save(); c.globalAlpha = 1 - u * u;
        c.font = `700 ${Math.round(28 + (1 - u) * 4)}px Bahnschrift, "Segoe UI", sans-serif`;
        c.fillStyle = C.grade[jt.g]; c.shadowColor = C.grade[jt.g]; c.shadowBlur = 14;
        c.fillText(GRADE_NAME[jt.g], jp[0], jp[1]);
        if (jt.fs) { c.font = '600 13px Bahnschrift, "Segoe UI", sans-serif'; c.fillStyle = jt.fs === 'FAST' ? '#7fb6ff' : '#ff9a7a'; c.fillText(jt.fs, jp[0], jp[1] + 24); }
        c.restore();
      }
      const cpos = this.P(0, 0.2, -9);
      if (judge.combo >= 2 && cpos) {
        c.save(); c.font = '700 42px Bahnschrift, "Segoe UI", sans-serif'; c.fillStyle = 'rgba(247,247,255,0.9)';
        c.fillText(String(judge.combo), cpos[0], cpos[1] - 30);
        c.font = '600 11px Bahnschrift, "Segoe UI", sans-serif'; c.fillStyle = 'rgba(247,247,255,0.5)';
        c.fillText('COMBO', cpos[0], cpos[1]);
        c.restore();
      }
      c.textAlign = 'right'; c.textBaseline = 'top';
      c.font = '700 24px Bahnschrift, "Segoe UI", sans-serif'; c.fillStyle = '#f7f7ff';
      c.fillText(judge.score.toLocaleString('en-US'), W - 16, 44);
      c.font = '12px "Segoe UI", sans-serif'; c.fillStyle = 'rgba(247,247,255,0.55)';
      const acc = judge.judgedCount ? (judge.weight / judge.judgedCount) * 100 : 100;
      c.fillText(`정확도 ${acc.toFixed(2)}%   ·   P ${judge.counts[0]}  G ${judge.counts[1]}  M ${judge.counts[2]}`, W - 16, 74);
      if (judge.auto) { c.textAlign = 'left'; c.font = '700 13px Bahnschrift, "Segoe UI", sans-serif'; c.fillStyle = C.violet; c.fillText('AUTO', 16, 48); }

      if (opts.result) this._result(judge);
    }

    _tapBar(x0, x1, z, col, alpha) {
      const c = this.ctx;
      c.save(); c.globalAlpha = alpha; c.shadowColor = col; c.shadowBlur = 12;
      this._poly([[x0, 0.04, z + 0.13], [x1, 0.04, z + 0.13], [x1, 0.04, z - 0.13], [x0, 0.04, z - 0.13]], col);
      c.restore();
    }

    _result(j) {
      const c = this.ctx, W = this.W, H = this.H;
      c.fillStyle = 'rgba(8,7,15,0.78)'; c.fillRect(0, 0, W, H);
      c.textAlign = 'center'; c.textBaseline = 'middle';
      const acc = j.total ? (j.weight / j.total) * 100 : 0;
      const full = j.counts[2] === 0 && j.judgedCount === j.total;
      c.font = '600 13px "Segoe UI", sans-serif'; c.fillStyle = 'rgba(247,247,255,0.55)';
      c.fillText('테스트 결과 (시작 지점 이후 판정 ' + j.total + '개)', W / 2, H / 2 - 92);
      c.font = '700 52px Bahnschrift, "Segoe UI", sans-serif'; c.fillStyle = '#f7f7ff';
      c.fillText(j.score.toLocaleString('en-US'), W / 2, H / 2 - 48);
      c.font = '600 16px Bahnschrift, "Segoe UI", sans-serif';
      c.fillStyle = full ? (j.counts[1] === 0 ? C.grade[0] : C.grade[1]) : 'rgba(247,247,255,0.7)';
      c.fillText(full ? (j.counts[1] === 0 ? 'ALL PERFECT' : 'FULL COMBO') : `정확도 ${acc.toFixed(2)}%`, W / 2, H / 2 - 8);
      c.font = '15px "Segoe UI", sans-serif';
      const rows = [['PERFECT', j.counts[0], C.grade[0]], ['GREAT', j.counts[1], C.grade[1]], ['MISS', j.counts[2], C.grade[2]]];
      rows.forEach(([n, v, col], i) => { c.fillStyle = col; c.fillText(`${n}  ${v}`, W / 2 + (i - 1) * 120, H / 2 + 32); });
      c.fillStyle = 'rgba(247,247,255,0.7)';
      c.fillText(`최대 콤보 ${j.maxCombo} / ${j.total}   ·   FAST ${j.fast}  SLOW ${j.slow}`, W / 2, H / 2 + 62);
      c.fillStyle = 'rgba(247,247,255,0.45)'; c.font = '13px "Segoe UI", sans-serif';
      c.fillText('R 다시  ·  Esc 닫기', W / 2, H / 2 + 100);
    }
  }

  root.PlayTest = { PlayJudge, PlayView, GRADE, GEO };
})(typeof window !== 'undefined' ? window : globalThis);
