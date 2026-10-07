import 'package:flutter/material.dart';

import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/glass.dart';
import 'bud_avatar.dart';
import 'bud_chat.dart';
import 'buds.dart';
import 'make_bud.dart';

/// A grid of glass cards, one per Bud, and a "New Bud" card at the end.
class BudsHome extends StatelessWidget {
  const BudsHome({super.key, required this.store, required this.settings, required this.palette});
  final BudStore store;
  final Settings settings;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    final pad = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(22, pad.top + 92, 22, 6),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Your ', style: sans(34, c: p.text, w: FontWeight.w700, ls: -.03, h: 1.1)),
                            TextSpan(text: 'Buds', style: serif(38, c: p.accent, h: 1.1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Helpers with a face and a job. Each one remembers what you tell it, and you can see all of it.',
                          style: sans(15, c: p.textSoft, w: FontWeight.w400)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 14, 16, pad.bottom + 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: .78,
                  ),
                  delegate: SliverChildListDelegate([
                    for (final b in store.buds) _BudCard(bud: b, palette: p, onTap: () => _open(context, b)),
                    _NewBudCard(palette: p, onTap: () => _make(context)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Bud b) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, _, _) => BudChat(bud: b, store: store, settings: settings),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: ScaleTransition(scale: Tween(begin: .97, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)), child: child),
        ),
      ),
    );
  }

  Future<void> _make(BuildContext context) async {
    final bud = await showMakeBud(context: context, palette: palette);
    if (bud == null || !context.mounted) return;
    store.add(bud);
    _open(context, bud);
  }
}

class _BudCard extends StatelessWidget {
  const _BudCard({required this.bud, required this.palette, required this.onTap});
  final Bud bud;
  final Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Glass(
      radius: 26,
      fill: p.glass,
      edge: p.edge,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (_, c) => BudAvatar(
                        shape: bud.shape,
                        color: bud.color,
                        size: c.biggest.shortestSide.clamp(48, 96).toDouble(),
                        semanticLabel: bud.name,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(bud.name, style: sans(18, c: p.text, w: FontWeight.w700, ls: -.01)),
                const SizedBox(height: 3),
                Text(bud.job, maxLines: 2, overflow: TextOverflow.ellipsis, style: sans(13.5, c: p.textSoft, w: FontWeight.w400, h: 1.3)),
                const SizedBox(height: 10),
                Text(
                  bud.memory.isEmpty ? 'NEW' : 'REMEMBERS ${bud.memory.length}',
                  style: mono(10.5, c: p.textSoft.withValues(alpha: .8), w: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewBudCard extends StatelessWidget {
  const _NewBudCard({required this.palette, required this.onTap});
  final Palette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Glass(
      radius: 26,
      fill: p.glass.withValues(alpha: p.glass.a * .5),
      edge: p.edge,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(shape: CircleBorder(side: BorderSide(color: p.textSoft.withValues(alpha: .5), width: .8))),
                child: Icon(Icons.add_rounded, color: p.text, size: 28),
              ),
              const SizedBox(height: 12),
              Text('New Bud', style: sans(16, c: p.text, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('Give it a job and a face', style: sans(13, c: p.textSoft, w: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}
