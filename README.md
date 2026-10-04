# Sonot

My Best AI Work, Sonot. Made by [ThatMaxwell](https://github.com/ThatMaxwell).

This repo holds the Sonot launch & download site.

## What's on the site

1. **Loader** that lasts exactly 3 seconds while the Sonot petals bloom in.
2. **Launch film** (0:49), built in real time from HTML/CSS with a soundtrack synthesized in the browser (tap *Sound* or press **M**). **Esc** skips it.
3. **Scroll story**: hero bloom, manifesto, desktop app preview (macOS / Windows / Linux), phones, capabilities, people, an interactive "ask it something hard" demo, and downloads.

## Run it locally

Open `index.html` in a browser, or serve the folder:

```sh
npx http-server .
```

Handy URL flags: `?film` always plays the launch film, `?nofilm` skips it.

## Publish with GitHub Pages

Settings → Pages → *Deploy from a branch* → pick your branch and `/ (root)`. No build step needed.

## Configure

Everything you'll want to change lives in `assets/js/config.js`:

- `downloads`: paste each platform's download URL. Empty links show a "coming soon" toast.
- `version` / `requirements`: the text under the download button.
- `film`: `'first-visit'` (default), `'always'` or `'never'`.

## Files

```
index.html             page markup (loader, film scenes, site sections)
assets/css/style.css   all styles and animations
assets/js/config.js    download links + settings
assets/js/film.js      launch film timeline + generative soundtrack
assets/js/main.js      loader flow, scroll scenes, interactions
assets/brand/          Sonot icon & mark, ThatMaxwell logo, favicons, share image
assets/img/            photography (see CREDITS.md)
```
