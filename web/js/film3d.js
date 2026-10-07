/* ==========================================================================
   SONOT — "Ignition"  ·  the launch film as ONE continuous particle shot.
   Every scene is the same cloud of light morphing into a new formation,
   locked to the soundtrack (128 BPM, 24 bars = 45s). Flutter feeds the
   film clock in through setProgress(t).
   ========================================================================== */
import * as THREE from 'three';
import { EffectComposer } from './jsm/postprocessing/EffectComposer.js';
import { RenderPass } from './jsm/postprocessing/RenderPass.js';
import { UnrealBloomPass } from './jsm/postprocessing/UnrealBloomPass.js';
import { OutputPass } from './jsm/postprocessing/OutputPass.js';

const BPM = 128, BEAT = 60 / BPM, BAR = BEAT * 4;
const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
const seg = (x, a, b) => clamp((x - a) / (b - a));
const lerp = (a, b, t) => a + (b - a) * t;

const PETAL = 'M 512 512 C 500 440, 457 322, 440 262 A 75 75 0 1 1 584 262 C 567 322, 524 440, 512 512 Z';

const WORDS = {
  en: ['READS', 'REASONS', 'WRITES', 'CODES', 'SEES', 'SPEAKS'],
  pt: ['LÊ', 'RACIOCINA', 'ESCREVE', 'PROGRAMA', 'ENXERGA', 'FALA'],
};

/* ---------------- formations ---------------- */
function rnd(seed) { return () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; }; }

function dustInto(out, i, R, r) {
  const u = r() * 2 - 1, a = r() * Math.PI * 2, rad = R * Math.cbrt(r());
  const s = Math.sqrt(1 - u * u);
  out[i * 3] = Math.cos(a) * s * rad; out[i * 3 + 1] = u * rad * .7; out[i * 3 + 2] = Math.sin(a) * s * rad;
}

/** Draw on a canvas, then scatter N particles over the lit pixels. */
function sample(N, w, h, draw, { scale, share = .86, depth = .5, dust = 16, step = 2, z = null, seed = 1, oy = 0 }) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d', { willReadFrequently: true });
  g.fillStyle = '#fff'; g.strokeStyle = '#fff'; g.lineCap = 'round'; g.lineJoin = 'round';
  draw(g, w, h);
  const d = g.getImageData(0, 0, w, h).data;
  const px = [];
  for (let y = 0; y < h; y += step) for (let x = 0; x < w; x += step) if (d[(y * w + x) * 4 + 3] > 120) px.push(x, y);
  const out = new Float32Array(N * 3), r = rnd(seed);
  for (let i = 0; i < N; i++) {
    if (px.length && r() < share) {
      const k = Math.floor(r() * px.length / 2) * 2;
      const x = (px[k] - w / 2 + r() * step) * scale, y = -(px[k + 1] - h / 2 + r() * step) * scale;
      out[i * 3] = x; out[i * 3 + 1] = y + oy;
      out[i * 3 + 2] = (z ? z(x, y) : 0) + (r() - .5) * depth;
    } else dustInto(out, i, dust, r);
  }
  return out;
}

function petals(g, size, cx, cy) {
  const p = new Path2D(PETAL);
  g.save(); g.translate(cx, cy); g.scale(size / 1024, size / 1024);
  for (let i = 0; i < 8; i++) { g.save(); g.translate(512, 512); g.rotate(i * Math.PI / 4); g.translate(-512, -512); g.fill(p); g.restore(); }
  g.restore();
}

function textForm(N, word, seed) {
  return sample(N, 1800, 440, (g, w, h) => {
    let fs = 300;
    g.font = `800 ${fs}px SonotDisplay, "Inter Tight", system-ui, sans-serif`;
    const mw = g.measureText(word).width;
    if (mw > w * .92) fs = fs * (w * .92) / mw;
    g.font = `800 ${fs}px SonotDisplay, "Inter Tight", system-ui, sans-serif`;
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(word, w / 2, h / 2 + fs * .04);
  }, { scale: 22 / 1800, share: .9, depth: .7, dust: 20, seed });
}

