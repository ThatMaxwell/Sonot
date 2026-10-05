/* ==========================================================================
   SONOT — "Ignition" (launch film soundtrack)
   Uplifting cinematic electronic, synthesized live with WebAudio.
   128 BPM, D major (I–V–vi–IV). 24 bars = 45s:
     0-3   VOID    warm drone, soft heartbeat, a glass note for every spark
     4-7   RISE    pulse arpeggio climbs, kick fades in, filter opens, a breath
     8-14  REVEAL  half-time anthem: lush chords, bell hook, deep soft hits
     15-16 LIGHT   breakdown: felt keys and air
     17-21 FLIGHT  the full beat lifts it, hook an octave up
     22-23 ARRIVAL one big open D major chord and bells
   Built to hype, not to hurt: no distortion, no strobing noise.
   The film reads its clock from here, so every moment lands on the beat.
   ========================================================================== */
(function () {
  'use strict';

  var BPM = 128, BEAT = 60 / BPM, STEP = BEAT / 4, BAR = BEAT * 4, BARS = 24;
  var LENGTH = BARS * BAR;

  // D – A – Bm – G  (I–V–vi–IV: the uplifting one)
  var CHORDS = [
    { bass: 38, notes: [62, 66, 69, 74] },
    { bass: 33, notes: [61, 64, 69, 73] },
    { bass: 35, notes: [62, 66, 71, 74] },
    { bass: 31, notes: [62, 67, 71, 74] }
  ];
  var HOOK = [
    [74, null, 73, 74, 76, null, 74, null],
    [73, null, 69, null, 71, 73, null, null],
    [74, null, 71, null, 78, null, 76, 74],
    [74, null, 71, null, 69, null, null, null]
  ];
  var GLASS = [86, 88, 90, 93, 95, 98];

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

  var ctx = null, master, comp, music, duck, verb, verbIn, delayIn, noise, filt;
  var t0 = 0, step = 0, timer = null, started = false, muted = false;

  function hz(m) { return 440 * Math.pow(2, (m - 69) / 12); }

  function build() {
    if (ctx) return true;
    var AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return false;
    ctx = new AC({ latencyHint: 'interactive' });

    comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -16; comp.knee.value = 10; comp.ratio.value = 3; comp.attack.value = .005; comp.release.value = .2;
    master = ctx.createGain(); master.gain.value = 0;
    master.connect(comp); comp.connect(ctx.destination);

    // sidechain bus (pumps with the kick) → master filter (opens during the build)
    duck = ctx.createGain();
    filt = ctx.createBiquadFilter(); filt.type = 'lowpass'; filt.frequency.value = 20000; filt.Q.value = .8;
    duck.connect(filt); filt.connect(master);
    music = ctx.createGain(); music.connect(duck);

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
    o.frequency.setValueAtTime(140, t); o.frequency.exponentialRampToValueAtTime(48, t + .12);
    g.gain.setValueAtTime(v, t); g.gain.setValueAtTime(v, t + .04); g.gain.exponentialRampToValueAtTime(.001, t + .48);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + .5);
    var cf = ctx.createBiquadFilter(), cg = ctx.createGain(); cf.type = 'highpass'; cf.frequency.value = 2500;
    cg.gain.setValueAtTime(v * .08, t); cg.gain.exponentialRampToValueAtTime(.001, t + .015);
    cf.connect(cg); cg.connect(master); noiseSrc(t, t + .03, cf);
    if (pump !== false) { duck.gain.setValueAtTime(.55, t); duck.gain.linearRampToValueAtTime(1, t + BEAT * .6); }
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
    osc('sine', hz(26), t, t + dur, g); osc('sawtooth', hz(38), t, t + dur, f, -6); osc('sawtooth', hz(45), t, t + dur, f, 7);
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
  function lead(t, m, dur, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.Q.value = 3;
    f.frequency.setValueAtTime(6000, t); f.frequency.exponentialRampToValueAtTime(1700, t + dur);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .006); g.gain.setValueAtTime(v * .8, t + dur * .7); g.gain.exponentialRampToValueAtTime(.001, t + dur + .08);
    f.connect(g); send(g, .3, null, .4);
    osc('square', hz(m), t, t + dur + .1, f); var g2 = ctx.createGain(); g2.gain.value = .35; g2.connect(f); osc('sawtooth', hz(m + 12), t, t + dur + .1, g2, 6);
  }

  function bell(t, m, v) { // soft FM-ish bell for the hook
    var g = ctx.createGain(), g2 = ctx.createGain();
    env(g, t, .004, v, .02, 1.1); env(g2, t, .004, v * .25, .01, .35);
    osc('sine', hz(m), t, t + 1.3, g); osc('triangle', hz(m + 12), t, t + .5, g2);
    g2.connect(g); send(g, .45, null, .35);
  }
  function warmBass(t, m, dur, v) {
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.frequency.value = 420;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .05); g.gain.setValueAtTime(v, t + dur - .08); g.gain.linearRampToValueAtTime(0, t + dur);
    f.connect(g); g.connect(music);
    osc('sine', hz(m), t, t + dur, g); osc('triangle', hz(m + 12), t, t + dur, f);
  }
  function softBoom(t, v) { // a deep, round hit instead of a blast
    var o = ctx.createOscillator(), g = ctx.createGain();
    o.frequency.setValueAtTime(70, t); o.frequency.exponentialRampToValueAtTime(32, t + 1.2);
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .02); g.gain.exponentialRampToValueAtTime(.001, t + 1.8);
    o.connect(g); g.connect(master); o.start(t); o.stop(t + 1.9);
    var f = ctx.createBiquadFilter(), ng = ctx.createGain(); f.type = 'lowpass'; f.frequency.setValueAtTime(2500, t); f.frequency.exponentialRampToValueAtTime(200, t + 1.5);
    ng.gain.setValueAtTime(v * .12, t); ng.gain.exponentialRampToValueAtTime(.001, t + 1.6);
    f.connect(ng); var w = ctx.createGain(); w.gain.value = 1; ng.connect(w); w.connect(verbIn);
    noiseSrc(t, t + 1.7, f, true);
  }
  function anthem(t, notes, dur, v, cut) { // the big lush chord
    var f = ctx.createBiquadFilter(), g = ctx.createGain(); f.type = 'lowpass'; f.Q.value = .5;
    if (Array.isArray(cut)) { f.frequency.setValueAtTime(cut[0], t); f.frequency.exponentialRampToValueAtTime(cut[1], t + dur); } else f.frequency.value = cut || 3200;
    g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(v, t + .25); g.gain.setValueAtTime(v, t + dur - .15); g.gain.linearRampToValueAtTime(0, t + dur + .5);
    f.connect(g); send(g, .5);
    notes.forEach(function (m) { [-11, -4, 4, 11].forEach(function (c) { osc('sawtooth', hz(m), t, t + dur + .6, f, c); }); });
  }

  /* ---------------- arrangement: one call per 16th step ---------------- */
  function play(n, t) {
    var bar = Math.floor(n / 16), s = n % 16, ch = CHORDS[bar % 4];
    var reveal = bar >= 8 && bar < 15, flight = bar >= 17 && bar < 22;

    // VOID — warm, quiet, waiting
    if (bar < 4) {
      if (n === 0) drone(t, BAR * 4, .05);
      if (s % 8 === 0 && bar >= 1) heartbeat(t, .1 + bar * .03);
      for (var k = 0; k < SPARKS.length; k++) if (Math.abs(SPARKS[k] - n * STEP) < 1e-6) glass(t, GLASS[k % 6], .032);
      if (bar === 2 && s === 0) pad(t, CHORDS[0].notes, BAR * 2, .022, 1000);
      if (bar === 3 && s === 0) swell(t, BAR, .07);
    }

    // RISE — the arpeggio climbs, the kick comes in, the filter opens
    if (bar >= 4 && bar < 8) {
      var b = bar - 4;
      if (n === 64) { filt.frequency.setValueAtTime(500, t); filt.frequency.exponentialRampToValueAtTime(14000, t + BAR * 3.7); }
      if (s === 0) anthem(t, ch.notes, BAR, .018 + b * .006, [800 + b * 450, 1400 + b * 800]);
      if (s === 0) warmBass(t, ch.bass, BAR, .08 + b * .025);
      var rate = bar < 6 ? 2 : 1; // 8ths, then 16ths
      if (s % rate === 0) pluck(t, ch.notes[[0, 1, 2, 3, 2, 1][(s / rate) % 6]] + 12, .026 + b * .007, .35, .25);
      if (bar >= 5 && s % 4 === 0 && !(bar === 7 && s >= 12)) kick(t, .26 + (bar - 5) * .09);
      if (bar >= 6 && s % 4 === 2) hat(t, .025);
      if (bar === 6 && s === 0) riser(t, BAR * 2 - BEAT, .1);
      if (bar === 7 && s === 12) swell(t, BEAT, .12);
    }

    // REVEAL — half-time anthem
    if (reveal) {
      if (bar === 8 && s === 0) { softBoom(t, .55); filt.frequency.setValueAtTime(20000, t); }
      var four = bar >= 12; // the talents section lifts to four-on-the-floor
      if (four ? s % 4 === 0 : (s === 0 || s === 10)) kick(t, four ? .55 : .6);
      if (four ? (s === 4 || s === 12) : s === 8) clap(t, .2);
      if (s % 2 === 0) hat(t, s % 4 === 2 ? .03 : .015);
      if (s === 0) { anthem(t, ch.notes, BAR, .05, 3800); warmBass(t, ch.bass, BAR, .22); }
      if (s % 2 === 0) { var note = HOOK[bar % 4][s / 2]; if (note) bell(t, note + (four ? 12 : 0), .05); }
      if (four) pluck(t, ch.notes[[0, 2, 1, 3][s % 4]] + 24, .018, .3, .2);
    }

    // LIGHT — breakdown
    if (bar === 15 || bar === 16) {
      if (s === 0) { pad(t, ch.notes, BAR, .05, 2200); warmBass(t, ch.bass, BAR, .1); }
      if (s % 2 === 0) { var kn = HOOK[bar % 4][s / 2]; if (kn) keys(t, kn, .07); }
      if (bar === 16 && s === 0) riser(t, BAR - BEAT * .5, .1);
      if (bar === 16 && s >= 8 && s % 2 === 0) pluck(t, CHORDS[0].notes[(s / 2) % 4] + 12, .02 + (s - 8) * .004, .4, .2);
      if (bar === 16 && s === 12) swell(t, BEAT, .12);
    }

    // FLIGHT — the full beat
    if (flight) {
      if (bar === 17 && s === 0) softBoom(t, .5);
      if (s % 4 === 0) kick(t, .65);
      if (s === 4 || s === 12) clap(t, .24);
      if (s % 4 === 2) hat(t, .04, true); else if (s % 2 === 1) hat(t, .018);
      if (s === 0 && bar % 4 === 1) crash(t, .045);
      if (s === 0) { anthem(t, ch.notes, BAR, .05, 4200); warmBass(t, ch.bass, BAR, .22); }
      if (s % 2 === 0) { var fn = HOOK[bar % 4][s / 2]; if (fn) bell(t, fn + 12, .045); }
      pluck(t, ch.notes[[3, 1, 2, 0][s % 4]] + 12, .022, .25, .15);
    }

    // ARRIVAL — one big open D major
    if (bar === 22 && s === 0) {
      softBoom(t, .6); kick(t, .6, false); crash(t, .05);
      anthem(t, [50, 57, 62, 66, 69, 74, 78], BAR * 1.8, .05, [5000, 1200]);
      pad(t, [38, 50, 57, 62, 66], BAR * 1.9, .06, 1800);
      warmBass(t, 26, BAR * 1.6, .2);
    }
    if (bar === 22 && s % 2 === 0 && s >= 2) bell(t, [86, 90, 93, 98, 93, 90, 86][(s / 2 - 1) % 7], .035);
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
