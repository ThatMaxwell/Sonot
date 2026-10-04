/* ==========================================================================
   SONOT — Launch film
   A ~49s real-time "video" built from DOM + CSS, driven by its own clock so it
   can pause with the tab, plus a generative WebAudio soundtrack.
   ========================================================================== */
(function () {
  'use strict';

  var LENGTH = 49; // seconds

  /* ---------- tiny helpers ---------- */
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function seeded(seed) { return function () { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }
  function pad(n) { return (n < 10 ? '0' : '') + n; }

  /* ======================================================================
     SOUNDTRACK — synthesized live, nothing to download
     ====================================================================== */
  var Sound = {
    ctx: null, master: null, wet: null, noise: null,
    on: false, offset: 0, scheduledTo: 0, events: null,

    ensure: function () {
      if (this.ctx) return true;
      var AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      var ctx = this.ctx = new AC();
      var comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -16; comp.ratio.value = 4;
      this.master = ctx.createGain(); this.master.gain.value = 0;
      this.master.connect(comp); comp.connect(ctx.destination);

      // Reverb from a decaying noise impulse
      var len = ctx.sampleRate * 3, ir = ctx.createBuffer(2, len, ctx.sampleRate);
      for (var c = 0; c < 2; c++) {
        var d = ir.getChannelData(c);
        for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 2.6);
      }
      var verb = ctx.createConvolver(); verb.buffer = ir;
      this.wet = ctx.createGain(); this.wet.gain.value = .55;
      this.wet.connect(verb); verb.connect(this.master);

      var nb = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate), nd = nb.getChannelData(0);
      for (var j = 0; j < nd.length; j++) nd[j] = Math.random() * 2 - 1;
      this.noise = nb;
      this.events = this.compose();
      return true;
    },

    out: function (node, wet) {
      node.connect(this.master);
      if (wet) { var g = this.ctx.createGain(); g.gain.value = wet; node.connect(g); g.connect(this.wet); }
    },

    hz: function (m) { return 440 * Math.pow(2, (m - 69) / 12); },

    pad: function (t, notes, dur, vol) {
      var ctx = this.ctx, self = this;
      var f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 1100; f.Q.value = .6;
      var g = ctx.createGain();
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(vol, t + .9);
      g.gain.setValueAtTime(vol, t + dur - .2);
      g.gain.linearRampToValueAtTime(0, t + dur + 1.2);
      f.connect(g); this.out(g, .9);
      notes.forEach(function (m) {
        [-7, 7].forEach(function (cents) {
          var o = ctx.createOscillator(); o.type = 'sawtooth';
          o.frequency.value = self.hz(m); o.detune.value = cents;
          o.connect(f); o.start(t); o.stop(t + dur + 1.4);
        });
      });
    },

    pluck: function (t, m, vol) {
      var ctx = this.ctx, o = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter();
      o.type = 'triangle'; o.frequency.value = this.hz(m);
      f.type = 'lowpass'; f.frequency.setValueAtTime(4200, t); f.frequency.exponentialRampToValueAtTime(600, t + .35);
      g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(vol, t + .005); g.gain.exponentialRampToValueAtTime(.0001, t + .55);
      o.connect(f); f.connect(g); this.out(g, .7);
      o.start(t); o.stop(t + .6);
    },

    kick: function (t, vol) {
      var ctx = this.ctx, o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine';
      o.frequency.setValueAtTime(130, t); o.frequency.exponentialRampToValueAtTime(42, t + .16);
      g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.0001, t + .45);
      o.connect(g); this.out(g, .1);
      o.start(t); o.stop(t + .5);
    },

    hat: function (t, vol) {
      var ctx = this.ctx, s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
      s.buffer = this.noise; f.type = 'highpass'; f.frequency.value = 7500;
      g.gain.setValueAtTime(vol, t); g.gain.exponentialRampToValueAtTime(.0001, t + .06);
      s.connect(f); f.connect(g); this.out(g, .15);
      s.start(t, Math.random()); s.stop(t + .08);
    },

    whoosh: function (t, dur, vol) {
      var ctx = this.ctx, s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
      s.buffer = this.noise; s.loop = true;
      f.type = 'bandpass'; f.Q.value = 1.2;
      f.frequency.setValueAtTime(300, t); f.frequency.exponentialRampToValueAtTime(5000, t + dur);
      g.gain.setValueAtTime(.0001, t); g.gain.exponentialRampToValueAtTime(vol, t + dur * .95); g.gain.linearRampToValueAtTime(0, t + dur + .05);
      s.connect(f); f.connect(g); this.out(g, .5);
      s.start(t); s.stop(t + dur + .1);
    },

    impact: function (t, vol) {
      this.kick(t, vol);
      var ctx = this.ctx, s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
      s.buffer = this.noise;
      f.type = 'lowpass'; f.frequency.setValueAtTime(6000, t); f.frequency.exponentialRampToValueAtTime(200, t + 1.2);
      g.gain.setValueAtTime(vol * .5, t); g.gain.exponentialRampToValueAtTime(.0001, t + 1.4);
      s.connect(f); f.connect(g); this.out(g, 1);
      s.start(t); s.stop(t + 1.5);
      // shimmering bell on top
      var self = this;
      [86, 93, 98].forEach(function (m, i) { self.pluck(t + i * .04, m, .05); });
    },

    /* The score: a list of {t, fn} on the film timeline */
    compose: function () {
      var ev = [], self = this, beat = .625; // 96 bpm
      var chords = [
        [50, 57, 61, 64, 66], // Dmaj9
        [47, 54, 57, 61, 62], // Bm9
        [43, 50, 54, 59, 61], // Gmaj7#11
        [45, 52, 54, 59, 62]  // A6sus
      ];
      function at(t, fn) { ev.push({ t: t, fn: fn }); }

      // Opening drone + a high glint when the spark appears
      at(0, function (T) { self.pad(T, [38, 45], 4.6, .05); });
      at(.4, function (T) { self.pluck(T, 81, .06); self.pluck(T + .3, 88, .04); });
      // Riser into the bloom impact (square lands at 4.6 + 1.9)
      at(4.6, function (T) { self.whoosh(T, 1.9, .22); });
      at(6.5, function (T) { self.impact(T, .9); self.pad(T, chords[0], 3.5, .06); });

      // Main groove: 10s → 43.2s
      for (var t = 10; t < 43.2; t += beat * 4) {
        (function (t) {
          var c = chords[Math.floor((t - 10) / (beat * 4)) % 4];
          at(t, function (T) { self.pad(T, c, beat * 4, .045); });
        })(t);
      }
      for (var b = 0; 10 + b * beat < 38.6; b++) {
        (function (b) {
          var t = 10 + b * beat, c = chords[Math.floor(b / 4) % 4];
          at(t, function (T) { self.kick(T, b % 4 === 0 ? .7 : .45); });
          if (t >= 16.6) at(t + beat / 2, function (T) { self.hat(T, .12); });
          var arp = [c[1] + 12, c[2] + 12, c[3] + 12, c[4] + 12];
          at(t, function (T) { self.pluck(T, arp[(b * 2) % 4], .07); });
          at(t + beat / 2, function (T) { self.pluck(T, arp[(b * 2 + 1) % 4], .05); });
        })(b);
      }
      // Scene-change sweeps
      [16.1, 22.1, 28.1, 33.1].forEach(function (t) { at(t, function (T) { self.whoosh(T, .5, .08); }); });
      // Montage: a hit on every cut
      for (var k = 0; k < 7; k++) {
        (function (k) { at(38.6 + k * .5, function (T) { self.kick(T, .8); self.hat(T, .2); self.pluck(T, 74 + (k % 3) * 5, .06); }); })(k);
      }
      at(42.1, function (T) { self.whoosh(T, 1.1, .2); });
      // Finale
      at(43.4, function (T) { self.impact(T, 1); self.pad(T, [38, 50, 57, 61, 64, 66, 69], 5.2, .07); });
      at(44.6, function (T) { [74, 78, 81, 85].forEach(function (m, i) { self.pluck(T + i * .18, m, .06); }); });
      return ev.sort(function (a, b) { return a.t - b.t; });
    },

    enable: function (filmT) {
      if (!this.ensure()) return false;
      var ctx = this.ctx;
      if (ctx.state === 'suspended') ctx.resume();
      this.on = true;
      this.offset = ctx.currentTime - filmT + .05;
      this.scheduledTo = filmT;
      this.master.gain.cancelScheduledValues(ctx.currentTime);
      this.master.gain.setTargetAtTime(.75, ctx.currentTime, .3);
      return true;
    },

    disable: function () {
      if (!this.ctx) return;
      this.on = false;
      this.master.gain.cancelScheduledValues(this.ctx.currentTime);
      this.master.gain.setTargetAtTime(0, this.ctx.currentTime, .15);
    },

    tick: function (filmT) {
      if (!this.on || !this.events) return;
      var horizon = filmT + .3, self = this;
      this.events.forEach(function (e) {
        if (e.t >= self.scheduledTo && e.t < horizon) e.fn(self.offset + e.t);
      });
      this.scheduledTo = horizon;
    },

    pause: function () { if (this.ctx && this.ctx.state === 'running') this.ctx.suspend(); },
    resume: function () { if (this.ctx && this.on) this.ctx.resume(); }
  };

  /* ======================================================================
     FILM CONTROLLER
     ====================================================================== */
  var Film = {
    el: null, scenes: [], typers: [], t: 0, last: 0,
    playing: false, paused: false, onEnd: null, built: false,

    build: function () {
      if (this.built) return;
      this.built = true;
      var el = this.el = $('#film');
      this.scenes = $$('.scene', el).map(function (s) {
        var a = parseFloat(s.dataset.start), b = parseFloat(s.dataset.end);
        s.style.setProperty('--dur', (b - a) + 's');
        return { el: s, start: a, end: b, on: false };
      });
      this.typers = [
        { el: $('#filmAskText'), text: 'Plan 3 days in Kyoto for under $800 ✈️', t0: 10.6, t1: 12.45 }
      ];
      this.progress = $('#filmProgress');
      this.time = $('#filmTime');
      this.buildBloom();
      this.buildNetwork();
      $$('.ed-body .ln', el).forEach(function (l, i) { l.style.setProperty('--n', i); });

      var self = this;
      $('#filmSkip').addEventListener('click', function () { self.finish(); });
      var snd = $('#filmSound');
      snd.addEventListener('click', function () {
        if (Sound.on) { Sound.disable(); } else if (!Sound.enable(self.t)) { return; }
        snd.setAttribute('aria-pressed', Sound.on ? 'true' : 'false');
        snd.querySelector('.lbl').textContent = Sound.on ? 'Sound on' : 'Sound off';
        try { localStorage.setItem('sonot.sound', Sound.on ? '1' : '0'); } catch (e) {}
      });
      document.addEventListener('keydown', function (e) {
        if (!self.playing) return;
        if (e.key === 'Escape') self.finish();
        if (e.key === 'm' || e.key === 'M') snd.click();
      });
      document.addEventListener('visibilitychange', function () {
        if (!self.playing) return;
        self.setPaused(document.hidden);
      });
    },

    /* Petals that fly in from all over the screen and lock into the icon */
    buildBloom: function () {
      var rnd = seeded(8), html = '';
      for (var i = 0; i < 8; i++) {
        var x = Math.round((rnd() - .5) * 2600), y = Math.round((rnd() - .5) * 1800), r = Math.round((rnd() - .5) * 540);
        html += '<g transform="rotate(' + i * 45 + ' 512 512)"><use class="bp" href="#petal" style="--i:' + i + ';--x:' + x + 'px;--y:' + y + 'px;--rot:' + r + 'deg"/></g>';
      }
      $('.b-petals', this.el).innerHTML = html;
    },

    /* A constellation that draws itself outward from a central "hub" */
    buildNetwork: function () {
      var rnd = seeded(42), W = 600, H = 420, cx = 300, cy = 210, nodes = [{ x: cx, y: cy, hub: true }];
      var rings = [[7, 85], [11, 150], [15, 220]];
      rings.forEach(function (ring, ri) {
        for (var i = 0; i < ring[0]; i++) {
          var a = (i / ring[0]) * Math.PI * 2 + ri * .5 + (rnd() - .5) * .45;
          var r = ring[1] + (rnd() - .5) * 34;
          var x = cx + Math.cos(a) * r * 1.25, y = cy + Math.sin(a) * r * .78;
          if (x > 14 && x < W - 14 && y > 14 && y < H - 14) nodes.push({ x: x, y: y });
        }
      });
      function dist(a, b) { return Math.hypot(a.x - b.x, a.y - b.y); }
      var lines = [], seen = {};
      nodes.forEach(function (n, i) {
        if (i === 0) return;
        var near = nodes.map(function (m, j) { return { j: j, d: dist(n, m) }; })
          .filter(function (o) { return o.j !== i; })
          .sort(function (a, b) { return a.d - b.d; }).slice(0, 2);
        near.forEach(function (o) {
          var key = Math.min(i, o.j) + '-' + Math.max(i, o.j);
          if (!seen[key]) { seen[key] = 1; lines.push([n, nodes[o.j]]); }
        });
        if (dist(n, nodes[0]) < 140) lines.push([nodes[0], n]);
      });
      function delay(p) { return (.35 + dist(p, nodes[0]) / 210 * 1.7).toFixed(2) + 's'; }
      var svg = '';
      lines.forEach(function (l) {
        var a = dist(l[0], nodes[0]) <= dist(l[1], nodes[0]) ? l[0] : l[1], b = a === l[0] ? l[1] : l[0];
        var len = Math.ceil(dist(a, b));
        svg += '<line x1="' + a.x.toFixed(1) + '" y1="' + a.y.toFixed(1) + '" x2="' + b.x.toFixed(1) + '" y2="' + b.y.toFixed(1) + '" style="--len:' + len + ';--d:' + delay(a) + '"/>';
      });
      nodes.forEach(function (n) {
        svg += '<circle cx="' + n.x.toFixed(1) + '" cy="' + n.y.toFixed(1) + '" r="' + (n.hub ? 13 : (2.5 + rnd() * 3).toFixed(1)) + '"' + (n.hub ? ' class="hub"' : '') + ' style="--d:' + (n.hub ? '.2s' : delay(n)) + '"/>';
      });
      $('.net', this.el).innerHTML = svg;
    },

    play: function (onEnd) {
      this.build();
      var self = this, el = this.el;
      this.onEnd = onEnd || null;
      this.t = 0; this.playing = true; this.paused = false;
      this.scenes.forEach(function (s) { s.on = false; s.el.classList.remove('on'); });
      this.typers.forEach(function (ty) { ty.el.textContent = ''; });
      el.hidden = false; el.setAttribute('aria-hidden', 'false');
      el.classList.remove('paused');
      document.body.classList.add('film-open');
      requestAnimationFrame(function () { el.classList.add('show'); });
      // Keep the visitor's sound preference (needs a gesture, so only when replayed by click)
      var snd = $('#filmSound'), wants = false;
      try { wants = localStorage.getItem('sonot.sound') === '1'; } catch (e) {}
      if (wants && navigator.userActivation && navigator.userActivation.isActive && Sound.enable(0)) {
        snd.setAttribute('aria-pressed', 'true'); snd.querySelector('.lbl').textContent = 'Sound on';
      } else if (!Sound.on) {
        snd.setAttribute('aria-pressed', 'false'); snd.querySelector('.lbl').textContent = 'Sound off';
      } else {
        Sound.enable(0);
      }
      this.last = performance.now();
      requestAnimationFrame(function loop(now) {
        if (!self.playing) return;
        var dt = Math.min(.1, (now - self.last) / 1000);
        self.last = now;
        if (!self.paused) self.t += dt;
        self.render();
        if (self.t >= LENGTH) self.finish(); else requestAnimationFrame(loop);
      });
    },

    setPaused: function (p) {
      this.paused = p;
      this.el.classList.toggle('paused', p);
      if (p) Sound.pause(); else Sound.resume();
    },

    render: function () {
      var t = this.t;
      this.scenes.forEach(function (s) {
        var on = t >= s.start && t < s.end;
        if (on !== s.on) { s.on = on; s.el.classList.toggle('on', on); }
      });
      this.typers.forEach(function (ty) {
        var p = Math.max(0, Math.min(1, (t - ty.t0) / (ty.t1 - ty.t0)));
        var chars = Array.from(ty.text), n = Math.round(p * chars.length);
        if (ty.n !== n) { ty.n = n; ty.el.textContent = chars.slice(0, n).join(''); }
      });
      this.progress.style.transform = 'scaleX(' + Math.min(1, t / LENGTH) + ')';
      var s = Math.floor(t);
      if (s !== this._s) { this._s = s; this.time.textContent = pad(Math.floor(s / 60)) + ':' + pad(s % 60) + ' / 00:' + LENGTH; }
      Sound.tick(t);
    },

    finish: function () {
      if (!this.playing) return;
      this.playing = false;
      var el = this.el, self = this;
      Sound.disable();
      el.classList.remove('show');
      el.setAttribute('aria-hidden', 'true');
      document.body.classList.remove('film-open');
      if (this.onEnd) this.onEnd();
      setTimeout(function () {
        if (self.playing) return;
        el.hidden = true;
        self.scenes.forEach(function (s) { s.on = false; s.el.classList.remove('on'); });
      }, 950);
    }
  };

  window.SonotFilm = Film;
  window.SonotFilm.LENGTH = LENGTH;
})();
