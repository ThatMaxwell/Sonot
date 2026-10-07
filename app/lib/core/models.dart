/// The Sonot model family and the effort bar.
///
/// Names are Carrot's pick; models and effort ranges follow the research
/// plan (benchmarks + Puter prices). Rename or re-pick here and nowhere else. `model` is a Puter model id
/// from https://api.puter.com/puterai/chat/models/details.
class Tier {
  const Tier(this.id, this.name, this.blurb, this.model, this.efforts, this.defaultEffort);
  final String id;
  final String name;
  final String blurb;
  final String model;

  /// The effort stops this tier offers; the rest of the bar is dimmed.
  final Set<Effort> efforts;
  final Effort defaultEffort;

  /// The closest stop this tier allows to [e].
  Effort clamp(Effort e) {
    if (efforts.contains(e)) return e;
    final allowed = efforts.toList()..sort((a, b) => a.index.compareTo(b.index));
    return allowed.reduce((best, x) => (x.index - e.index).abs() < (best.index - e.index).abs() ? x : best);
  }
}

/// How hard the model thinks before answering. Sent to Puter as
/// `reasoning_effort`, which Puter maps onto each vendor's own control.
enum Effort {
  instant('Instant', 'none', 'Answers right away'),
  quick('Quick', 'low', 'A little thought'),
  balanced('Balanced', 'medium', 'Thinks when it helps'),
  deep('Deep', 'high', 'Works it through'),
  max('Max', 'xhigh', 'Takes all the time it needs');

  const Effort(this.label, this.puter, this.blurb);
  final String label;
  final String puter;
  final String blurb;

  static Effort? byName(String? n) => Effort.values.where((e) => e.name == n).firstOrNull;
}

const tiers = [
  Tier('hum', 'Sonot Hum', 'Fastest, for quick questions', 'gpt-6-luna', {Effort.instant, Effort.quick}, Effort.instant),
  Tier('tone', 'Sonot Tone', 'Everyday work, quick and sharp', 'gemini-3.8-flash', {
    Effort.instant,
    Effort.quick,
    Effort.balanced,
  }, Effort.quick),
  Tier('chord', 'Sonot Chord', 'Hard problems and real code', 'claude-sonnet-5-5', {
    Effort.quick,
    Effort.balanced,
    Effort.deep,
    Effort.max,
  }, Effort.balanced),
  Tier('anthem', 'Sonot Anthem', 'The strongest Sonot', 'claude-opus-5-5', {
    Effort.balanced,
    Effort.deep,
    Effort.max,
  }, Effort.deep),
];

Tier tierById(String? id) => tiers.firstWhere((t) => t.id == id, orElse: () => tiers[1]);
