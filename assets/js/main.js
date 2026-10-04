/* ==========================================================================
   SONOT — site engine: loader → film → site, scroll scenes, interactions
   ========================================================================== */
(function () {
  'use strict';

  var CONFIG = window.SONOT_CONFIG || {};
  var Film = window.SonotFilm;
  var body = document.body;
  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var finePointer = window.matchMedia('(pointer: fine)').matches;

  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function clamp(v, a, b) { return Math.min(b === undefined ? 1 : b, Math.max(a || 0, v)); }
  function seg(p, a, b) { return clamp((p - a) / (b - a)); }
  function ease(x) { return 1 - Math.pow(1 - x, 3); }
  function easeIO(x) { return x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; }
  var I18n = window.SonotI18n;
  function T(k) { return I18n ? I18n.t(k) : ''; }
  if (I18n) I18n.apply(window.__lang || 'en');

  function store(k, v) { try { if (v === undefined) return localStorage.getItem(k); localStorage.setItem(k, v); } catch (e) { return null; } }

  /* ----------------------------------------------------------------------
     1. Draw the logos (petals are shared <use> references)
     ---------------------------------------------------------------------- */
  function petals(cls) {
    var h = '';
    for (var i = 0; i < 8; i++) h += '<g transform="rotate(' + i * 45 + ' 512 512)"><use class="' + (cls || 'pt') + '" href="#petal" style="--i:' + i + '"/></g>';
    return h;
  }
  $$('[data-petals]').forEach(function (g) { g.innerHTML = petals(); });
  $$('svg[data-bloom]').forEach(function (s) { s.innerHTML = '<g fill="currentColor">' + petals() + '</g>'; });
  $$('.fin-petals').forEach(function (g) { g.innerHTML = petals(); });
  $$('svg[data-mx]').forEach(function (s) {
    var h = '';
    for (var i = 0; i < 8; i++) h += '<use href="#mxPetal" transform="rotate(' + i * 45 + ' 627 627)"/>';
    s.innerHTML = '<g fill="#fff">' + h + '</g>';
  });

  /* ----------------------------------------------------------------------
     2. Platform detection + download buttons
     ---------------------------------------------------------------------- */
  var ICONS = {
    mac: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="5" width="16" height="11" rx="1.6"/><path d="M2 19h20"/></svg>',
    win: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M3 5.6l7.4-1.1v7H3zM11.6 4.3L21 3v8.5h-9.4zM3 12.6h7.4v7L3 18.4zM11.6 12.6H21V21l-9.4-1.3z"/></svg>',
    linux: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2.6"/><path d="M7 9.5l3 2.5-3 2.5M12.5 15H17"/></svg>',
    ios: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><rect x="6.5" y="2.5" width="11" height="19" rx="3"/><path d="M10.5 5.6h3"/></svg>',
    android: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M4.8 17a7.2 7.2 0 0 1 14.4 0z"/><path d="M8 10.3L6.4 7.8M16 10.3l1.6-2.5" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/><circle cx="9.4" cy="14" r=".95" fill="#0b2a8a"/><circle cx="14.6" cy="14" r=".95" fill="#0b2a8a"/></svg>'
  };
  var NAMES = { mac: 'macOS', win: 'Windows', linux: 'Linux', ios: 'iPhone', android: 'Android' };

  function detectOS() {
    var ua = navigator.userAgent || '';
    var plat = (navigator.userAgentData && navigator.userAgentData.platform) || navigator.platform || '';
    if (/android/i.test(ua)) return 'android';
    if (/iPhone|iPad|iPod/.test(ua) || (/Mac/.test(plat) && navigator.maxTouchPoints > 1)) return 'ios';
    if (/Win/i.test(plat) || /Windows/.test(ua)) return 'win';
    if (/Mac/i.test(plat) || /Mac OS X/.test(ua)) return 'mac';
    if (/Linux|X11|CrOS/i.test(plat + ua)) return 'linux';
    return 'mac';
  }
  var OS = detectOS();
  var links = CONFIG.downloads || {};

  $$('.pi').forEach(function (el) {
    var k = (el.className.match(/pi-(\w+)/) || [])[1];
    if (ICONS[k]) el.innerHTML = ICONS[k];
  });
  $$('[data-os-glyph]').forEach(function (el) { el.innerHTML = ICONS[OS]; });
  function downloadText() {
    $$('[data-dl-label]').forEach(function (el) { el.textContent = T('downloadFor').replace('{os}', NAMES[OS]); });
    $$('[data-dl-version]').forEach(function (el) { el.textContent = T('version') || CONFIG.version || ''; });
    $$('[data-dl-req]').forEach(function (el) { el.textContent = T('req_' + OS) || (CONFIG.requirements || {})[OS] || ''; });
  }
  downloadText();

  function wireDownload(a, os) {
    var url = links[os];
    if (url) { a.href = url; return; }
    a.addEventListener('click', function (e) {
      e.preventDefault();
      toast(T('soon').replace('{os}', NAMES[os]));
    });
  }
  $$('[data-dl-primary]').forEach(function (a) { wireDownload(a, OS); });
  $$('[data-platform]').forEach(function (a) {
    wireDownload(a, a.dataset.platform);
    if (a.dataset.platform === OS) a.classList.add('detected');
  });

  var toastTimer;
  function toast(msg) {
    var t = $('#toast');
    t.textContent = msg;
    t.classList.add('on');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { t.classList.remove('on'); }, 3200);
  }

  /* ----------------------------------------------------------------------
     3. Loader → launch film → site
     ---------------------------------------------------------------------- */
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  window.scrollTo(0, 0);

  var params = new URLSearchParams(location.search);
  var mode = CONFIG.film || 'first-visit';
  var playFilm = params.has('film') ||
    (!params.has('nofilm') && !reduceMotion && (mode === 'always' || (mode === 'first-visit' && store('sonot.filmSeen') !== '1')));

  function revealSite() {
    body.classList.remove('is-loading');
    body.classList.add('is-ready');
    onScroll();
  }

  (window.__loaderDone || Promise.resolve()).then(function () {
    var loader = $('#loader');
    loader.classList.add('done');
    setTimeout(function () { loader.remove(); }, 900);
    if (playFilm && Film) {
      body.classList.remove('is-loading');
      // Only remember the film once it has finished or been skipped,
      // so a refresh mid-intro plays it again.
      Film.play(function () { store('sonot.filmSeen', '1'); revealSite(); });
    } else {
      revealSite();
    }
  });

  function replay() {
    if (!Film) return;
    window.scrollTo({ top: 0, behavior: 'instant' in document.documentElement.style ? 'instant' : 'auto' });
    body.classList.remove('is-ready');
    Film.play(function () { requestAnimationFrame(revealSite); });
  }
  $('#watchFilm').addEventListener('click', replay);
  $('#replayFilm').addEventListener('click', replay);

  /* ----------------------------------------------------------------------
     4. Scroll-driven scenes
     ---------------------------------------------------------------------- */
  var vh = window.innerHeight;
  var nav = $('#nav'), scrollBar = $('#scrollProgress');
  var hero = $('#hero'), heroInner = $('.hero-inner'), heroMark = $('#heroMark');

  // Manifesto: split into words
  var manifesto = $('[data-words]');
  var words = [];
  function splitManifesto() {
    if (!manifesto) return;
    manifesto.innerHTML = manifesto.textContent.trim().split(/\s+/).map(function (w) {
      var hot = /^(Maxwell|built|criou)/.test(w) ? ' hot' : '';
      return '<span class="w' + hot + '">' + w + '</span>';
    }).join(' ');
    words = $$('.w', manifesto);
  }
  splitManifesto();

  // Desktop showcase
  var screen = $('#screen'), appwin = $('#appwin'), quick = $('#quick'), quickText = $('#quickText');
  var stream = $('[data-stream]');
  var notes = $$('.desk-notes p');

  // Phones
  var phones = { l: $('.ph-l'), c: $('.ph-c'), v: $('.ph-v') };

  // People track
  var people = $('#people'), track = $('#peopleTrack'), peopleBar = $('#peopleBar');
  var pcards = $$('.pcard');
  var trackShift = 0;

  function layout() {
    vh = window.innerHeight;
    if (track && people) {
      trackShift = Math.max(0, track.scrollWidth - window.innerWidth);
      people.style.height = (trackShift + vh * 1.15) + 'px';
    }
  }

  function sectionProgress(el) {
    var r = el.getBoundingClientRect();
    var span = r.height - vh;
    return span <= 0 ? (r.top < 0 ? 1 : 0) : clamp(-r.top / span);
  }

  var lastStep = {};
  function setStep(el, cls, on) {
    if (lastStep[cls] === on) return;
    lastStep[cls] = on;
    el.classList.toggle(cls, on);
  }

  function updateDesk(p) {
    var a = easeIO(seg(p, 0, .15));
    screen.style.transform = 'rotateX(' + ((1 - a) * 34).toFixed(2) + 'deg) translateY(' + ((1 - a) * 70).toFixed(1) + 'px) scale(' + (.76 + a * .24).toFixed(4) + ')';

    screen.classList.toggle('bounce', p > .13 && p < .2);
    var w = ease(seg(p, .16, .26));
    appwin.style.transform = 'translate(-50%, -48%) translateY(' + ((1 - w) * 16).toFixed(2) + 'cqw) scale(' + (.12 + .88 * w).toFixed(4) + ')';
    appwin.style.opacity = Math.min(1, w * 2.2).toFixed(3);
    screen.classList.toggle('app-open', w > .4);

    setStep(appwin, 's1', p > .29);
    setStep(appwin, 's2', p > .35);
    var sp = seg(p, .36, .55);
    var streamText = T('stream'), n = Math.round(sp * streamText.length);
    if (stream._n !== n) { stream._n = n; stream.textContent = streamText.slice(0, n); }
    setStep(appwin, 's3', p > .56);
    setStep(appwin, 's4', p > .62);

    var qOn = p > .69;
    quick.classList.toggle('on', qOn);
    screen.classList.toggle('dim', qOn);
    var QUICK = T('quick'), qn = Math.round(seg(p, .71, .79) * QUICK.length);
    if (quickText._n !== qn) { quickText._n = qn; quickText.textContent = QUICK.slice(0, qn); }
    quick.classList.toggle('res', p > .82);

    if (notes.length) {
      notes[0].classList.toggle('on', p > .18 && p < .66);
      notes[1].classList.toggle('on', p >= .7);
    }
  }

  function updatePhones(p) {
    var e = easeIO(seg(p, 0, .55));
    var drift = (p - .5) * 40;
    if (phones.l) phones.l.style.transform = 'translateY(' + ((1 - e) * 160 - drift * .5).toFixed(1) + 'px) rotateY(' + ((1 - e) * 28 + 8).toFixed(2) + 'deg) rotateZ(' + ((1 - e) * -6).toFixed(2) + 'deg)';
    if (phones.c) phones.c.style.transform = 'translateY(' + ((1 - e) * 260 - 24 - drift).toFixed(1) + 'px)';
    if (phones.v) phones.v.style.transform = 'translateY(' + ((1 - e) * 160 - drift * .5).toFixed(1) + 'px) rotateY(' + ((1 - e) * -28 - 8).toFixed(2) + 'deg) rotateZ(' + ((1 - e) * 6).toFixed(2) + 'deg)';
  }

  function updatePeople(p) {
    track.style.transform = 'translate3d(' + (-p * trackShift).toFixed(1) + 'px,0,0)';
    peopleBar.style.transform = 'scaleX(' + p.toFixed(4) + ')';
    var mid = window.innerWidth / 2;
    pcards.forEach(function (c) {
      var r = c.getBoundingClientRect();
      if (r.right < -200 || r.left > window.innerWidth + 200) return;
      c.style.setProperty('--px', ((r.left + r.width / 2 - mid) * -.06).toFixed(1) + 'px');
    });
  }

  var pins = $$('[data-pin]');
  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () {
      ticking = false;
      var y = window.scrollY;
      var docH = document.documentElement.scrollHeight - vh;
      scrollBar.style.transform = 'scaleX(' + (docH > 0 ? y / docH : 0).toFixed(4) + ')';
      nav.classList.toggle('scrolled', y > 20);

      // Hero: petals burst outward as you leave
      var hp = clamp(y / (vh * .85));
      if (hp < 1 || !hero._done) {
        hero._done = hp >= 1;
        heroMark.style.setProperty('--hp', hp.toFixed(4));
        heroInner.style.transform = 'translateY(' + (hp * 90).toFixed(1) + 'px) scale(' + (1 - hp * .06).toFixed(4) + ')';
        heroInner.style.opacity = (1 - hp * 1.15).toFixed(3);
      }

      pins.forEach(function (sec) {
        var r = sec.getBoundingClientRect();
        if (r.bottom < -50 || r.top > vh + 50) return;
        var p = sectionProgress(sec);
        if (sec.id === 'manifesto') {
          var lit = Math.floor(seg(p, .05, .85) * (words.length + 1));
          for (var i = 0; i < words.length; i++) {
            var on = i < lit;
            if (words[i]._on !== on) { words[i]._on = on; words[i].classList.toggle('lit', on); }
          }
        } else if (sec.id === 'desktop') updateDesk(p);
        else if (sec.id === 'mobile') updatePhones(p);
        else if (sec.id === 'people') updatePeople(p);
      });
    });
  }

  layout();
  window.addEventListener('scroll', onScroll, { passive: true });
  window.addEventListener('resize', function () { layout(); onScroll(); });
  window.addEventListener('load', function () { layout(); onScroll(); });
  updateDesk(0); updatePhones(0);

  /* ----------------------------------------------------------------------
     5. OS switcher for the desktop preview
     ---------------------------------------------------------------------- */
  var tabs = $$('.os-tabs [data-os]'), pill = $('.os-pill');
  function selectOS(os) {
    screen.dataset.os = os;
    tabs.forEach(function (b) {
      var on = b.dataset.os === os;
      b.setAttribute('aria-selected', on ? 'true' : 'false');
      if (on) { pill.style.width = b.offsetWidth + 'px'; pill.style.transform = 'translateX(' + b.offsetLeft + 'px)'; }
    });
  }
  tabs.forEach(function (b) { b.addEventListener('click', function () { selectOS(b.dataset.os); }); });
  selectOS(OS === 'win' || OS === 'linux' ? OS : 'mac');
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { selectOS(screen.dataset.os); layout(); });

  /* ----------------------------------------------------------------------
     6. Reveal on scroll (staggered per parent)
     ---------------------------------------------------------------------- */
  var groups = new Map();
  $$('[data-reveal]').forEach(function (el) {
    var k = el.parentNode, i = groups.get(k) || 0;
    el.style.setProperty('--rd', (i * .08) + 's');
    groups.set(k, i + 1);
  });
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (en) {
      if (!en.isIntersecting) return;
      en.target.classList.add('in');
      io.unobserve(en.target);
      if (en.target.classList.contains('t-fast')) countUp($('.speed-num', en.target));
      if (en.target.classList.contains('try-win')) startTry();
    });
  }, { threshold: .15, rootMargin: '0px 0px -5% 0px' });
  $$('[data-reveal]').forEach(function (el) { io.observe(el); });

  /* ----------------------------------------------------------------------
     7. Hero: starfield dust + mouse tilt
     ---------------------------------------------------------------------- */
  (function dust() {
    var cv = $('#dust');
    if (!cv || reduceMotion) return;
    var ctx = cv.getContext('2d'), dpr = Math.min(2, window.devicePixelRatio || 1);
    var W, H, pts = [], mx = 0, my = 0, visible = true;
    function size() {
      W = cv.clientWidth; H = cv.clientHeight;
      cv.width = W * dpr; cv.height = H * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var n = Math.round(Math.min(130, W * H / 9000));
      pts = [];
      for (var i = 0; i < n; i++) pts.push({ x: Math.random() * W, y: Math.random() * H, z: Math.random() * .9 + .1, s: Math.random() * 6.28, v: Math.random() * .25 + .05 });
    }
    size();
    window.addEventListener('resize', size);
    hero.addEventListener('pointermove', function (e) { mx = e.clientX / W - .5; my = e.clientY / H - .5; });
    new IntersectionObserver(function (en) { visible = en[0].isIntersecting; if (visible) requestAnimationFrame(draw); }).observe(hero);
    function draw(t) {
      if (!visible) return;
      ctx.clearRect(0, 0, W, H);
      for (var i = 0; i < pts.length; i++) {
        var p = pts[i];
        p.y -= p.v * p.z; if (p.y < -5) { p.y = H + 5; p.x = Math.random() * W; }
        var a = (.35 + .65 * Math.abs(Math.sin(t / 1400 + p.s))) * p.z;
        var x = p.x - mx * 30 * p.z, y = p.y - my * 30 * p.z;
        ctx.beginPath();
        ctx.fillStyle = 'rgba(' + (150 + 105 * p.z | 0) + ',' + (185 + 70 * p.z | 0) + ',255,' + a.toFixed(3) + ')';
        ctx.arc(x, y, p.z * 1.4, 0, 6.283);
        ctx.fill();
      }
      requestAnimationFrame(draw);
    }
    requestAnimationFrame(draw);
  })();

  if (finePointer && !reduceMotion) {
    hero.addEventListener('pointermove', function (e) {
      var r = hero.getBoundingClientRect();
      var x = (e.clientX - r.left) / r.width - .5, y = (e.clientY - r.top) / r.height - .5;
      heroMark.style.transform = 'perspective(800px) rotateY(' + (x * 22).toFixed(2) + 'deg) rotateX(' + (-y * 22).toFixed(2) + 'deg)';
    });
    hero.addEventListener('pointerleave', function () { heroMark.style.transform = ''; });
    heroMark.style.transition = 'transform .6s cubic-bezier(.2,.7,.1,1)';
  }

  /* ----------------------------------------------------------------------
     8. Micro-interactions: magnetic buttons + spotlight tiles
     ---------------------------------------------------------------------- */
  if (finePointer && !reduceMotion) {
    $$('.magnetic').forEach(function (el) {
      el.addEventListener('pointermove', function (e) {
        var r = el.getBoundingClientRect();
        var x = e.clientX - r.left - r.width / 2, y = e.clientY - r.top - r.height / 2;
        el.style.transform = 'translate(' + (x * .22).toFixed(1) + 'px,' + (y * .3).toFixed(1) + 'px)';
      });
      el.addEventListener('pointerleave', function () { el.style.transform = ''; });
    });
  }
  $$('.spot').forEach(function (el) {
    el.addEventListener('pointermove', function (e) {
      var r = el.getBoundingClientRect();
      el.style.setProperty('--mx', (e.clientX - r.left) + 'px');
      el.style.setProperty('--my', (e.clientY - r.top) + 'px');
    });
  });

  /* ----------------------------------------------------------------------
     9. Bento details
     ---------------------------------------------------------------------- */
  var wave = $('.wave');
  if (wave) {
    var bars = '';
    for (var i = 0; i < 34; i++) {
      var h = (.25 + Math.abs(Math.sin(i * .55)) * .55 + Math.random() * .2).toFixed(2);
      bars += '<i style="--h:' + h + ';animation-delay:' + (-Math.random() * 1.2).toFixed(2) + 's;animation-duration:' + (.7 + Math.random() * .7).toFixed(2) + 's"></i>';
    }
    wave.innerHTML = bars;
  }

  var toneTabs = $$('.tone-tabs span'), toneOut = $('#toneOut'), toneI = 0;
  function setTone(i) {
    toneI = i;
    toneTabs.forEach(function (t, j) { t.classList.toggle('on', j === i); });
    toneOut.classList.add('swap');
    setTimeout(function () { toneOut.textContent = T('tones')[i]; toneOut.classList.remove('swap'); }, 280);
  }
  toneTabs.forEach(function (t, j) { t.style.cursor = 'pointer'; t.addEventListener('click', function () { setTone(j); }); });
  setInterval(function () { if (!document.hidden) setTone((toneI + 1) % 3); }, 3200);

  function countUp(el) {
    if (!el) return;
    var target = parseFloat(el.dataset.count), t0 = performance.now();
    (function f(now) {
      var p = clamp((now - t0) / 1400);
      el.textContent = (ease(p) * target).toFixed(1);
      if (p < 1) requestAnimationFrame(f);
    })(t0);
  }

  /* ----------------------------------------------------------------------
     10. "Ask it something hard" — scripted streaming preview
     ---------------------------------------------------------------------- */
  var tryBody = $('#tryBody'), tryInput = $('#tryInput'), tryRun = 0, tryStarted = false, tryCurrent = 0;
  tryInput.textContent = T('askPlaceholder');
  var promptBtns = $$('.prompt');
  var BLOOM_SVG = '<svg class="mini-bloom" viewBox="0 0 1024 1024"><g fill="currentColor">' + petals() + '</g></svg>';

  function wait(ms, run) { return new Promise(function (res, rej) { setTimeout(function () { run === tryRun ? res() : rej(); }, ms); }); }

  function streamInto(root, html, run) {
    root.innerHTML = html;
    var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
    var nodes = [], n;
    while ((n = walker.nextNode())) nodes.push({ node: n, text: n.nodeValue });
    $$('*', root).forEach(function (el) { if (el.tagName !== 'BR') { el._d = el.style.display; el.style.display = 'none'; } });
    nodes.forEach(function (o) { o.node.nodeValue = ''; });
    var ni = 0, ci = 0;
    return new Promise(function (res) {
      (function step() {
        if (run !== tryRun) return;
        var budget = 3;
        while (budget > 0 && ni < nodes.length) {
          var o = nodes[ni];
          if (ci === 0) {
            for (var p = o.node.parentNode; p && p !== root; p = p.parentNode) if (p.style && p.style.display === 'none') p.style.display = p._d || '';
          }
          var take = Math.min(budget, o.text.length - ci);
          ci += take; budget -= take;
          o.node.nodeValue = o.text.slice(0, ci);
          if (ci >= o.text.length) { ni++; ci = 0; }
        }
        tryBody.scrollTop = tryBody.scrollHeight;
        if (ni < nodes.length) requestAnimationFrame(step); else res();
      })();
    });
  }

  function ask(i) {
    var run = ++tryRun, item = T('answers')[i];
    tryCurrent = i;
    promptBtns.forEach(function (b, j) { b.classList.toggle('on', j === i); });
    tryBody.innerHTML = '';
    tryInput.textContent = '';
    var chars = Array.from(item.q), k = 0;
    (function type() {
      if (run !== tryRun) return;
      k += 2;
      tryInput.textContent = chars.slice(0, k).join('');
      if (k < chars.length) setTimeout(type, 16); else go();
    })();
    function go() {
      wait(260, run).then(function () {
        tryInput.textContent = T('askPlaceholder');
        var u = document.createElement('div');
        u.className = 'tw-user'; u.textContent = item.q;
        tryBody.appendChild(u);
        var b = document.createElement('div');
        b.className = 'tw-bot';
        b.innerHTML = '<div class="tw-bot-h">' + BLOOM_SVG + 'Sonot <small>' + T('thinking') + '</small></div><div class="tw-dots"><i></i><i></i><i></i></div>';
        tryBody.appendChild(b);
        $('.mini-bloom', b).classList.add('spin');
        return wait(900, run).then(function () {
          $('.tw-dots', b).remove();
          $('.mini-bloom', b).classList.remove('spin');
          $('small', b).textContent = item.ms;
          var c = document.createElement('div');
          b.appendChild(c);
          return streamInto(c, item.a, run);
        });
      }).catch(function () {});
    }
  }
  promptBtns.forEach(function (b) { b.addEventListener('click', function () { tryStarted = true; ask(+b.dataset.prompt); }); });
  function startTry() { if (tryStarted) return; tryStarted = true; setTimeout(function () { ask(0); }, 400); }

  /* ----------------------------------------------------------------------
     11. Language switch (EN ⇄ PT), live without reloading
     ---------------------------------------------------------------------- */
  var langBtn = $('#langBtn');
  function langButton() {
    langBtn.textContent = T('langBtn');
    langBtn.setAttribute('aria-label', T('langLabel'));
  }
  langButton();
  langBtn.addEventListener('click', function () {
    var next = I18n.lang === 'pt' ? 'en' : 'pt';
    store('sonot.lang', next);
    I18n.apply(next);
  });
  if (I18n) I18n.on(function () {
    langButton();
    downloadText();
    splitManifesto();
    stream._n = -1; quickText._n = -1;
    toneOut.textContent = T('tones')[toneI];
    if (tryStarted) ask(tryCurrent);
    selectOS(screen.dataset.os);
    layout();
    onScroll();
  });
})();
