/* ==========================================================================
   SONOT — three.js backgrounds, mounted into Flutter platform views.
   Scenes:  'bloom'  glossy 3D Sonot flower (hero, on white)
            'galaxy' petal-armed particle galaxy (on black)
            'waves'  undulating particle field (on blue)
   ========================================================================== */
import * as THREE from 'three';
import { filmScene } from './film3d.js';

const scenes = new Map();
let nextId = 1;
const pointer = { x: 0, y: 0, tx: 0, ty: 0 };
window.addEventListener('pointermove', (e) => {
  pointer.tx = (e.clientX / window.innerWidth) * 2 - 1;
  pointer.ty = (e.clientY / window.innerHeight) * 2 - 1;
}, { passive: true });

/* The Sonot petal, traced from the icon (1024 grid → scene units) */
function petalShape() {
  const k = 1 / 100, P = (x, y) => [(x - 512) * k, -(y - 512) * k];
  const s = new THREE.Shape();
  s.moveTo(...P(512, 512));
  s.bezierCurveTo(...P(500, 440), ...P(457, 322), ...P(440, 262));
  const [cx, cy] = P(512, 241);
  s.absarc(cx, cy, .75, Math.atan2(P(440, 262)[1] - cy, P(440, 262)[0] - cx), Math.atan2(P(584, 262)[1] - cy, P(584, 262)[0] - cx), true);
  s.bezierCurveTo(...P(567, 322), ...P(524, 440), ...P(512, 512));
  return s;
}

/* A soft studio environment so glossy materials have something to reflect */
function studioEnv(renderer) {
  const pm = new THREE.PMREMGenerator(renderer);
  const env = new THREE.Scene();
  const box = new THREE.Mesh(new THREE.BoxGeometry(30, 30, 30), new THREE.MeshBasicMaterial({ color: 0xf2f5ff, side: THREE.BackSide }));
  env.add(box);
  const panel = (w, h, color, pos, rot) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, h), new THREE.MeshBasicMaterial({ color, side: THREE.DoubleSide }));
    m.position.set(...pos); if (rot) m.rotation.set(...rot); env.add(m);
  };
  panel(12, 4, 0xffffff, [0, 10, 0], [Math.PI / 2, 0, 0]);
  panel(6, 10, 0xffffff, [-12, 2, 4], [0, Math.PI / 2, 0]);
  panel(6, 10, 0x9fc0ff, [12, 0, -2], [0, -Math.PI / 2, 0]);
  panel(20, 3, 0x0b5cff, [0, -9, -6], [-Math.PI / 3, 0, 0]);
  const tex = pm.fromScene(env, .04).texture;
  pm.dispose();
  return tex;
}

function makeRenderer(el) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.0;
  renderer.setClearColor(0x000000, 0);
  const c = renderer.domElement;
  c.style.width = '100%'; c.style.height = '100%'; c.style.display = 'block';
  el.appendChild(c);
  return renderer;
}