function buildForms(N, lang) {
  const F = {}, r = rnd(7);
  // far starfield
  F.void = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) {
    const u = r() * 2 - 1, a = r() * Math.PI * 2, rad = 40 + r() * 50, s = Math.sqrt(1 - u * u);
    F.void[i * 3] = Math.cos(a) * s * rad; F.void[i * 3 + 1] = u * rad; F.void[i * 3 + 2] = Math.sin(a) * s * rad - 30;
  }
  // a nebula of sparks
  F.sparks = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) {
    const u = r() * 2 - 1, a = r() * Math.PI * 2, rad = 2.5 + Math.pow(r(), .7) * 15, s = Math.sqrt(1 - u * u);
    F.sparks[i * 3] = Math.cos(a) * s * rad * 1.6; F.sparks[i * 3 + 1] = u * rad * .8; F.sparks[i * 3 + 2] = Math.sin(a) * s * rad;
  }
  // 8-armed vortex (the petals, as a galaxy)
  F.vortex = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) {
    const rr = .3 + Math.pow(r(), .65) * 15, arm = i % 8;
    const ang = arm / 8 * Math.PI * 2 + rr * .42 + (r() - .5) * (.5 + rr * .02);
    F.vortex[i * 3] = Math.cos(ang) * rr; F.vortex[i * 3 + 1] = (r() - .5) * (.25 + rr * .05); F.vortex[i * 3 + 2] = Math.sin(ang) * rr;
  }
  // singularity
  F.point = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) dustInto(F.point, i, .12, r);
  // the bloom, cupped like a flower
  F.bloom = sample(N, 900, 900, (g, w) => petals(g, w, 0, 0), {
    scale: 15 / 900, share: .93, depth: .35, dust: 22, seed: 3,
    z: (x, y) => .05 * (x * x + y * y) - 1.2,
  });
  F.sonot = textForm(N, 'SONOT', 11);
  F.words = WORDS[lang].map((w, k) => textForm(N, w, 20 + k));
  // laptop + phone outlines with a bloom on screen
  F.laptop = sample(N, 1000, 700, (g) => {
    g.lineWidth = 14;
    g.beginPath(); g.roundRect(170, 90, 660, 430, 26); g.stroke();
    g.beginPath(); g.moveTo(90, 560); g.lineTo(910, 560); g.stroke();
    g.beginPath(); g.moveTo(140, 520); g.lineTo(90, 560); g.moveTo(860, 520); g.lineTo(910, 560); g.stroke();
    petals(g, 230, 385, 190);
  }, { scale: 16 / 1000, share: .9, depth: .4, dust: 20, seed: 4, oy: -1.2 });
  F.phone = sample(N, 700, 1000, (g) => {
    g.lineWidth = 14;
    g.beginPath(); g.roundRect(200, 80, 300, 640, 54); g.stroke();
    g.beginPath(); g.roundRect(305, 112, 90, 22, 11); g.fill();
    petals(g, 230, 235, 280);
  }, { scale: 13 / 1000, share: .9, depth: .4, dust: 20, seed: 5, oy: -1.4 });
  // warp tunnel
  F.tunnel = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) {
    const a = r() * Math.PI * 2, rad = 6.5 + Math.pow(r(), .6) * 10;
    F.tunnel[i * 3] = Math.cos(a) * rad; F.tunnel[i * 3 + 1] = Math.sin(a) * rad; F.tunnel[i * 3 + 2] = r() * 100 - 90;
  }
  // the app icon
  F.icon = sample(N, 900, 900, (g) => {
    g.lineWidth = 26;
    g.beginPath(); g.roundRect(70, 70, 760, 760, 200); g.stroke();
    petals(g, 620, 140, 140);
  }, { scale: 13 / 900, share: .94, depth: .3, dust: 18, seed: 6 });
  return F;
}

/* ---------------- shaders ---------------- */
const VERT = /* glsl */`
  attribute vec3 aFrom;
  attribute vec3 aTo;
  attribute vec4 aRand;
  uniform float uMix, uTime, uSize, uPulse, uScatter, uReveal, uRatio, uWarp, uTunnel, uFlash, uAlphaK;
  uniform vec3 uColA, uColB, uColC;
  varying vec3 vColor;
  varying float vAlpha;
  void main() {
    float d = aRand.x * .45;
    float m = clamp((uMix - d) / (1. - .45), 0., 1.);
    m = m * m * (3. - 2. * m);
    vec3 p = mix(aFrom, aTo, m);
    float mid = sin(m * 3.14159);
    p += (aRand.yzw - .5) * mid * uScatter;
    // tunnel: stream toward the camera forever
    float tz = mod(p.z + uWarp + 90., 100.) - 90.;
    p.z = mix(p.z, tz, uTunnel);
    p += vec3(sin(uTime * 1.3 + aRand.y * 40.), cos(uTime * 1.1 + aRand.z * 40.), sin(uTime * .9 + aRand.w * 40.)) * .03;
    p *= 1. + uPulse * .012 * (.4 + aRand.x);
    vec4 mv = modelViewMatrix * vec4(p, 1.);
    gl_Position = projectionMatrix * mv;
    float s = uSize * (.45 + aRand.w * 1.1) * (1. + uPulse * .16 + uFlash * .5);
    gl_PointSize = clamp(s * uRatio * (14. / -mv.z), 0., 16. * uRatio);
    float pick = aRand.y;
    vColor = pick < .55 ? uColA : (pick < .85 ? uColB : uColC);
    vAlpha = min(1., step(aRand.z, uReveal) * (.55 + aRand.x * .45) * uAlphaK);
    vAlpha *= mix(1., smoothstep(-90., -45., p.z), uTunnel);
  }`;
