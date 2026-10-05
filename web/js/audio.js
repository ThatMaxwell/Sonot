/* ==========================================================================
   SONOT — "Think in Light" (launch film soundtrack)
   A full track synthesized live with WebAudio. 124 BPM, Ab major / F minor.
   26 bars ≈ 50.3s:  intro 0-3 · build 4-7 · DROP 8-15 · break 16-17 ·
                     DROP 18-23 · outro 24-25
   The film reads its clock from here, so every cut lands on the beat.
   ========================================================================== */
(function () {
  'use strict';

  var BPM = 124, BEAT = 60 / BPM, STEP = BEAT / 4, BAR = BEAT * 4, BARS = 26;
  var LENGTH = BARS * BAR;

  // Fm – Db – Ab – Eb  (vi–IV–I–V in Ab)
  var CHORDS = [
    { bass: 41, notes: [65, 68, 72, 77] },   // Fm
    { bass: 37, notes: [65, 68, 73, 77] },   // Db
    { bass: 44, notes: [63, 68, 72, 75] },   // Ab
    { bass: 39, notes: [63, 67, 70, 75] }    // Eb
  ];
  // Lead hook, 8th-note grid, 4 bars (null = rest)
  var HOOK = [
    [72, null, 68, null, 72, 75, null, 72],
    [73, null, 72, 68, null, 65, null, null],
    [75, null, 72, null, 75, 77, 75, 72],
    [70, null, 67, null, 70, null, 72, null]
  ];

  var ctx = null, master, comp, music, duck, verb, verbIn, delayIn, noise;
  var t0 = 0, step = 0, timer = null, started = false, muted = false;

  function hz(m) { return 440 * Math.pow(2, (m - 69) / 12); }

  function build() {
    if (ctx) return true;
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    ctx = new AC({ latencyHint: 'interactive' });

    comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -10; comp.knee.value = 8; comp.ratio.value = 6; comp.attack.value = .003; comp.release.value = .12;
    master = ctx.createGain(); master.gain.value = 0;
    master.connect(comp); comp.connect(ctx.destination);

    // Everything melodic goes through a sidechain "duck" bus that pumps with the kick
    duck = ctx.createGain(); duck.connect(master);
    music = ctx.createGain(); music.gain.value = 1; music.connect(duck);

    // Reverb
    var len = ctx.sampleRate * 2.8, ir = ctx.createBuffer(2, len, ctx.sampleRate);
    for (var c = 0; c < 2; c++) {
      var d = ir.getChannelData(c);
      for (var i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, 3);
    }
    verb = ctx.createConvolver(); verb.buffer = ir;
    verbIn = ctx.createGain(); verbIn.gain.value = .5;
    verbIn.connect(verb); verb.connect(duck);

    // Dotted-8th ping-pong-ish delay for the lead
    var dl = ctx.createDelay(1); dl.delayTime.value = BEAT * .75;
    var fb = ctx.createGain(); fb.gain.value = .38;
    var dlf = ctx.createBiquadFilter(); dlf.type = 'lowpass'; dlf.frequency.value = 3200;
    delayIn = ctx.createGain(); delayIn.gain.value = .3;
    delayIn.connect(dl); dl.connect(dlf); dlf.connect(fb); fb.connect(dl); dlf.connect(music);

    var nb = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate), nd = nb.getChannelData(0);
    for (var j = 0; j < nd.length; j++) nd[j] = Math.random() * 2 - 1;
    noise = nb;
    return true;
  }

  function send(node, wet, dry, dly) {
    node.connect(dry || music);
    if (wet) { var g = ctx.createGain(); g.gain.value = wet; node.connect(g); g.connect(verbIn); }
    if (dly) { var g2 = ctx.createGain(); g2.gain.value = dly; node.connect(g2); g2.connect(delayIn); }
  }

  /* ---------------- instruments ---------------- */
  function kick(t, v) {
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine';
    o.frequency.setValueAtTime(165, t); o.frequency.exponentialRampToValueAtTime(48, t + .11);
    g.gain.setValueAtTime(v, t); g.gain.setValueAtTime(v, t + .03); g.gain.exponentialRampToValueAtTime(.001, t + .42);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + .45);
    // click
    var s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), cg = ctx.createGain();
    s.buffer = noise; f.type = 'highpass'; f.frequency.value = 3000;
    cg.gain.setValueAtTime(v * .25, t); cg.gain.exponentialRampToValueAtTime(.001, t + .015);
    s.connect(f); f.connect(cg); cg.connect(master); s.start(t, Math.random()); s.stop(t + .02);
    // sidechain pump
    duck.gain.setValueAtTime(.18, t);
    duck.gain.linearRampToValueAtTime(1, t + BEAT * .62);
  }

  function clap(t, v) {
    var s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = noise; f.type = 'bandpass'; f.frequency.value = 1400; f.Q.value = .9;
    g.gain.setValueAtTime(0, t);
    [0, .011, .022].forEach(function (o) { g.gain.setValueAtTime(v, t + o); g.gain.exponentialRampToValueAtTime(v * .3, t + o + .009); });
    g.gain.setValueAtTime(v, t + .033); g.gain.exponentialRampToValueAtTime(.001, t + .22);
    s.connect(f); f.connect(g); g.connect(master);
    var w = ctx.createGain(); w.gain.value = .35; g.connect(w); w.connect(verbIn);
    s.start(t, Math.random()); s.stop(t + .25);
  }

  function hat(t, v, open) {
    var s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = noise; f.type = 'highpass'; f.frequency.value = open ? 7000 : 9000;
    var d = open ? .19 : .035;
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + d);
    s.connect(f); f.connect(g); g.connect(master);
    s.start(t, Math.random()); s.stop(t + d + .02);
  }

  function snare(t, v, tone) {
    var s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = noise; f.type = 'bandpass'; f.frequency.value = tone || 2200; f.Q.value = .6;
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + .12);
    s.connect(f); f.connect(g); g.connect(master);
    s.start(t, Math.random()); s.stop(t + .14);
  }

  function sub(t, m, dur, v) {
    var o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter();
    o.type = 'sine'; o.frequency.value = hz(m);
    o2.type = 'sawtooth'; o2.frequency.value = hz(m);
    f.type = 'lowpass'; f.frequency.value = 420;
    var g2 = ctx.createGain(); g2.gain.value = .25;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .008);
    g.gain.setValueAtTime(v, t + dur - .03); g.gain.linearRampToValueAtTime(0, t + dur);
    o.connect(g); o2.connect(g2); g2.connect(f); f.connect(g);
    g.connect(music);
    o.start(t); o2.start(t); o.stop(t + dur + .02); o2.stop(t + dur + .02);
  }

  // Supersaw chord; `cut` sets the filter (for builds), `rel` the release
  function saw(t, notes, dur, v, cut, rel, wet) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain();
    f.type = 'lowpass'; f.Q.value = 1.2;
    if (Array.isArray(cut)) { f.frequency.setValueAtTime(cut[0], t); f.frequency.exponentialRampToValueAtTime(cut[1], t + dur); }
    else f.frequency.value = cut || 5200;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .012);
    g.gain.setValueAtTime(v, t + dur); g.gain.exponentialRampToValueAtTime(.0008, t + dur + (rel || .12));
    f.connect(g); send(g, wet === undefined ? .25 : wet);
    notes.forEach(function (m) {
      [-14, -6, 0, 7, 15].forEach(function (cents, k) {
        var o = ctx.createOscillator(); o.type = 'sawtooth';
        o.frequency.value = hz(m); o.detune.value = cents + (k === 2 ? 0 : (Math.random() - .5) * 4);
        o.connect(f); o.start(t); o.stop(t + dur + (rel || .12) + .05);
      });
    });
  }

  function pad(t, notes, dur, v, cut) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain();
    f.type = 'lowpass';
    if (Array.isArray(cut)) { f.frequency.setValueAtTime(cut[0], t); f.frequency.exponentialRampToValueAtTime(cut[1], t + dur); }
    else f.frequency.value = cut || 1400;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .5);
    g.gain.setValueAtTime(v, t + dur - .1); g.gain.linearRampToValueAtTime(0, t + dur + .6);
    f.connect(g); send(g, .7);
    notes.forEach(function (m) {
      [-8, 8].forEach(function (c) {
        var o = ctx.createOscillator(); o.type = 'sawtooth'; o.frequency.value = hz(m); o.detune.value = c;
        o.connect(f); o.start(t); o.stop(t + dur + .7);
      });
    });
  }

  function pluck(t, m, v, wet, dly) {
    var o = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter();
    o.type = 'triangle'; o.frequency.value = hz(m);
    f.type = 'lowpass'; f.frequency.setValueAtTime(5000, t); f.frequency.exponentialRampToValueAtTime(700, t + .25);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .004); g.gain.exponentialRampToValueAtTime(.001, t + .4);
    o.connect(f); f.connect(g); send(g, wet || .3, null, dly || .25);
    o.start(t); o.stop(t + .45);
  }

  function lead(t, m, dur, v) {
    var o = ctx.createOscillator(), o2 = ctx.createOscillator(), g = ctx.createGain(), f = ctx.createBiquadFilter();
    o.type = 'square'; o2.type = 'sawtooth';
    o.frequency.value = hz(m); o2.frequency.value = hz(m + 12); o2.detune.value = 6;
    var g2 = ctx.createGain(); g2.gain.value = .35;
    f.type = 'lowpass'; f.Q.value = 3;
    f.frequency.setValueAtTime(5500, t); f.frequency.exponentialRampToValueAtTime(1600, t + dur);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .006);
    g.gain.setValueAtTime(v * .8, t + dur * .7); g.gain.exponentialRampToValueAtTime(.001, t + dur + .08);
    o.connect(f); o2.connect(g2); g2.connect(f); f.connect(g);
    send(g, .3, null, .4);
    o.start(t); o2.start(t); o.stop(t + dur + .1); o2.stop(t + dur + .1);
  }

  function riser(t, dur, v) {
    var s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), g = ctx.createGain();
    s.buffer = noise; s.loop = true;
    f.type = 'bandpass'; f.Q.value = 2;
    f.frequency.setValueAtTime(250, t); f.frequency.exponentialRampToValueAtTime(9000, t + dur);
    g.gain.setValueAtTime(.0008, t); g.gain.exponentialRampToValueAtTime(v, t + dur); g.gain.linearRampToValueAtTime(0, t + dur + .02);
    s.connect(f); f.connect(g); g.connect(master);
    var w = ctx.createGain(); w.gain.value = .4; g.connect(w); w.connect(verbIn);
    s.start(t); s.stop(t + dur + .05);
    // pitch riser
    var o = ctx.createOscillator(), og = ctx.createGain();
    o.type = 'sawtooth'; o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(1760, t + dur);
    og.gain.setValueAtTime(.0005, t); og.gain.exponentialRampToValueAtTime(v * .25, t + dur); og.gain.linearRampToValueAtTime(0, t + dur + .02);
    var of = ctx.createBiquadFilter(); of.type = 'lowpass'; of.frequency.value = 3000;
    o.connect(of); of.connect(og); og.connect(master); o.start(t); o.stop(t + dur + .05);
  }

  function impact(t, v) {
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.type = 'sine'; o.frequency.setValueAtTime(90, t); o.frequency.exponentialRampToValueAtTime(30, t + 1.4);
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + 1.8);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + 1.9);
    var s = ctx.createBufferSource(), f = ctx.createBiquadFilter(), ng = ctx.createGain();
    s.buffer = noise; f.type = 'lowpass';
    f.frequency.setValueAtTime(9000, t); f.frequency.exponentialRampToValueAtTime(150, t + 1.6);
    ng.gain.setValueAtTime(v * .55, t); ng.gain.exponentialRampToValueAtTime(.001, t + 1.8);
    s.connect(f); f.connect(ng); ng.connect(master);
    var w = ctx.createGain(); w.gain.value = .9; ng.connect(w); w.connect(verbIn);
    s.start(t); s.stop(t + 1.9);
  }

  /* ---------------- arrangement: one call per 16th step ---------------- */
  function play(n, t) {
    var bar = Math.floor(n / 16), s = n % 16, beat = Math.floor(s / 4), ch = CHORDS[bar % 4];
    var intro = bar < 4, build = bar >= 4 && bar < 8, drop1 = bar >= 8 && bar < 16;
    var brk = bar >= 16 && bar < 18, drop2 = bar >= 18 && bar < 24, outro = bar >= 24;
    var drop = drop1 || drop2;

    // INTRO — dark pad, heartbeat thump on each beat, glassy arp
    if (intro) {
      if (s === 0) pad(t, ch.notes.map(function (m) { return m - 12; }), BAR, .05, [500 + bar * 250, 900 + bar * 300]);
      if (s % 4 === 0) { kick(t, .22 + bar * .05); }
      if (bar >= 1) pluck(t, ch.notes[[0, 2, 1, 3][s % 4]] + 12, .035 + bar * .008, .4, .3);
      if (bar >= 2 && s % 2 === 1) hat(t, .025);
      if (bar === 3 && s === 0) riser(t, BAR, .12);
    }

    // BUILD — four on the floor, filter opens, snare roll, gap before the drop
    if (build) {
      var k = bar - 4;
      if (s % 4 === 0 && !(bar === 7 && s >= 12)) kick(t, .75);
      if (s === 0) saw(t, ch.notes, BAR * .96, .05, [400 + k * 500, 900 + k * 900], .2, .5);
      if (s % 2 === 1) hat(t, .045 + k * .01);
      if (bar >= 6 && (s === 4 || s === 12)) clap(t, .35);
      if (s === 2 || s === 6 || s === 10 || s === 14) sub(t, ch.bass, STEP * 1.6, .28 + k * .03);
      if (bar === 6 && s === 0) riser(t, BAR * 2 - BEAT, .3);
      if (bar === 7) {
        var roll = s < 8 ? (s % 2 === 0) : true;
        if (roll && s < 15) snare(t, .12 + s * .018, 1800 + s * 160);
        if (s >= 8 && s < 15) snare(t + STEP / 2, .14 + s * .018, 2000 + s * 180);
      }
    }

    // DROPS — the banger
    if (drop) {
      var d2 = drop2;
      if (s === 0 && (bar === 8 || bar === 18)) impact(t, .9);
      if (s % 4 === 0) kick(t, 1);
      if (s === 4 || s === 12) clap(t, .5);
      if (s % 4 === 2) hat(t, .09, true);
      else if (s % 2 === 1) hat(t, .05);
      if (d2 && s % 2 === 0 && s % 4 !== 0) hat(t, .035);
      // offbeat bass
      if (s % 4 === 2) sub(t, ch.bass, STEP * 1.7, .4);
      if (s === 15) sub(t, ch.bass + 12, STEP * .8, .25);
      // future-bass stabs
      if ([0, 3, 6, 10, 12].indexOf(s) >= 0) saw(t, ch.notes, s === 12 ? STEP * 3 : STEP * 1.6, .085, d2 ? 6500 : 5200, .1, .25);
      // hook
      if (s % 2 === 0) {
        var note = HOOK[(bar - (d2 ? 18 : 8)) % 4][s / 2];
        if (note) lead(t, note + (d2 && bar >= 22 ? 12 : 0), STEP * 1.8, .06);
      }
      if (d2) pluck(t, ch.notes[[3, 1, 2, 0][s % 4]] + 12, .028, .25, .15);
    }

    // BREAK — drums out, filtered hook, tension back up
    if (brk) {
      if (s === 0) pad(t, ch.notes, BAR, .055, [700, 1800]);
      if (s % 2 === 0) {
        var bn = HOOK[(bar - 16) % 4][s / 2];
        if (bn) pluck(t, bn, .06, .5, .45);
      }
      if (bar === 17 && s === 0) riser(t, BAR - BEAT * .5, .32);
      if (bar === 17 && s >= 8 && s < 15) { snare(t, .1 + (s - 8) * .025, 2200 + s * 120); snare(t + STEP / 2, .12 + (s - 8) * .025, 2400 + s * 120); }
      if (bar === 17 && s >= 12 && s % 4 === 0) kick(t, .5);
    }

    // OUTRO — last hit, big Ab chord rings out
    if (outro) {
      if (bar === 24 && s === 0) {
        impact(t, 1); kick(t, 1);
        saw(t, [56, 63, 68, 72, 75, 80], BAR * 1.6, .07, [6500, 900], 1.6, .8);
        pad(t, [44, 56, 63, 70], BAR * 1.8, .07, 1600);
        sub(t, 32, BAR * 1.2, .35);
      }
      if (bar === 24 && s % 2 === 0 && s >= 4) pluck(t, [80, 84, 87, 92, 87, 84][(s / 2 - 2) % 6], .04 - s * .0015, .6, .5);
    }
  }

  function pump() {
    var ahead = ctx.currentTime + .14;
    while (t0 + step * STEP < ahead && step < BARS * 16) {
      var at = t0 + step * STEP;
      if (at >= ctx.currentTime - .01) play(step, Math.max(at, ctx.currentTime));
      step++;
    }
    if (step >= BARS * 16 && timer) { clearInterval(timer); timer = null; }
  }

  /* ---------------- public API ---------------- */
  var api = {
    LENGTH: LENGTH, BPM: BPM, BEAT: BEAT, BAR: BAR,

    // Call from a click/tap: creates and unlocks the audio engine
    unlock: function () {
      if (!build()) return false;
      if (ctx.state !== 'running') ctx.resume();
      return true;
    },
    state: function () { return ctx ? ctx.state : 'none'; },

    // Start the song at film time `from` (seconds). Returns true if audible clock is running.
    start: function (from) {
      if (!build()) return false;
      if (ctx.state !== 'running') { ctx.resume(); return false; }
      from = Math.max(0, from || 0);
      t0 = ctx.currentTime - from + .03;
      step = Math.ceil(from / STEP);
      started = true;
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setValueAtTime(master.gain.value, ctx.currentTime);
      master.gain.linearRampToValueAtTime(muted ? 0 : .9, ctx.currentTime + .08);
      if (timer) clearInterval(timer);
      timer = setInterval(pump, 25);
      pump();
      return true;
    },
    // Film time according to the audio clock, or -1 when not playing
    time: function () { return started && ctx && ctx.state === 'running' ? ctx.currentTime - t0 : -1; },
    started: function () { return started; },
    stop: function () {
      if (!ctx) return;
      started = false;
      if (timer) { clearInterval(timer); timer = null; }
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setValueAtTime(master.gain.value, ctx.currentTime);
      master.gain.linearRampToValueAtTime(0, ctx.currentTime + .6);
    },
    pause: function () { if (ctx && ctx.state === 'running') ctx.suspend(); },
    resume: function () { if (ctx && started) ctx.resume(); },
    setMuted: function (m) {
      muted = !!m;
      if (!ctx) return;
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setTargetAtTime(muted || !started ? 0 : .9, ctx.currentTime, .05);
    },
    muted: function () { return muted; }
  };

  // Any tap or key unlocks audio (browsers require a gesture)
  ['pointerdown', 'keydown', 'touchend'].forEach(function (type) {
    window.addEventListener(type, function () { if (ctx && ctx.state !== 'running' && started !== null) ctx.resume(); }, true);
  });

  window.sonotAudio = api;
})();
