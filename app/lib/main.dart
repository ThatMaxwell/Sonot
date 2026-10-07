import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/settings.dart';
import 'core/theme.dart';
import 'screens/chat.dart';
import 'screens/setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  runApp(SonotApp(settings: settings));
}

class SonotApp extends StatefulWidget {
  const SonotApp({super.key, required this.settings});
  final Settings settings;

  @override
  State<SonotApp> createState() => _SonotAppState();
}

class _SonotAppState extends State<SonotApp> {
  late bool _setupDone = widget.settings.signedIn;

  void _finishSetup() => setState(() => _setupDone = true);

  Future<void> _signOut() async {
    await widget.settings.signOut();
    setState(() => _setupDone = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sonot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: F.sans,
        colorScheme: ColorScheme.fromSeed(seedColor: C.blue),
        splashFactory: InkSparkle.splashFactory,
      ),
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: _setupDone
              ? ChatScreen(key: const ValueKey('chat'), settings: widget.settings, onSignOut: _signOut)
              : SetupScreen(key: const ValueKey('setup'), settings: widget.settings, onDone: _finishSetup),
        ),
      ),
    );
  }
}