/* ---------------- BLOOM ---------------- */
function bloomScene(renderer) {
  const scene = new THREE.Scene();
  scene.environment = studioEnv(renderer);
  const camera = new THREE.PerspectiveCamera(32, 1, .1, 100);
  camera.position.set(0, 0, 15);

  const geo = new THREE.ExtrudeGeometry(petalShape(), { depth: .34, bevelEnabled: true, bevelThickness: .16, bevelSize: .13, bevelSegments: 8, curveSegments: 36 });
  geo.translate(0, 0, -.17);
  const mat = new THREE.MeshPhysicalMaterial({
    color: 0x0b5cff, metalness: .05, roughness: .16, clearcoat: 1, clearcoatRoughness: .06,
    iridescence: .55, iridescenceIOR: 1.3, sheen: .4, sheenColor: new THREE.Color(0x9fc0ff), envMapIntensity: 1.25
  });
  const glass = new THREE.MeshPhysicalMaterial({
    color: 0x2f74ff, metalness: .05, roughness: .1, clearcoat: 1, clearcoatRoughness: .03,
    iridescence: .8, iridescenceIOR: 1.4, envMapIntensity: 1.4
  });

  const flower = new THREE.Group();
  const petals = [];
  for (let i = 0; i < 8; i++) {
    const pivot = new THREE.Group();
    pivot.rotation.z = -i * Math.PI / 4;
    const mesh = new THREE.Mesh(geo, i % 2 ? glass : mat);
    pivot.add(mesh);
    flower.add(pivot);
    petals.push({ pivot, mesh, phase: i * .7 });
  }
  const core = new THREE.Mesh(new THREE.SphereGeometry(.34, 48, 48), new THREE.MeshPhysicalMaterial({ color: 0xffffff, roughness: .1, clearcoat: 1, envMapIntensity: 1.5 }));
  core.position.z = .3;
  flower.add(core);
  scene.add(flower);

  // Orbiting light motes
  const N = 260, pos = new Float32Array(N * 3), seeds = [];
  for (let i = 0; i < N; i++) seeds.push({ r: 4.5 + Math.random() * 5, a: Math.random() * Math.PI * 2, y: (Math.random() - .5) * 7, s: .1 + Math.random() * .25 });
  const pg = new THREE.BufferGeometry(); pg.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const motes = new THREE.Points(pg, new THREE.PointsMaterial({ color: 0x3b7bff, size: .07, transparent: true, opacity: .7, depthWrite: false }));
  scene.add(motes);

  scene.add(new THREE.HemisphereLight(0xffffff, 0xc7d6ff, .9));
  const key = new THREE.DirectionalLight(0xffffff, 2.2); key.position.set(4, 6, 8); scene.add(key);
  const rim = new THREE.DirectionalLight(0x6ea2ff, 2.4); rim.position.set(-6, -3, -4); scene.add(rim);

  let progress = 0, intro = 0;
  return {
    scene, camera,
    set(p) { progress = p; },
    tick(t, dt) {
      intro = Math.min(1, intro + dt * .55);
      const e = 1 - Math.pow(1 - intro, 4);
      const spread = progress * 3.2;
      petals.forEach((p, i) => {
        const breathe = Math.sin(t * 1.6 + p.phase) * .06;
        p.mesh.position.y = (1 - e) * 4 + breathe + spread;
        p.mesh.rotation.y = Math.sin(t * .8 + p.phase) * .18 + (1 - e) * 2.5 + progress * 1.4;
        p.mesh.scale.setScalar(.25 + .75 * e);
      });
      flower.rotation.z = -t * .12 - (1 - e) * 2;
      flower.rotation.x += ((pointer.y * .35 + .15) - flower.rotation.x) * .05;
      flower.rotation.y += ((pointer.x * .5) - flower.rotation.y) * .05;
      flower.position.y = Math.sin(t * .9) * .15;
      core.scale.setScalar(.6 + .4 * e + Math.sin(t * 3) * .03);
      seeds.forEach((s, i) => {
        s.a += dt * s.s * .5;
        pos[i * 3] = Math.cos(s.a) * s.r; pos[i * 3 + 1] = s.y + Math.sin(t + i) * .2; pos[i * 3 + 2] = Math.sin(s.a) * s.r - 2;
      });
      pg.attributes.position.needsUpdate = true;
    }
  };
}

/* ---------------- GALAXY ---------------- */
function galaxyScene() {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(55, 1, .1, 200);
  camera.position.set(0, 9, 16); camera.lookAt(0, 0, 0);
  const N = 26000, pos = new Float32Array(N * 3), col = new Float32Array(N * 3);
  const inner = new THREE.Color(0xffffff), outer = new THREE.Color(0x0b5cff), deep = new THREE.Color(0x0a1a66);
  for (let i = 0; i < N; i++) {
    const arm = i % 8, r = Math.pow(Math.random(), 1.6) * 11 + .2;
    const a = arm / 8 * Math.PI * 2 + r * .32;
    const spread = Math.pow(Math.random(), 2.5) * (Math.random() < .5 ? 1 : -1) * (.25 + r * .09);
    const spread2 = Math.pow(Math.random(), 2.5) * (Math.random() < .5 ? 1 : -1) * (.25 + r * .09);
    pos[i * 3] = Math.cos(a) * r + spread;
    pos[i * 3 + 1] = (Math.random() - .5) * .5 * Math.exp(-r * .15);
    pos[i * 3 + 2] = Math.sin(a) * r + spread2;
    const c = inner.clone().lerp(outer, Math.min(1, r / 6)).lerp(deep, Math.max(0, (r - 7) / 6));
    col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b;
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({ size: .05, vertexColors: true, transparent: true, opacity: .95, depthWrite: false, blending: THREE.AdditiveBlending, sizeAttenuation: true }));
  scene.add(pts);
  let progress = 0;
  return {
    scene, camera,
    set(p) { progress = p; },
    tick(t) {
      pts.rotation.y = t * .06 + progress * 1.6;
      const z = 16 - progress * 9, y = 9 - progress * 6;
      camera.position.set(pointer.x * 1.5, y + pointer.y * -1, z);
      camera.lookAt(0, 0, 0);
    }
  };
}

