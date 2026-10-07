# Sonot

My Best AI Work, Sonot. Made by [ThatMaxwell](https://github.com/ThatMaxwell).

This repo holds the Sonot launch & download site, built with **Flutter** (web), with **three.js** backgrounds and a soundtrack synthesized live in the browser.

## The experience

1. **Language** — English or Português, the very first screen (no branding yet). Remembered; switch anytime with the EN/PT button.
2. **Loader** — exactly 3 seconds: the petals fly in and the icon forms around them.
3. **Launch film, "Ignition"** — 45 seconds, one continuous real-time 3D shot (three.js): a single particle system becomes a point of light, sparks, a vortex, implodes, explodes into the Sonot bloom on the drop, writes SONOT and the six talents in light, draws a laptop and a phone, warps through hyperspace past people's questions, and lands as the app icon. Scored with an uplifting 128 BPM cinematic electronic track in D major that builds the hype without the noise (the film's clock *is* the music). Esc skips, M mutes.
4. **The site** — white + electric blue, black for contrast:
   hero with a 3D glass bloom (three.js) · crossing marquee bands · manifesto over a petal galaxy (three.js) · pinned desktop app on Windows / Linux · fanned Android phones · talents bento with live tiles · sideways people carousel · interactive "ask it something hard" demo · electric-blue download section over particle waves (three.js) · footer.

URL flags: `?film` always plays the film, `?nofilm` skips it, `?reset` forgets everything (language, film seen, mute).

## Publish (GitHub Pages)

The compiled site lives in **`docs/`**. In **Settings → Pages**, choose *Deploy from a branch* → `main` with either `/ (root)` (a small `index.html` forwards to `docs/`) or `/docs`. Both work.

## Edit & rebuild

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.38+).

```sh
flutter pub get
flutter run -d chrome                        # live preview
flutter build web --release --no-web-resources-cdn -o docs
```

(The page works out its own base path, so it runs from any folder or domain.)

- **Download links & film behaviour:** `lib/core/config.dart`
- **All text (English + Portuguese):** `lib/core/i18n.dart`

## Code map

```
lib/main.dart              language → loader → film → site
lib/phases/intro.dart      language gate + 3s loader
lib/film/film.dart         the launch film (10 beat-synced scenes)
lib/site/                  site sections (hero, desktop, phones, talents, people, try it, download, footer)
lib/widgets/motion.dart    pin-on-scroll, parallax, reveal, marquee, tilt, magnetic, smooth wheel
lib/widgets/bloom.dart     Sonot + ThatMaxwell logos as vectors
web/js/audio.js            the soundtrack (WebAudio synth + arrangement)
web/js/film3d.js           the launch film: one particle system, every formation, camera + colour moods
web/js/sonot3d.js          three.js scenes: bloom, galaxy, waves (and mounts the film)
web/js/jsm/                three.js bloom post-processing
assets/                    photos, brand marks, fonts
```

Photo credits: see `CREDITS.md`. three.js is MIT licensed (`web/js/three.LICENSE`).
