# Sonot

My Best AI Work, Sonot. Made by [ThatMaxwell](https://github.com/ThatMaxwell).

This repo holds the Sonot launch & download site, built with **Flutter** (web), with **three.js** backgrounds and a soundtrack synthesized live in the browser.

## The experience

1. **Language** — English or Português, the very first screen (no branding yet). Remembered; switch anytime with the EN/PT button.
2. **Loader** — exactly 3 seconds: the petals fly in and the icon forms around them.
3. **Launch film** — 50 seconds, 26 bars at 124 BPM. The film's clock *is* the music, so every slam, cut and pulse lands on the beat. Esc skips, M mutes.
4. **The site** — white + electric blue, black for contrast:
   hero with a 3D glass bloom (three.js) · crossing marquee bands · manifesto over a petal galaxy (three.js) · pinned desktop app on macOS / Windows / Linux · fanned phones · talents bento with live tiles · sideways people carousel · interactive "ask it something hard" demo · electric-blue download section over particle waves (three.js) · footer.

URL flags: `?film` always plays the film, `?nofilm` skips it, `?reset` forgets everything (language, film seen, mute).

## Publish (GitHub Pages)

The compiled site lives in **`docs/`**. In the repo's **Settings → Pages**, choose *Deploy from a branch* → `main` → **`/docs`**.

## Edit & rebuild

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.38+).

```sh
flutter pub get
flutter run -d chrome                        # live preview
flutter build web --release --base-href /Sonot/ --no-web-resources-cdn -o docs
```

(`/Sonot/` matches the GitHub Pages path; use `/` if you host it at a domain root.)

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
web/js/sonot3d.js          three.js scenes: bloom, galaxy, waves
assets/                    photos, brand marks, fonts
```

Photo credits: see `CREDITS.md`. three.js is MIT licensed (`web/js/three.LICENSE`).
