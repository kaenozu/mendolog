import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'domain.dart';
import 'storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(MendologApp(store: MendologStore(preferences)));
}

class MendologApp extends StatelessWidget {
  const MendologApp({super.key, required this.store});
  final MendologStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'めんどログ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff476b5c)),
      useMaterial3: true,
    ),
    home: MendologHome(store: store),
  );
}

class MendologHome extends StatefulWidget {
  const MendologHome({super.key, required this.store});
  final MendologStore store;

  @override
  State<MendologHome> createState() => _MendologHomeState();
}

class _MendologHomeState extends State<MendologHome> {
  late MendologData data = widget.store.load();
  int tab = 0;

  Future<void> _record(FrictionCategory category, String target) async {
    final clean = canonicalizeTarget(target);
    if (clean.isEmpty) return;
    final event = FrictionEvent(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: category,
      target: clean,
      occurredAt: DateTime.now(),
    );
    setState(
      () => data = MendologData(
        events: [...data.events, event],
        improvements: data.improvements,
      ),
    );
    await widget.store.save(data);
  }

  Future<void> _openRecorder(FrictionCategory category) async {
    final controller = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            final targets = data.recentTargets;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${category.emoji} ${category.label}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (targets.isNotEmpty) ...[
                  const Text('最近使った対象'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: targets
                        .map(
                          (target) => ActionChip(
                            label: Text(target),
                            onPressed: () => Navigator.pop(context, target),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: controller,
                  autofocus: targets.isEmpty,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '対象を入力',
                    hintText: '例：爪切り',
                  ),
                  onSubmitted: (value) => Navigator.pop(context, value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, controller.text),
                    child: const Text('記録する'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    if (selected != null) await _record(category, selected);
  }

  Future<void> _startImprovement(ImprovementSuggestion suggestion) async {
    final improvement = Improvement(
      category: suggestion.category,
      canonicalTarget: suggestion.canonicalTarget,
      title: suggestion.title,
      startedAt: DateTime.now(),
    );
    setState(
      () => data = MendologData(
        events: data.events,
        improvements: [...data.improvements, improvement],
      ),
    );
    await widget.store.save(data);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('めんどログ'), centerTitle: false),
    body: IndexedStack(
      index: tab,
      children: [_home(), _history(), _insights()],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (value) => setState(() => tab = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          label: '記録',
        ),
        NavigationDestination(icon: Icon(Icons.history), label: '履歴'),
        NavigationDestination(icon: Icon(Icons.insights_outlined), label: '集計'),
      ],
    ),
  );

  Widget _home() {
    final suggestions = data.suggestions(DateTime.now());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('いま、何がめんどかった？', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'タップして対象を選ぶだけ。記録は端末内に保存されます。',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: FrictionCategory.values
              .map(
                (category) => FilledButton.tonal(
                  onPressed: () => _openRecorder(category),
                  child: Text('${category.emoji}  ${category.label}'),
                ),
              )
              .toList(),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('改善の候補', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...suggestions.map(
            (suggestion) => Card(
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(
                  '${suggestion.category.label}「${suggestion.canonicalTarget}」',
                ),
                subtitle: Text(
                  '直近30日で${suggestion.count}回。${suggestion.title}？',
                ),
                trailing: TextButton(
                  onPressed: () => _startImprovement(suggestion),
                  child: const Text('改善する'),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _history() => data.events.isEmpty
      ? const Center(child: Text('まだ記録がありません'))
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: data.events.length,
          itemBuilder: (context, index) {
            final event = data.events[data.events.length - 1 - index];
            return ListTile(
              leading: Text(
                event.category.emoji,
                style: const TextStyle(fontSize: 24),
              ),
              title: Text('${event.category.label} · ${event.canonicalTarget}'),
              subtitle: Text(_formatDate(event.occurredAt)),
            );
          },
        );

  Widget _insights() {
    final now = DateTime.now();
    final rows = <Widget>[];
    for (final category in FrictionCategory.values) {
      final count = data.events
          .where(
            (event) =>
                event.category == category &&
                event.occurredAt.isAfter(
                  now.subtract(const Duration(days: 30)),
                ),
          )
          .length;
      if (count > 0) {
        rows.add(
          ListTile(
            leading: Text(category.emoji, style: const TextStyle(fontSize: 22)),
            title: Text(category.label),
            trailing: Text('$count回'),
          ),
        );
      }
    }
    final improvements = data.improvements;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('直近30日の集計', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        if (rows.isEmpty) const Text('記録が増えると、ここに集計が表示されます。') else ...rows,
        if (improvements.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('改善の効果', style: Theme.of(context).textTheme.titleLarge),
          ...improvements.map((item) {
            final comparison = data.comparison(item, now);
            return ListTile(
              title: Text('${item.canonicalTarget} · ${item.title}'),
              subtitle: Text(
                '改善前 ${comparison.before}回 → 改善後 ${comparison.after}回',
              ),
            );
          }),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) =>
      '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