/* ---------------- WAVES ---------------- */
function wavesScene() {
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(50, 1, .1, 200);
  camera.position.set(0, 6, 14); camera.lookAt(0, 0, 0);
  const W = 140, D = 70, N = W * D, pos = new Float32Array(N * 3);
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: .06, transparent: true, opacity: .85, depthWrite: false }));
  scene.add(pts);
  let progress = 0;
  return {
    scene, camera,
    set(p) { progress = p; },
    tick(t) {
      let k = 0;
      const mx = pointer.x * 10, mz = pointer.y * 6;
      for (let i = 0; i < W; i++) for (let j = 0; j < D; j++) {
        const x = (i - W / 2) * .28, z = (j - D / 2) * .28;
        const d = Math.hypot(x - mx, z - mz);
        pos[k++] = x;
        pos[k++] = Math.sin(x * .35 + t * 1.1) * .55 + Math.cos(z * .45 + t * .8) * .45 + Math.sin(d * 1.2 - t * 3) * .35 * Math.exp(-d * .18);
        pos[k++] = z;
      }
      g.attributes.position.needsUpdate = true;
      pts.rotation.y = progress * .5;
      camera.position.y = 6 - progress * 2;
      camera.lookAt(0, 0, 0);
    }
  };
}

const KINDS = { bloom: bloomScene, galaxy: galaxyScene, waves: wavesScene, film: filmScene };

function mount(el, kind) {
  const id = nextId++;
  const renderer = makeRenderer(el);
  const s = KINDS[kind](renderer);
  const entry = { el, renderer, s, visible: true, t: 0, last: performance.now(), raf: 0 };
  const resize = () => {
    const w = el.clientWidth || 1, h = el.clientHeight || 1;
    renderer.setSize(w, h, false);
    s.camera.aspect = w / h;
    if (kind === 'bloom') s.camera.position.z = w / h < 1 ? 22 : 15;
    s.camera.updateProjectionMatrix();
    if (s.resize) s.resize(w, h);
  };
  entry.ro = new ResizeObserver(resize); entry.ro.observe(el); resize();
  entry.io = new IntersectionObserver((en) => { entry.visible = en[0].isIntersecting; }, { rootMargin: '100px' });
  entry.io.observe(el);
  const loop = (now) => {
    entry.raf = requestAnimationFrame(loop);
    const dt = Math.min(.05, (now - entry.last) / 1000); entry.last = now;
    if ((!entry.visible && kind !== 'film') || document.hidden) return;
    entry.t += dt;
    pointer.x += (pointer.tx - pointer.x) * .06; pointer.y += (pointer.ty - pointer.y) * .06;
    s.tick(entry.t, dt);
    if (s.render) s.render(); else renderer.render(s.scene, s.camera);
  };
  entry.raf = requestAnimationFrame(loop);
  scenes.set(id, entry);
  return id;
}

window.sonot3dImpl = {
  mount,
  setProgress(id, p) { const e = scenes.get(id); if (e) e.s.set(p); },
  dispose(id) {
    const e = scenes.get(id); if (!e) return;
    cancelAnimationFrame(e.raf); e.ro.disconnect(); e.io.disconnect();
    e.renderer.dispose(); e.renderer.domElement.remove(); scenes.delete(id);
  }
};
window.dispatchEvent(new Event('sonot3d-ready'));
