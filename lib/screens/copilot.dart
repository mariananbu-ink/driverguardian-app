import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api.dart';
import '../ui.dart';

/// AI Copilot — answers from the school's own records first.
/// Conversations are kept on the phone: New chat, previous chats, clear.
/// Developed & Powered by Marian Anbu Juwan
class CopilotScreen extends StatefulWidget {
  const CopilotScreen({super.key});
  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final items = <Map<String, String>>[];
  final input = TextEditingController();
  final scroll = ScrollController();
  List<String> suggestions = [];
  bool busy = false;

  /// Saved conversations: {id, title, at, messages:[{role, content, source}]}
  List<Map<String, dynamic>> chats = [];
  String? currentId;

  String get _key => 'copilot_chats_${Api.I.user?['id'] ?? 0}';
  Map<String, String> get _greeting => {'role': 'assistant', 'content': 'Hi ${firstName(Api.I.user?['name'] as String?)} 👋 Ask me about buses, attendance, fees or routes.', 'source': ''};

  @override
  void initState() {
    super.initState();
    items.add(_greeting);
    Api.I.get('/copilot/suggestions').then((d) => setState(() => suggestions = (d['suggestions'] as List).cast<String>())).catchError((_) {});
    _restore();
  }

  Future<void> _restore() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      chats = ((j['chats'] as List?) ?? const []).cast<Map>().map((c) => c.cast<String, dynamic>()).toList();
      currentId = j['current'] as String?;
      final c = chats.where((x) => x['id'] == currentId).firstOrNull;
      if (c != null && mounted) setState(() => _show(c));
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode({'current': currentId, 'chats': chats}));
    } catch (_) {}
  }

  void _show(Map<String, dynamic>? c) {
    items
      ..clear()
      ..add(_greeting);
    if (c != null) items.addAll(((c['messages'] as List?) ?? const []).cast<Map>().map((m) => m.cast<String, String>()));
    _bottom();
  }

  void _newChat() {
    setState(() { currentId = null; _show(null); });
    _save();
  }

  void _clearChat() {
    setState(() {
      chats.removeWhere((c) => c['id'] == currentId);
      currentId = null;
      _show(null);
    });
    _save();
  }

  Future<void> _history() async {
    final list = [...chats]..sort((a, b) => ((b['at'] ?? 0) as num).compareTo((a['at'] ?? 0) as num));
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(builder: (c, set) => SafeArea(child: list.isEmpty
          ? const Padding(padding: EdgeInsets.all(30), child: Text('No saved chats yet.'))
          : ListView(shrinkWrap: true, children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 6), child: Text('Previous chats', style: TextStyle(fontWeight: FontWeight.w700))),
              for (final ch in list)
                ListTile(
                  leading: Icon(Icons.chat_bubble_outline, color: ch['id'] == currentId ? kBlue : kMuted),
                  title: Text('${ch['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${DateTime.fromMillisecondsSinceEpoch((ch['at'] as num).toInt()).toString().substring(0, 16)} · ${(((ch['messages'] as List?)?.length ?? 0) / 2).ceil()} question(s)'),
                  onTap: () => Navigator.pop(c, ch['id'] as String),
                  trailing: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                    chats.removeWhere((x) => x['id'] == ch['id']);
                    list.remove(ch);
                    if (ch['id'] == currentId) { currentId = null; _show(null); }
                    _save();
                    set(() {});
                    setState(() {});
                  }),
                ),
            ]))),
    );
    if (pick == null || !mounted) return;
    setState(() { currentId = pick; _show(chats.where((x) => x['id'] == pick).firstOrNull); });
    _save();
  }

  void _remember(String q, Map<String, String> answer) {
    var c = chats.where((x) => x['id'] == currentId).firstOrNull;
    if (c == null) {
      c = {'id': 'c${DateTime.now().millisecondsSinceEpoch}', 'title': q.length > 48 ? q.substring(0, 48) : q, 'at': DateTime.now().millisecondsSinceEpoch, 'messages': <Map<String, String>>[]};
      chats.add(c);
      if (chats.length > 15) chats.removeAt(0);
      currentId = c['id'] as String;
    }
    final m = ((c['messages'] as List?) ?? []).cast<Map>().map((x) => x.cast<String, String>()).toList()
      ..add({'role': 'user', 'content': q, 'source': 'u'})
      ..add(answer);
    c['messages'] = m.length > 40 ? m.sublist(m.length - 40) : m;
    c['at'] = DateTime.now().millisecondsSinceEpoch;
    _save();
  }

  Future<void> _ask(String q) async {
    q = q.trim();
    if (q.isEmpty || busy) return;
    final history = items.where((m) => m['source'] != '').map((m) => {'role': m['role']!, 'content': m['content']!}).toList();
    setState(() { items.add({'role': 'user', 'content': q, 'source': 'u'}); busy = true; });
    input.clear();
    _bottom();
    try {
      final r = await Api.I.post('/copilot/ask', {'q': q, 'history': history.length > 6 ? history.sublist(history.length - 6) : history});
      final a = {'role': 'assistant', 'content': r['answer']?.toString() ?? '', 'source': r['source']?.toString() ?? 'ai'};
      setState(() => items.add(a));
      _remember(q, a);
    } catch (e) {
      setState(() => items.add({'role': 'assistant', 'content': errText(e), 'source': 'error'}));
    } finally {
      setState(() => busy = false);
      _bottom();
    }
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  /// 2.12 markdown for answers: "## heading", **bold**, • bullets, | tables | (scroll sideways), [links](url).
  Widget _md(String text, bool mine) {
    final color = mine ? Colors.white : Colors.black87;
    final base = TextStyle(color: color, height: 1.35, fontSize: 14);
    final children = <Widget>[];
    final lines = text.replaceAll('\r', '').split('\n');
    var i = 0;
    List<String> cells(String l) => l.trim().replaceAll(RegExp(r'^\||\|$'), '').split('|').map((c) => c.trim()).toList();
    while (i < lines.length) {
      final t = lines[i].trim();
      if (t.isEmpty) { i++; continue; }
      if (t.startsWith('#')) {
        children.add(Padding(padding: const EdgeInsets.only(bottom: 4), child: _rich(t.replaceFirst(RegExp(r'^#+\s*'), ''), base.copyWith(fontWeight: FontWeight.w800, fontSize: 15))));
        i++;
        continue;
      }
      if (t.startsWith('|') && i + 1 < lines.length && RegExp(r'^\|?\s*:?-{2,}').hasMatch(lines[i + 1].trim())) {
        final head = cells(t);
        final body = <List<String>>[];
        i += 2;
        while (i < lines.length && lines[i].trim().startsWith('|')) { body.add(cells(lines[i])); i++; }
        children.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(10)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              children: [
                TableRow(decoration: const BoxDecoration(color: Color(0xFFF1F5F9)), children: [
                  for (var c = 0; c < head.length; c++) _cell(head[c], base.copyWith(fontWeight: FontWeight.w700, fontSize: 12), c > 0),
                ]),
                for (final r in body)
                  TableRow(decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEF2F7)))), children: [
                    for (var c = 0; c < head.length; c++) _cell(c < r.length ? r[c] : '', base.copyWith(fontSize: 12), c > 0),
                  ]),
              ],
            ),
          ),
        ));
        continue;
      }
      final bullet = RegExp(r'^([-*•]|\d+[.)])\s+').firstMatch(t);
      if (bullet != null) {
        children.add(Padding(padding: const EdgeInsets.only(left: 2, bottom: 2), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(bullet.group(1)!.startsWith(RegExp(r'\d')) ? '${bullet.group(1)} ' : '•  ', style: base),
          Expanded(child: _rich(t.substring(bullet.end), base)),
        ])));
        i++;
        continue;
      }
      children.add(Padding(padding: const EdgeInsets.only(bottom: 4), child: _rich(t, base)));
      i++;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _cell(String v, TextStyle st, bool right) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Align(alignment: right ? Alignment.centerRight : Alignment.centerLeft, child: _rich(v, st)),
      );

  /// **bold**, _italic_ and [label](url) inside one line (links are shown as bold text).
  Widget _rich(String line, TextStyle st) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)\s]+)\)|(?<![A-Za-z0-9*])[_*]([^_*]+)[_*](?![A-Za-z0-9*])');
    var pos = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > pos) spans.add(TextSpan(text: line.substring(pos, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(text: m.group(2), style: const TextStyle(fontWeight: FontWeight.w700, color: kBlue)));
      } else {
        spans.add(TextSpan(text: m.group(4), style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54)));
      }
      pos = m.end;
    }
    if (pos < line.length) spans.add(TextSpan(text: line.substring(pos)));
    return Text.rich(TextSpan(children: spans, style: st));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeroGradient)),
        title: const Row(children: [Icon(Icons.auto_awesome, color: kYellow), SizedBox(width: 8), Text('AI Copilot')]),
        actions: [
          IconButton(tooltip: 'New chat', icon: const Icon(Icons.add_comment_outlined), onPressed: busy ? null : _newChat),
          IconButton(tooltip: 'Previous chats', icon: const Icon(Icons.history), onPressed: _history),
          IconButton(tooltip: 'Clear this chat', icon: const Icon(Icons.delete_outline), onPressed: busy || items.length <= 1 ? null : _clearChat),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: scroll,
            padding: const EdgeInsets.all(12),
            itemCount: items.length + (busy ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == items.length) return const Padding(padding: EdgeInsets.all(8), child: Text('Thinking…', style: TextStyle(color: Colors.black45)));
              final m = items[i];
              final mine = m['role'] == 'user';
              final src = {'database': '🗄 From your records', 'ai': '✨ AI model', 'error': '⚠'}[m['source']];
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .85),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: mine ? kBlue : Colors.white, borderRadius: BorderRadius.circular(14), border: mine ? null : Border.all(color: const Color(0xFFE6EAF2))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _md(m['content']!, mine),
                    if (!mine && src != null) Text(src, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ]),
                ),
              );
            },
          ),
        ),
        if (suggestions.isNotEmpty && items.length <= 1)
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
              for (final s in suggestions) Padding(padding: const EdgeInsets.only(right: 6), child: ActionChip(
                    avatar: const Icon(Icons.auto_awesome, size: 14, color: kBlue),
                    label: Text(s, style: const TextStyle(fontSize: 12, color: kBlue, fontWeight: FontWeight.w500)),
                    backgroundColor: const Color(0xFFEEF2FF),
                    side: const BorderSide(color: Color(0xFFC7D2FE)),
                    onPressed: () => _ask(s),
                  )),
            ]),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(child: TextField(controller: input, onSubmitted: _ask, textInputAction: TextInputAction.send, decoration: const InputDecoration(hintText: 'Ask anything…'))),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: () => _ask(input.text), icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
