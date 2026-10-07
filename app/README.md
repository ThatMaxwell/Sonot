# Sonot app

The Sonot chat app, in Flutter, for **Windows**, **Android** and **Linux**. It reuses the launch site's palette, fonts and bloom mark.

## What's in it

- **Setup**: night-navy screen with *Continue with Puter* (or *Use my own server*).
- **Chat**: glass top bar and composer over a soft backdrop. The Sonot mark sits in the middle of an empty chat and steps aside as soon as you type.
- **Sonot / Code switch**: Code turns the whole app dark and more serious, uses mono type, and has its own conversation and model.
- **Models**: four tiers with a five-stop effort bar (Instant → Max). Edit names and picks in [`lib/core/models.dart`](lib/core/models.dart).

| Tier | Model (via Puter) | Effort stops |
|---|---|---|
| Sonot Hum | GPT-6 Luna | Instant, Quick |
| Sonot Tone | Gemini 3.8 Flash | Instant, Quick, Balanced |
| Sonot Chord | Claude Sonnet 5.5 | Quick → Max |
| Sonot Anthem | Claude Opus 5.5 | Balanced → Max |

## How the AI works

Replies come from [Puter](https://docs.puter.com/AI/chat/), the service behind puter.js. Each person signs in with their own Puter account, which pays for their own usage (Puter's *user-pays* model), so the app ships with no API keys and needs no server.

Sign-in works like puter.js does in Node: the app opens `puter.com/?action=authme` in the browser and catches the token on a one-shot `localhost` address (`lib/core/puter_auth.dart`). Chat calls go to the same endpoint puter.js uses, `api.puter.com/drivers/call`, and stream back line by line (`lib/core/api.dart`).

*Use my own server* points the app at [`../server`](../server) instead, which holds an Anthropic API key.

## Run and build

Needs Flutter 3.38+.

```sh
cd app
flutter pub get
flutter run -d windows        # or: -d linux, or a connected Android phone
flutter test

flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
flutter build windows --release
flutter build linux --release
```

Windows builds need a Windows PC. GitHub builds all three on every push that touches `app/` (see `.github/workflows/app.yml`): open the run under **Actions** and download **Sonot-windows** (installer + zip), **Sonot-android** (APK) or **Sonot-linux**. Pushing a tag like `v0.1.0` publishes them as a release.

The Android APK is signed with the debug key for now, so it installs by sideloading; set up a release key before the Play Store.

## Code map

```
lib/main.dart                 setup or chat
lib/screens/setup.dart        first-run screen
lib/screens/chat.dart         the chat screen, mode switch, account sheet
lib/core/api.dart             Puter and own-server providers (streaming)
lib/core/puter_auth.dart      Puter sign-in through the browser
lib/core/models.dart          tiers and the effort bar
lib/core/settings.dart        what the app remembers
lib/core/theme.dart           palette, the two moods, type
lib/widgets/glass.dart        glass, glass buttons, the backdrop
lib/widgets/model_picker.dart model chip, picker and effort slider
lib/widgets/message.dart      message bubbles and code blocks
lib/widgets/markdown.dart     light Markdown for replies
lib/widgets/bloom.dart        the Sonot mark (shared with the site)
windows/installer/sonot.iss   Windows installer script
```