const FRAG = /* glsl */`
  varying vec3 vColor;
  varying float vAlpha;
  uniform float uOpacity, uSoft;
  void main() {
    float r = length(gl_PointCoord - .5);
    float a = smoothstep(.5, .0, r);
    a = mix(smoothstep(.5, .3, r), a * a, uSoft);
    if (a * vAlpha < .01) discard;
    gl_FragColor = vec4(vColor, a * vAlpha * uOpacity);
  }`;

/* ---------------- timeline (in bars) ---------------- */
// form, morph duration (s), mid-flight scatter, morph easing power
const SHOTS = [
  { at: 0, form: 'void', dur: .1, scatter: 0 },
  { at: .25, form: 'sparks', dur: 7.2, scatter: 4 },
  { at: 4, form: 'vortex', dur: 3.6, scatter: 3 },
  { at: 7, form: 'point', dur: 1.75, scatter: 0, pow: 3 },
  { at: 8, form: 'bloom', dur: 1.1, scatter: 14 },
  { at: 9, form: 'sonot', dur: .8, scatter: 6 },
  { at: 10, form: 'bloom', dur: .9, scatter: 8 },
  ...[0, 1, 2, 3, 4, 5].map((k) => ({ at: 12 + k * .5, form: 'w' + k, dur: .42, scatter: 5 })),
  { at: 15, form: 'laptop', dur: 1.1, scatter: 5 },
  { at: 16, form: 'phone', dur: .9, scatter: 4 },
  { at: 17, form: 'tunnel', dur: 1.2, scatter: 10 },
  { at: 22, form: 'icon', dur: 1.4, scatter: 9 },
];

const PALETTE = {
  dark: { bg: new THREE.Color(0x010208), a: new THREE.Color(0xffffff), b: new THREE.Color(0x9cc0ff), c: new THREE.Color(0x3b7bff), bloom: 1.05, size: 1.9, add: true, alpha: 1.3 },
  blue: { bg: new THREE.Color(0x0b5cff), a: new THREE.Color(0xffffff), b: new THREE.Color(0xffffff), c: new THREE.Color(0xdce7ff), bloom: .35, size: 1.25, add: false, alpha: 1.5, soft: .35 },
  white: { bg: new THREE.Color(0xffffff), a: new THREE.Color(0x0b5cff), b: new THREE.Color(0x0029c9), c: new THREE.Color(0x3b7bff), bloom: 0, size: 1.7, add: false, alpha: 1.8, soft: 0 },
  navy: { bg: new THREE.Color(0x01030e), a: new THREE.Color(0xffffff), b: new THREE.Color(0x9cc0ff), c: new THREE.Color(0x3b7bff), bloom: 1.3, size: 1.5, add: true, alpha: 1.5 },
};
function moodAt(tb) {
  if (tb < 8) return 'dark';
  if (tb < 15) return 'blue';
  if (tb < 17) return 'white';
  if (tb < 22) return 'navy';
  return 'white';
}
const drums = (tb) => (tb >= 4 && tb < 7.75) || (tb >= 8 && tb < 15) || (tb >= 17 && tb < 22) || (tb >= 22 && tb < 22.25);

