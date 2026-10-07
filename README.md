<div align="center">

### [thatmaxwell.github.io/Sonot](https://thatmaxwell.github.io/Sonot/)

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/sonot-mark.svg">
  <img src="assets/brand/sonot-mark-ink.svg" alt="Sonot" width="140">
</picture>

# Sonot

### Think in light.

**One AI family that reads, reasons, writes, codes, sees and speaks.**
Built for the machines you actually use: **Windows**, **Android** and **Linux**.

Made by [ThatMaxwell](https://github.com/ThatMaxwell)

`Windows` · `Android` · `Linux`

</div>

---

## The Sonot family

Three apps, one mind. Each one is built for a different side of your day.

| App | What it is | Status |
|---|---|---|
| **Sonot** | The assistant. Ask anything, think out loud, write, plan and learn, in a chat that feels fast and personal. | Coming soon |
| **Sonot Buds** | Companions with personality. Characters you can talk to, laugh with and come back to, with their own voices and styles. | Coming soon |
| **Sonot Code** | The flagship. An agentic coding partner that works where you work: GitHub, your terminal, a built-in browser and your desktop. | Coming soon |

> **Where things stand:** this repository is home to the official Sonot launch site, which is live today. The apps are in active development, and nothing above ships until it's ready. Star the repo to follow along.

## Made for your screens

Sonot is designed first for **Windows**, with **Android** and **Linux** right alongside it. Every app shares one design language, white and electric blue, so moving from your desktop to your phone feels like one continuous conversation.

## The launch site

The site is more than a download page. It's an experience.

- **"Ignition", the launch film.** A 45-second, real-time 3D shot built in three.js: one particle system becomes a spark, a vortex and an explosion into the Sonot bloom, all locked to an original 128 BPM soundtrack synthesized live in your browser.
- **Interactive from top to bottom.** A 3D glass bloom, a petal galaxy, a pinned desktop showcase for Windows and Linux, fanned Android phones, live talent tiles and an "ask it something hard" preview.
- **Bilingual from the first second.** English and Português, chosen on the very first screen and remembered after that.

---

## For developers

This repo holds two things:

- **The Sonot app** in [`app/`](app): Flutter for Windows, Android and Linux, with an optional backend in [`server/`](server). See [`app/README.md`](app/README.md) and [`server/README.md`](server/README.md).
- **The launch site** (everything else below), built with **Flutter** (web), **three.js** and **WebAudio**.

### The experience, step by step

1. **Language:** English or Português, the very first screen (no branding yet). Remembered; switch anytime with the EN/PT button.
2. **Loader:** exactly 3 seconds. The petals fly in and the icon forms around them.
3. **Launch film:** Esc skips, M mutes. The film's clock *is* the music.
4. **The site:** hero, marquee bands, manifesto, desktop app on Windows / Linux, Android phones, talents, people, "try it" demo, download section and footer.

URL flags: `?film` always plays the film, `?nofilm` skips it, `?reset` forgets everything (language, film seen, mute).

### Publish (GitHub Pages)

The compiled site lives in **`docs/`**. In **Settings → Pages**, choose *Deploy from a branch* → `main` with either `/ (root)` (a small `index.html` forwards to `docs/`) or `/docs`. Both work.

### Edit & rebuild

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.38+).

```sh
flutter pub get
flutter run -d chrome                        # live preview
flutter build web --release --no-web-resources-cdn -o docs
```

(The page works out its own base path, so it runs from any folder or domain.)

- **Download links & film behaviour:** `lib/core/config.dart`
- **All text (English + Portuguese):** `lib/core/i18n.dart`

### Code map

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
