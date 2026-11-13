import 'package:flutter/material.dart';

import '../api.dart';
import '../ui.dart';

/// User Guide & manual (role-filtered, from GET /guide). Developed & Powered by Marian Anbu Juwan
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});
  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String q = '';

  /// "**bold**" → bold spans.
  Widget _rich(String s, {TextStyle? style}) {
    final parts = s.split('**');
    return Text.rich(
      TextSpan(
        style: style ?? const TextStyle(fontSize: 13.5, height: 1.45, color: kInk),
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(
              text: parts[i],
              style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dgBar('User guide'),
      body: Loader<Map<String, dynamic>>(
        load: () => Api.I.get('/guide'),
        builder: (context, d, _) {
          final all = ((d['sections'] as List?) ?? const []).cast<Map>();
          final list = q.isEmpty ? all : all.where((s) => '${s['title']} ${s['summary']} ${(s['steps'] as List).join(' ')}'.toLowerCase().contains(q)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
            children: [
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search the guide…'),
                onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              if (list.isEmpty) const EmptyState(Icons.menu_book_outlined, 'Nothing matches — try another word.'),
              for (var n = 0; n < list.length; n++) ...[
                if (n == 0 || list[n]['group'] != list[n - 1]['group']) SectionTitle('${list[n]['group']}'),
                _section(list[n]),
              ],
              const SizedBox(height: 12),
              const Text(
                kCredit,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: kMuted),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _section(Map s) => Card(
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      leading: const GradientIcon(Icons.menu_book_rounded, gIndigo, size: 38),
      title: Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${s['summary']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: kMuted),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s['where'] != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kLine),
            ),
            child: Text('📍 ${s['where']}', style: const TextStyle(fontSize: 12, color: kMuted)),
          ),
        for (var i = 0; i < (s['steps'] as List).length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xFFEEF2FF), shape: BoxShape.circle),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontSize: 11, color: kBlue, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _rich('${(s['steps'] as List)[i]}')),
              ],
            ),
          ),
        for (final t in (s['tips'] as List? ?? const []))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF9DB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFEC99)),
            ),
            child: _rich('💡 $t', style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A5A00), height: 1.4)),
          ),
        if (s['image'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network('${s['image']}', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
      ],
    ),
  );
}
