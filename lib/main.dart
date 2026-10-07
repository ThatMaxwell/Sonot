import 'package:flutter/material.dart' show MaterialApp, ThemeData;
import 'package:flutter/widgets.dart';
import 'core/bridge.dart';
import 'core/config.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'film/film.dart';
import 'phases/intro.dart';
import 'site/site.dart';

void main() => runApp(const SonotApp());

class SonotApp extends StatelessWidget {
  const SonotApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Sonot',
    debugShowCheckedModeBanner: false,
    color: C.blue,
    theme: ThemeData(fontFamily: F.sans, scaffoldBackgroundColor: C.white, useMaterial3: true),
    home: DefaultTextStyle(style: sans(16), child: const Shell()),
  );
}

enum Phase { language, loader, film, site }

/// Runs the show: language → 3s loader → launch film (first visit) → site.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late Phase phase;
  late final bool playFilm;
  final revealed = ValueNotifier<bool>(false);
  bool loaderVisible = true;
  int filmRun = 0;

  @override
  void initState() {
    super.initState();
    final q = Uri.base.queryParameters;
    if (q.containsKey('reset')) Browser.clearSonot();
    final saved = Browser.read('sonot.lang');
    if (saved == 'en' || saved == 'pt') {
      lang.value = saved!;
      phase = Phase.loader;
    } else {
      phase = Phase.language;
    }
    const mode = SonotConfig.film;
    playFilm =
        q.containsKey('film') ||
        (!q.containsKey('nofilm') && !Browser.reducedMotion && (mode == 'always' || (mode == 'first-visit' && Browser.read('sonot.filmSeen') != '1')));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final p in [...montagePhotos, 'assets/img/desk-coffee.webp', 'assets/img/wall-peaks.webp', 'assets/img/phone-mountain.webp']) {
      precacheImage(AssetImage(p), context);
    }
  }

  void _loaderDone() => setState(() => phase = playFilm ? Phase.film : Phase.site);

  void _filmReveal() {
    Browser.write('sonot.filmSeen', '1');
    revealed.value = true;
  }

  void _filmDone() => setState(() => phase = Phase.site);

  void replay() => setState(() {
    filmRun++;
    phase = Phase.film;
  });

  @override
  Widget build(BuildContext context) {
    if (phase == Phase.site && !revealed.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => revealed.value = true);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // The site is built underneath from the start so its images warm up.
        Offstage(
          offstage: phase == Phase.language,
          child: Site(revealed: revealed, onReplay: replay),
        ),
        if (phase == Phase.film) FilmPlayer(key: ValueKey(filmRun), onReveal: _filmReveal, onDone: _filmDone),
        if (loaderVisible && phase != Phase.language) Loader(onDone: _loaderDone, onExit: () => setState(() => loaderVisible = false)),
        if (phase == Phase.language) LanguageGate(onPicked: (_) => setState(() => phase = Phase.loader)),
      ],
    );
  }
}