/* ---------------- the scene ---------------- */
export function filmScene(renderer) {
  const mobile = Math.min(window.innerWidth, window.innerHeight) < 700 || !!window.sonotLite;
  const N = mobile ? 16000 : 38000;
  const lang = (() => { try { return localStorage.getItem('sonot.lang') === 'pt' ? 'pt' : 'en'; } catch (e) { return 'en'; } })();

  renderer.toneMapping = THREE.NoToneMapping;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(45, 1, .1, 400);
  camera.position.set(0, 0, 34);

  const geo = new THREE.BufferGeometry();
  const zeros = new Float32Array(N * 3);
  geo.setAttribute('position', new THREE.BufferAttribute(zeros, 3));
  const aFrom = new THREE.BufferAttribute(new Float32Array(N * 3), 3);
  const aTo = new THREE.BufferAttribute(new Float32Array(N * 3), 3);
  const rand = new Float32Array(N * 4); const r = rnd(99);
  for (let i = 0; i < N * 4; i++) rand[i] = r();
  geo.setAttribute('aFrom', aFrom); geo.setAttribute('aTo', aTo);
  geo.setAttribute('aRand', new THREE.BufferAttribute(rand, 4));
  geo.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 500);

  const uniforms = {
    uMix: { value: 0 }, uTime: { value: 0 }, uSize: { value: 1 }, uPulse: { value: 0 }, uScatter: { value: 0 },
    uReveal: { value: 0 }, uRatio: { value: renderer.getPixelRatio() }, uWarp: { value: 0 }, uTunnel: { value: 0 },
    uFlash: { value: 0 }, uOpacity: { value: 1 }, uAlphaK: { value: 1 }, uSoft: { value: 1 },
    uColA: { value: new THREE.Color() }, uColB: { value: new THREE.Color() }, uColC: { value: new THREE.Color() },
  };
  const mat = new THREE.ShaderMaterial({ vertexShader: VERT, fragmentShader: FRAG, uniforms, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
  const cloud = new THREE.Points(geo, mat);
  const group = new THREE.Group(); group.add(cloud); scene.add(group);

  // the first point of light
  const glowTex = (() => {
    const c = document.createElement('canvas'); c.width = c.height = 128;
    const g = c.getContext('2d'); const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(.18, 'rgba(160,195,255,.9)'); gr.addColorStop(.5, 'rgba(11,92,255,.25)'); gr.addColorStop(1, 'rgba(11,92,255,0)');
    g.fillStyle = gr; g.fillRect(0, 0, 128, 128); return new THREE.CanvasTexture(c);
  })();
  const core = new THREE.Sprite(new THREE.SpriteMaterial({ map: glowTex, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }));
  scene.add(core);

  // hyperspace streaks for the warp
  const S = mobile ? 900 : 2200;
  const sPos = new Float32Array(S * 6), sEnd = new Float32Array(S * 2), sCol = new Float32Array(S * 2);
  for (let i = 0; i < S; i++) {
    const a = r() * Math.PI * 2, rad = 2.5 + Math.pow(r(), .7) * 15, z0 = r() * 120 - 100, c = r();
    for (let e = 0; e < 2; e++) {
      sPos[(i * 2 + e) * 3] = Math.cos(a) * rad; sPos[(i * 2 + e) * 3 + 1] = Math.sin(a) * rad; sPos[(i * 2 + e) * 3 + 2] = z0;
      sEnd[i * 2 + e] = e; sCol[i * 2 + e] = c;
    }
  }
  const sGeo = new THREE.BufferGeometry();
  sGeo.setAttribute('position', new THREE.BufferAttribute(sPos, 3));
  sGeo.setAttribute('aEnd', new THREE.BufferAttribute(sEnd, 1));
  sGeo.setAttribute('aCol', new THREE.BufferAttribute(sCol, 1));
  sGeo.boundingSphere = new THREE.Sphere(new THREE.Vector3(), 500);
  const sUni = { uWarp: { value: 0 }, uLen: { value: 3 }, uOpacity: { value: 0 } };
  const streaks = new THREE.LineSegments(sGeo, new THREE.ShaderMaterial({
    uniforms: sUni, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: `attribute float aEnd; attribute float aCol; uniform float uWarp, uLen; varying float vA; varying float vC;
      void main(){ vec3 p = position; p.z = mod(p.z + uWarp + 100., 120.) - 100.; p.z -= (1. - aEnd) * uLen * (.6 + aCol);
        vA = aEnd * smoothstep(-100., -35., p.z); vC = aCol; gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.); }`,
    fragmentShader: `uniform float uOpacity; varying float vA; varying float vC;
      void main(){ vec3 c = mix(vec3(1.), vec3(.43,.64,1.), step(.55, vC)); gl_FragColor = vec4(c, vA * uOpacity); }`,
  }));
  scene.add(streaks);

  // formations (text needs the display font first)
  let F = null;
  const font = new FontFace('SonotDisplay', `url(${new URL('assets/assets/fonts/InterTight-800.ttf', document.baseURI)})`, { weight: '800' });
  font.load().then((f) => document.fonts.add(f)).catch(() => {}).finally(() => {
    F = buildForms(N, lang);
    F.words.forEach((w, k) => { F['w' + k] = w; });
    shot = -1;
  });

  // post: bloom glow
  const composer = new EffectComposer(renderer);
  composer.addPass(new RenderPass(scene, camera));
  const bloom = new UnrealBloomPass(new THREE.Vector2(512, 512), 1, .5, .42);
  composer.addPass(bloom);
  composer.addPass(new OutputPass());

  const sparks = (window.sonotAudio && window.sonotAudio.SPARKS) || [];
  let t = 0, last = -1, shot = -1, warp = 0, spin = 0, shake = 0;
  const bg = new THREE.Color(0x010208), camPos = new THREE.Vector3(0, 0, 34), look = new THREE.Vector3(), camLook = new THREE.Vector3();
  let fovNow = 45, mood = 'dark', bloomNow = 1;

  function setShot(k) {
    shot = k;
    const prev = SHOTS[Math.max(0, k - 1)], cur = SHOTS[k];
    aFrom.array.set(F[k === 0 ? cur.form : prev.form]); aFrom.needsUpdate = true;
    aTo.array.set(F[cur.form]); aTo.needsUpdate = true;
  }

  return {
    scene, camera, mobile,
    set(v) { t = v; },
    resize(w, h) { composer.setSize(w, h); bloom.resolution.set(w / (mobile ? 4 : 2), h / (mobile ? 4 : 2)); },
    render() { composer.render(); },
    tick(_, dt) {
      if (t === last && t > 0) { /* paused: keep idle shimmer */ }
      last = t;
      const tb = t / BAR, bt = t / BEAT;
      uniforms.uTime.value += dt;

      // which shot are we in?
      if (F) {
        let k = 0;
        for (let i = 0; i < SHOTS.length; i++) if (tb >= SHOTS[i].at) k = i;
        if (k !== shot) setShot(k);
        const s = SHOTS[k];
        let m = clamp((t - s.at * BAR) / s.dur);
        if (s.pow) m = Math.pow(m, s.pow);
        uniforms.uMix.value = m;
        uniforms.uScatter.value = s.scatter;
      }

      // kicks + sparks
      const pulse = drums(tb) ? Math.exp(-((t % BEAT) / BEAT) * 5) * .8 : 0;
      uniforms.uPulse.value = pulse;
      let lit = 0, flash = 0;
      for (const st of sparks) { if (st <= t) { lit++; flash = Math.max(flash, Math.exp(-(t - st) * 9)); } }
      const reveal = tb < 4 ? .04 + .55 * (sparks.length ? lit / sparks.length : seg(tb, .25, 4)) + .4 * seg(tb, 2.5, 4) : 1;
      uniforms.uReveal.value = reveal;
      uniforms.uFlash.value = tb < 4 ? flash : 0;

      // mood: background, colors, blending, glow
      const md = moodAt(tb);
      const P = PALETTE[md];
      const fast = md !== mood;
      mood = md;
      bg.lerp(P.bg, fast ? 1 : .2);
      uniforms.uColA.value.copy(P.a); uniforms.uColB.value.copy(P.b); uniforms.uColC.value.copy(P.c);
      uniforms.uSize.value = P.size * (mobile ? 1.15 : 1);
      uniforms.uAlphaK.value = P.alpha || 1; uniforms.uSoft.value = P.soft === undefined ? 1 : P.soft;
      if (mat.blending !== (P.add ? THREE.AdditiveBlending : THREE.NormalBlending)) { mat.blending = P.add ? THREE.AdditiveBlending : THREE.NormalBlending; mat.needsUpdate = true; }
      bloomNow = fast || P.bloom === 0 ? P.bloom : lerp(bloomNow, P.bloom, .15);
      bloom.strength = bloomNow * (1 + pulse * .1);
      bloom.enabled = bloomNow > .02;
      scene.background = bg;

      // tunnel streaming
      const tun = tb >= 17 && tb < 22.2 ? seg(tb, 17, 17.6) * (1 - seg(tb, 22, 22.3)) : 0;
      uniforms.uTunnel.value = tun;
      warp += dt * (40 + pulse * 10) * tun;
      uniforms.uWarp.value = warp;
      sUni.uWarp.value = warp; sUni.uLen.value = 5 + pulse * 2.5; sUni.uOpacity.value = tun * .9;
      streaks.visible = tun > .001;

      // the point of light
      const heart = tb < 4 ? Math.exp(-((t % (BEAT * 2)) / BEAT) * 5) : 0;
      const coreVis = tb < 4 ? seg(tb, 0, .3) * (1 - seg(tb, 3, 4) * .6) : (tb < 8 ? .4 + seg(tb, 7, 8) * 1.6 : 0);
      core.material.opacity = clamp(coreVis);
      core.scale.setScalar((tb < 7 ? 2.2 + heart * 1.4 : 2 + seg(tb, 7, 8) * 7) * (tb >= 8 ? 0 : 1));

      // camera choreography
      let pos, tgt = new THREE.Vector3(0, 0, 0), fov = 45, roll = 0;
      const aspect = camera.aspect, fit = aspect < 1 ? 1.15 / aspect : 1;
      if (tb < 4) { pos = new THREE.Vector3(Math.sin(t * .2) * 2, Math.cos(t * .15) * 1.2, 34 - tb * 2.5); }
      else if (tb < 7) { const v = seg(tb, 4, 7); pos = new THREE.Vector3(Math.sin(t * .3) * 3, lerp(2, 19, v * v), lerp(26, 13, v)); fov = 45 + v * 12; }
      else if (tb < 8) { const v = seg(tb, 7, 8); pos = new THREE.Vector3(0, lerp(19, 2, v), lerp(13, 7, v * v)); fov = 57 - v * 10; }
      else if (tb < 12) { const a = Math.sin((tb - 8) * .7) * .5; pos = new THREE.Vector3(Math.sin(a) * 24 * fit, 2.5, Math.cos(a) * 24 * fit); fov = 46 - pulse * 1; }
      else if (tb < 15) { pos = new THREE.Vector3(Math.sin(t * .4) * 1.5, .5, 26 * fit); fov = 44 - pulse * .6; }
      else if (tb < 17) { pos = new THREE.Vector3(Math.sin(t * .35) * 2, .5, 22 * fit); fov = 44; }
      else if (tb < 22) { pos = new THREE.Vector3(0, 0, 9); tgt = new THREE.Vector3(Math.sin(t * .5) * 2, Math.cos(t * .4) * 1.5, -60); fov = 72 + pulse * 1.5; roll = Math.sin(t * .5) * .22; }
      else { pos = new THREE.Vector3(Math.sin(t * .3) * 1.2, 0, 21 * fit); fov = 44; }
      const cut = (tb >= 8 && tb < 8.06) || (tb >= 17 && tb < 17.04) || (tb >= 22 && tb < 22.04);
      camPos.lerp(pos, cut ? 1 : clamp(dt * 3.2));
      camLook.lerp(tgt, cut ? 1 : clamp(dt * 3.2));
      fovNow = lerp(fovNow, fov, cut ? 1 : clamp(dt * 5));
      shake = 0;
      camera.position.copy(camPos).add(new THREE.Vector3((Math.random() - .5) * shake * .6, (Math.random() - .5) * shake * .6, 0));
      camera.fov = fovNow; camera.updateProjectionMatrix();
      camera.lookAt(camLook);
      camera.rotateZ(roll);

      // formation spin
      if (tb >= 4 && tb < 7.75) spin += dt * lerp(.15, 3.2, Math.pow(seg(tb, 4, 7.6), 2));
      else if (tb >= 8 && tb < 9 || tb >= 10 && tb < 12) spin += dt * .25;
      else if (tb >= 22) spin += dt * .12;
      else spin = lerp(spin, Math.round(spin / (Math.PI * 2)) * Math.PI * 2, .08);
      if (tb >= 4 && tb < 7.75) { group.rotation.set(0, spin, 0); }
      else if ((tb >= 8 && tb < 9) || (tb >= 10 && tb < 12)) { group.rotation.set(0, 0, -spin); }
      else if (tb >= 22) { const v = seg(tb, 22, 23.3); group.rotation.set(0, 0, -1.1 * Math.pow(1 - v, 3)); }
      else group.rotation.set(0, 0, 0);
      uniforms.uOpacity.value = tb >= 23.6 ? 1 - seg(tb, 23.6, 24) : 1;
    }
  };
}
