/* ==========================================================================
   SONOT — "Ignition" (launch film soundtrack)
   Hybrid trailer × EDM, synthesized live with WebAudio. 128 BPM, F minor.
   24 bars = 45s:
     0-3   VOID    sub drone, heartbeat, a glass pluck for every spark
     4-7   SWARM   four-on-the-floor build, filter opens, snare roll, silence
     8-14  DROP    BRAAAM + reese bass, supersaw stabs, the hook
     15-16 LIGHT   breakdown: felt keys, air, riser
     17-21 WARP    second drop, wobble bass, double-time hats
     22-23 ARRIVAL last BRAAAM, resolves to F MAJOR (minor → light)
   The film reads its clock from here, so every hit lands on the beat.
   ========================================================================== */
(function () {
  'use strict';

  var BPM = 128, BEAT = 60 / BPM, STEP = BEAT / 4, BAR = BEAT * 4, BARS = 24;
  var LENGTH = BARS * BAR;

  // Fm – Eb – Db – C  (the C major is the cinematic tension chord)
  var CHORDS = [
    { bass: 41, notes: [65, 68, 72, 77] },
    { bass: 39, notes: [63, 67, 70, 75] },
    { bass: 37, notes: [61, 65, 68, 73] },
    { bass: 36, notes: [60, 64, 67, 72] }
  ];
  var HOOK = [
    [72, null, 68, null, 72, null, 77, 75],
    [75, null, 70, 67, 70, null, null, null],
    [77, null, 73, null, 68, null, 65, 68],
    [67, null, 64, null, 67, null, 72, null]
  ];

  // Every spark in the opening gets its own glass note (and its own flash on screen)
  var SPARKS = (function () {
    var out = [], seed = 5;
    function r() { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }
    for (var s = 2; s < 64; s++) { // 16th steps across bars 0-3
      var density = .08 + (s / 64) * .55;
      if (r() < density) out.push(s * STEP);
    }
    return out;
  })();

  var ctx = null, master, comp, music, duck, verb, verbIn, delayIn, noise, drive, filt;
  var t0 = 0, step = 0, timer = null, started = false, muted = false;

  function hz(m) { return 440 * Math.pow(2, (m - 69) / 12); }

  function build() {
    if (ctx) return true;
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    ctx = new AC({ latencyHint: 'interactive' });

    comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -9; comp.knee.value = 6; comp.ratio.value = 8; comp.attack.value = .002; comp.release.value = .1;
    master = ctx.createGain(); master.gain.value = 0;
    master.connect(comp); comp.connect(ctx.destination);

    // sidechain bus (pumps with the kick) → master filter (opens during the build)
    duck = ctx.createGain();
    filt = ctx.createBiquadFilter(); filt.type = 'lowpass'; filt.frequency.value = 20000; filt.Q.value = .8;
    duck.connect(filt); filt.connect(master);
    music = ctx.createGain(); music.connect(duck);

    // soft-clip drive for bass + horns
    drive = ctx.createWaveShaper();
    var curve = new Float32Array(1024);
    for (var i = 0; i < 1024; i++) { var x = i / 512 - 1; curve[i] = Math.tanh(x * 2.6); }
    drive.curve = curve; drive.oversample = '2x';
    drive.connect(duck);

    // big hall reverb
    var len = ctx.sampleRate * 3.4, ir = ctx.createBuffer(2, len, ctx.sampleRate);
    for (var c = 0; c < 2; c++) {
      var d = ir.getChannelData(c);
      for (var j = 0; j < len; j++) d[j] = (Math.random() * 2 - 1) * Math.pow(1 - j / len, 2.8);
    }
    verb = ctx.createConvolver(); verb.buffer = ir;
    verbIn = ctx.createGain(); verbIn.gain.value = .55;
    verbIn.connect(verb); verb.connect(filt);

    // dotted-8th delay
    var dl = ctx.createDelay(1); dl.delayTime.value = BEAT * .75;
    var fb = ctx.createGain(); fb.gain.value = .36;
    var dlf = ctx.createBiquadFilter(); dlf.type = 'lowpass'; dlf.frequency.value = 3400;
    delayIn = ctx.createGain(); delayIn.gain.value = .3;
    delayIn.connect(dl); dl.connect(dlf); dlf.connect(fb); fb.connect(dl); dlf.connect(music);

    var nb = ctx.createBuffer(1, ctx.sampleRate * 2, ctx.sampleRate), nd = nb.getChannelData(0);
    for (var k = 0; k < nd.length; k++) nd[k] = Math.random() * 2 - 1;
    noise = nb;
    return true;
  }

  function send(node, wet, dry, dly) {
    node.connect(dry || music);
    if (wet) { var g = ctx.createGain(); g.gain.value = wet; node.connect(g); g.connect(verbIn); }
    if (dly) { var g2 = ctx.createGain(); g2.gain.value = dly; node.connect(g2); g2.connect(delayIn); }
  }
  function env(g, t, a, peak, hold, rel) {
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(peak, t + a);
    g.gain.setValueAtTime(peak, t + a + hold); g.gain.exponentialRampToValueAtTime(.0008, t + a + hold + rel);
  }
  function osc(type, f, t, end, dest, detune) {
    var o = ctx.createOscillator(); o.type = type; o.frequency.value = f; if (detune) o.detune.value = detune;
    o.connect(dest); o.start(t); o.stop(end); return o;
  }
  function noiseSrc(t, end, dest, loop) {
    var s = ctx.createBufferSource(); s.buffer = noise; s.loop = !!loop; s.connect(dest);
    s.start(t, loop ? 0 : Math.random()); s.stop(end); return s;
  }

  /* ---------------- instruments ---------------- */
  function kick(t, v, pump) {
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(180, t); o.frequency.exponentialRampToValueAtTime(46, t + .1);
    g.gain.setValueAtTime(v, t); g.gain.setValueAtTime(v, t + .04); g.gain.exponentialRampToValueAtTime(.001, t + .48);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + .5);
    var cf = ctx.createBiquadFilter(), cg = ctx.createGain(); cf.type = 'highpass'; cf.frequency.value = 2500;
    cg.gain.setValueAtTime(v * .3, t); cg.gain.exponentialRampToValueAtTime(.001, t + .02);
    cf.connect(cg); cg.connect(master); noiseSrc(t, t + .03, cf);
    if (pump !== false) { duck.gain.setValueAtTime(.12, t); duck.gain.linearRampToValueAtTime(1, t + BEAT * .7); }
  }
  function heartbeat(t, v) {
    [0, .17].forEach(function (o, i) {
      var os = ctx.createOscillator(), g = ctx.createGain();
      os.frequency.setValueAtTime(70, t + o); os.frequency.exponentialRampToValueAtTime(38, t + o + .12);
      g.gain.setValueAtTime(v * (i ? .6 : 1), t + o); g.gain.exponentialRampToValueAtTime(.001, t + o + .3);
      os.connect(g); g.connect(master); os.start(t + o); os.stop(t + o + .32);
    });
  }
  function clap(t, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'bandpass'; f.frequency.value = 1500; f.Q.value = .8;
    g.gain.setValueAtTime(0, t);
    [0, .011, .023].forEach(function (o) { g.gain.setValueAtTime(v, t + o); g.gain.exponentialRampToValueAtTime(v * .25, t + o + .009); });
    g.gain.setValueAtTime(v, t + .034); g.gain.exponentialRampToValueAtTime(.001, t + .25);
    f.connect(g); g.connect(master); var w = ctx.createGain(); w.gain.value = .4; g.connect(w); w.connect(verbIn);
    noiseSrc(t, t + .27, f);
  }
  function hat(t, v, open) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'highpass'; f.frequency.value = open ? 7200 : 9500;
    var d = open ? .2 : .035;
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + d);
    f.connect(g); g.connect(master); noiseSrc(t, t + d + .02, f);
  }
  function snare(t, v, tone) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'bandpass'; f.frequency.value = tone || 2000; f.Q.value = .6;
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + .13);
    f.connect(g); g.connect(master); noiseSrc(t, t + .15, f);
    var o = ctx.createOscillator(), og = ctx.createGain(); o.frequency.value = 190;
    og.gain.setValueAtTime(v * .5, t); og.gain.exponentialRampToValueAtTime(.001, t + .08);
    o.connect(og); og.connect(master); o.start(t); o.stop(t + .1);
  }
  function crash(t, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'highpass'; f.frequency.value = 5000;
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + 2.2);
    f.connect(g); g.connect(master); var w = ctx.createGain(); w.gain.value = .5; g.connect(w); w.connect(verbIn);
    noiseSrc(t, t + 2.3, f, true);
  }
  // the trailer horn
  function braaam(t, root, dur, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.Q.value = 4;
    f.frequency.setValueAtTime(120, t); f.frequency.exponentialRampToValueAtTime(1400, t + .18); f.frequency.exponentialRampToValueAtTime(260, t + dur);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .05); g.gain.setValueAtTime(v, t + dur * .55); g.gain.exponentialRampToValueAtTime(.001, t + dur);
    f.connect(g); g.connect(drive); var w = ctx.createGain(); w.gain.value = .8; g.connect(w); w.connect(verbIn);
    [root - 12, root, root + 7, root + 12].forEach(function (m, i) {
      [-9, 9].forEach(function (c) { osc('sawtooth', hz(m), t, t + dur + .05, f, c + i * 2); });
    });
    var s = ctx.createOscillator(), sg = ctx.createGain(); s.frequency.setValueAtTime(hz(root - 12), t);
    sg.gain.setValueAtTime(v * .9, t); sg.gain.exponentialRampToValueAtTime(.001, t + dur);
    s.connect(sg); sg.connect(master); s.start(t); s.stop(t + dur + .05);
  }
  function impact(t, v) {
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(95, t); o.frequency.exponentialRampToValueAtTime(28, t + 1.6);
    g.gain.setValueAtTime(v, t); g.gain.exponentialRampToValueAtTime(.001, t + 2);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + 2.1);
    var f = ctx.createBiquadFilter(), ng = ctx.createGain(); f.type = 'lowpass';
    f.frequency.setValueAtTime(10000, t); f.frequency.exponentialRampToValueAtTime(140, t + 1.8);
    ng.gain.setValueAtTime(v * .6, t); ng.gain.exponentialRampToValueAtTime(.001, t + 2);
    f.connect(ng); ng.connect(master); var w = ctx.createGain(); w.gain.value = 1; ng.connect(w); w.connect(verbIn);
    noiseSrc(t, t + 2.1, f, true);
  }
  function swell(t, dur, v) { // reverse-cymbal swoosh into a hit
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'highpass'; f.frequency.setValueAtTime(800, t); f.frequency.exponentialRampToValueAtTime(6000, t + dur);
    g.gain.setValueAtTime(.0005, t); g.gain.exponentialRampToValueAtTime(v, t + dur); g.gain.linearRampToValueAtTime(0, t + dur + .01);
    f.connect(g); g.connect(master); noiseSrc(t, t + dur + .02, f, true);
  }
  function riser(t, dur, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'bandpass'; f.Q.value = 2.2;
    f.frequency.setValueAtTime(220, t); f.frequency.exponentialRampToValueAtTime(9500, t + dur);
    g.gain.setValueAtTime(.0005, t); g.gain.exponentialRampToValueAtTime(v, t + dur); g.gain.linearRampToValueAtTime(0, t + dur + .02);
    f.connect(g); g.connect(master); var w = ctx.createGain(); w.gain.value = .4; g.connect(w); w.connect(verbIn);
    noiseSrc(t, t + dur + .05, f, true);
    var o = ctx.createOscillator(), og = ctx.createGain(), of = ctx.createBiquadFilter(); of.type = 'lowpass'; of.frequency.value = 3200;
    o.type = 'sawtooth'; o.frequency.setValueAtTime(110, t); o.frequency.exponentialRampToValueAtTime(1760, t + dur);
    og.gain.setValueAtTime(.0005, t); og.gain.exponentialRampToValueAtTime(v * .22, t + dur); og.gain.linearRampToValueAtTime(0, t + dur + .02);
    o.connect(of); of.connect(og); og.connect(master); o.start(t); o.stop(t + dur + .05);
  }
  function drone(t, dur, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.frequency.setValueAtTime(200, t); f.frequency.linearRampToValueAtTime(700, t + dur);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + 2); g.gain.setValueAtTime(v, t + dur - .4); g.gain.linearRampToValueAtTime(0, t + dur);
    f.connect(g); g.connect(master); var w = ctx.createGain(); w.gain.value = .5; g.connect(w); w.connect(verbIn);
    osc('sine', hz(29), t, t + dur, g); osc('sawtooth', hz(41), t, t + dur, f, -6); osc('sawtooth', hz(48), t, t + dur, f, 7);
  }
  function glass(t, m, v) {
    var g = ctx.createGain(), g2 = ctx.createGain();
    env(g, t, .003, v, .01, .9); env(g2, t, .003, v * .4, .01, .4);
    osc('sine', hz(m), t, t + 1, g); osc('sine', hz(m) * 2.76, t, t + .5, g2);
    g2.connect(g); send(g, .7, null, .35);
  }
  function pluck(t, m, v, wet, dly) {
    var g = ctx.createGain(), f = ctx.createBiquadFilter(); f.type = 'lowpass';
    f.frequency.setValueAtTime(5200, t); f.frequency.exponentialRampToValueAtTime(650, t + .25);
    env(g, t, .004, v, 0, .35); f.connect(g); send(g, wet || .3, null, dly || .25);
    osc('triangle', hz(m), t, t + .45, f); osc('sawtooth', hz(m), t, t + .45, f, 8);
  }
  function keys(t, m, v) { // felt-piano-ish
    var g = ctx.createGain(), f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 2200;
    env(g, t, .008, v, .05, 1.3); f.connect(g); send(g, .6, null, .3);
    osc('triangle', hz(m), t, t + 1.5, f); osc('sine', hz(m + 12), t, t + 1, f);
  }
  function saw(t, notes, dur, v, cut, rel, wet) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.Q.value = 1.1;
    if (Array.isArray(cut)) { f.frequency.setValueAtTime(cut[0], t); f.frequency.exponentialRampToValueAtTime(cut[1], t + dur); } else f.frequency.value = cut || 5500;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .01);
    g.gain.setValueAtTime(v, t + dur); g.gain.exponentialRampToValueAtTime(.0008, t + dur + (rel || .12));
    f.connect(g); send(g, wet === undefined ? .25 : wet);
    notes.forEach(function (m) { [-15, -6, 0, 7, 16].forEach(function (c) { osc('sawtooth', hz(m), t, t + dur + (rel || .12) + .05, f, c); }); });
  }
  function pad(t, notes, dur, v, cut) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.frequency.value = cut || 1500;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .6); g.gain.setValueAtTime(v, t + dur - .1); g.gain.linearRampToValueAtTime(0, t + dur + .8);
    f.connect(g); send(g, .7);
    notes.forEach(function (m) { [-8, 8].forEach(function (c) { osc('sawtooth', hz(m), t, t + dur + .9, f, c); }); });
  }
  function reese(t, m, dur, v, wobble) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.Q.value = 6; f.frequency.value = 700;
    if (wobble) {
      var lfo = ctx.createOscillator(), lg = ctx.createGain(); lfo.type = 'sine'; lfo.frequency.value = 1 / (BEAT / 2);
      lg.gain.value = 600; lfo.connect(lg); lg.connect(f.frequency); lfo.start(t); lfo.stop(t + dur);
    }
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .01); g.gain.setValueAtTime(v, t + dur - .03); g.gain.linearRampToValueAtTime(0, t + dur);
    f.connect(g); g.connect(drive);
    osc('sawtooth', hz(m), t, t + dur, f, -14); osc('sawtooth', hz(m), t, t + dur, f, 14);
    var s = ctx.createGain(); s.gain.value = .9; s.connect(g); osc('sine', hz(m - 12), t, t + dur, s);
  }
  function lead(t, m, dur, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.Q.value = 3;
    f.frequency.setValueAtTime(6000, t); f.frequency.exponentialRampToValueAtTime(1700, t + dur);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .006); g.gain.setValueAtTime(v * .8, t + dur * .7); g.gain.exponentialRampToValueAtTime(.001, t + dur + .08);
    f.connect(g); send(g, .3, null, .4);
    osc('square', hz(m), t, t + dur + .1, f); var g2 = ctx.createGain(); g2.gain.value = .35; g2.connect(f); osc('sawtooth', hz(m + 12), t, t + dur + .1, g2, 6);
  }

  /* ---------------- arrangement: one call per 16th step ---------------- */
  function play(n, t) {
    var bar = Math.floor(n / 16), s = n % 16, ch = CHORDS[bar % 4];
    var drop1 = bar >= 8 && bar < 15, drop2 = bar >= 17 && bar < 22;

    // VOID
    if (bar < 4) {
      if (n === 0) drone(t, BAR * 4, .16);
      if (s % 8 === 0) heartbeat(t, .38 + bar * .06);
      for (var k = 0; k < SPARKS.length; k++) if (Math.abs(SPARKS[k] - n * STEP) < 1e-6) glass(t, [84, 87, 89, 91, 96, 92][k % 6], .05);
      if (bar === 3 && s === 0) swell(t, BAR, .22);
    }

    // SWARM — the build
    if (bar >= 4 && bar < 8) {
      var b = bar - 4;
      if (n === 64) { filt.frequency.setValueAtTime(380, t); filt.frequency.exponentialRampToValueAtTime(16000, t + BAR * 3.8); }
      if (s % 4 === 0 && !(bar === 7 && s >= 12)) kick(t, .85);
      if (s === 0) pad(t, ch.notes, BAR, .055, 900 + b * 600);
      pluck(t, ch.notes[[0, 2, 1, 3][s % 4]] + 12, .045 + b * .01, .3, .2);
      if (s % 2 === 1) hat(t, .04 + b * .012);
      if (bar >= 6 && (s === 4 || s === 12)) clap(t, .38);
      if (s % 4 === 2) reese(t, ch.bass, STEP * 1.6, .1 + b * .03);
      if (bar === 6 && s === 0) riser(t, BAR * 2 - BEAT, .32);
      if (bar === 7) {
        var on = s < 8 ? s % 2 === 0 : true;
        if (on && s < 12) { snare(t, .14 + s * .022, 1700 + s * 170); if (s >= 8) snare(t + STEP / 2, .16 + s * .022, 1900 + s * 170); }
      }
      if (bar === 7 && s === 12) swell(t, BEAT, .28);
    }

    // DROPS
    if (drop1 || drop2) {
      var first = (bar === 8 || bar === 17) && s === 0;
      if (first) { braaam(t, 41, BAR * 1.1, .34); impact(t, .9); crash(t, .2); filt.frequency.setValueAtTime(20000, t); }
      if (s % 4 === 0) kick(t, 1);
      if (s === 4 || s === 12) clap(t, .5);
      if (s % 4 === 2) hat(t, .1, true); else if (s % 2 === 1) hat(t, .05);
      if (drop2 && s % 2 === 0 && s % 4 !== 0) hat(t, .045);
      if (s === 0 && bar % 2 === 0 && !first) crash(t, .1);
      if (s === 0) reese(t, ch.bass, BAR, .26, drop2);
      if ([0, 3, 6, 10, 12].indexOf(s) >= 0) saw(t, ch.notes, s === 12 ? STEP * 3 : STEP * 1.6, .08, drop2 ? 7000 : 5600, .1, .25);
      if (s % 2 === 0) {
        var note = HOOK[bar % 4][s / 2];
        if (note) lead(t, note + (bar >= 12 && bar < 15 || bar >= 20 ? 12 : 0), STEP * 1.8, .058);
      }
      if (drop2) pluck(t, ch.notes[[3, 1, 2, 0][s % 4]] + 12, .03, .25, .15);
    }
    // LIGHT — breakdown
    if (bar === 15 || bar === 16) {
      if (s === 0) { pad(t, ch.notes, BAR, .07, 2400); if (bar === 15) braaam(t, 41, BAR * .9, .12); }
      if (s % 2 === 0) { var kn = HOOK[bar % 4][s / 2]; if (kn) keys(t, kn, .085); }
      if (bar === 16 && s === 0) riser(t, BAR - BEAT * .5, .34);
      if (bar === 16 && s >= 8 && s < 14) { snare(t, .1 + (s - 8) * .03, 2200 + s * 140); snare(t + STEP / 2, .12 + (s - 8) * .03, 2400 + s * 140); }
      if (bar === 16 && s === 12) swell(t, BEAT, .3);
    }

    // ARRIVAL — F major, the light
    if (bar === 22 && s === 0) {
      braaam(t, 41, BAR * 1.3, .3); impact(t, 1); kick(t, 1, false); crash(t, .22);
      saw(t, [53, 57, 60, 65, 69, 72], BAR * 1.7, .065, [7000, 900], 1.8, .8);
      pad(t, [41, 53, 60, 65, 69], BAR * 1.9, .08, 1800);
      reese(t, 29, BAR * 1.2, .18);
    }
    if (bar === 22 && s % 2 === 0 && s >= 4) glass(t, [81, 84, 89, 93, 89, 84][(s / 2 - 2) % 6], .05);
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
  window.sonotAudio = {
    LENGTH: LENGTH, BPM: BPM, BEAT: BEAT, BAR: BAR, SPARKS: SPARKS,
    unlock: function () { if (!build()) return false; if (ctx.state !== 'running') ctx.resume(); return true; },
    state: function () { return ctx ? ctx.state : 'none'; },
    start: function (from) {
      if (!build()) return false;
      if (ctx.state !== 'running') { ctx.resume(); return false; }
      from = Math.max(0, from || 0);
      t0 = ctx.currentTime - from + .03;
      step = Math.ceil(from / STEP);
      started = true;
      filt.frequency.cancelScheduledValues(ctx.currentTime);
      filt.frequency.setValueAtTime(from >= 4 * BAR && from < 8 * BAR ? 2000 : 20000, ctx.currentTime);
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setValueAtTime(master.gain.value, ctx.currentTime);
      master.gain.linearRampToValueAtTime(muted ? 0 : .9, ctx.currentTime + .08);
      if (timer) clearInterval(timer);
      timer = setInterval(pump, 25);
      pump();
      return true;
    },
    time: function () { return started && ctx && ctx.state === 'running' ? ctx.currentTime - t0 : -1; },
    started: function () { return started; },
    stop: function () {
      if (!ctx) return;
      started = false;
      if (timer) { clearInterval(timer); timer = null; }
      master.gain.cancelScheduledValues(ctx.currentTime);
      master.gain.setValueAtTime(master.gain.value, ctx.currentTime);
      master.gain.linearRampToValueAtTime(0, ctx.currentTime + .8);
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

  ['pointerdown', 'keydown', 'touchend'].forEach(function (type) {
    window.addEventListener(type, function () { if (ctx && ctx.state !== 'running') ctx.resume(); }, true);
  });
})();
