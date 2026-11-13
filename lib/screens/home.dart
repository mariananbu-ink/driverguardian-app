// App shell: gradient home with KPI carousel and role-based module launcher,
// slide-out drawer menu, bottom navigation, notification polling.
// Developed & Powered by Marian Anbu Juwan
import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../modules.dart';
import '../push.dart';
import '../ui.dart';
import '../web/web_banner.dart';
import '../widgets/announcement_banner.dart';
import 'dashboard.dart';
import 'login.dart';
import 'messages.dart';
import 'modules_admin.dart' show SchoolsScreen;
import 'more.dart';
import 'permissions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final scaffold = GlobalKey<ScaffoldState>();
  int tab = 0;
  List<AppModule> modules = [];
  Map counts = {};
  Map<String, dynamic>? dash;
  String? school;
  String? year;
  Object? error;
  int unreadNotes = 0;
  int lastSeen = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    Push.register();
    // ask for location / camera / notifications / battery once, right after the first sign-in
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) AppPermissions.maybeShow(context); });
    Api.I.refreshMe().then((_) { if (mounted) setState(() {}); }).catchError((_) {});
    _load();
    _poll(first: true);
    timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Api.I.get('/modules'), Api.I.get('/dashboard')]);
      if (!mounted) return;
      setState(() {
        modules = (r[0]['modules'] as List).cast<Map>().map(AppModule.fromJson).toList();
        counts = (r[0]['counts'] as Map?) ?? {};
        school = r[0]['school'] as String?;
        year = r[0]['academic_year'] as String?;
        dash = r[1];
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _poll({bool first = false}) async {
    if (Api.I.token == null) return;
    try {
      final d = await Api.I.get('/notifications');
      final list = (d['notifications'] as List).cast<Map>();
      final newest = list.isEmpty ? 0 : (list.first['id'] as int);
      if (!first && (!Push.available || Push.token == null) && newest > lastSeen) {
        final fresh = list.where((n) => (n['id'] as int) > lastSeen && n['read'] != true).toList();
        if (fresh.isNotEmpty && mounted) toast(context, '🔔 ${fresh.first['title']}: ${fresh.first['body'] ?? ''}');
      }
      lastSeen = newest > lastSeen ? newest : lastSeen;
      // school announcements flash on every screen until closed or marked read
      if (mounted) Announcements.update(ScaffoldMessenger.maybeOf(context), list);
      if (mounted) setState(() => unreadNotes = d['unread'] as int? ?? 0);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    await Future.wait([_load(), _poll()]);
  }

  Future<void> _open(AppModule m) async {
    await openModule(context, m);
    _refresh();
  }

  Future<void> _switchSchool() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => SchoolsScreen(onEntered: () {})));
    setState(() { dash = null; modules = []; });
    _refresh();
  }

  Future<void> _leaveSchool() async {
    await Api.I.setSchool(null);
    setState(() { dash = null; modules = []; });
    _refresh();
  }

  Future<void> _signOut() async {
    ScaffoldMessenger.maybeOf(context)?.clearMaterialBanners();
    await Api.I.logout(pushToken: Push.token);
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = (counts['messages'] as int?) ?? 0;
    final pages = [
      _homeTab(),
      _modulesTab(),
      const ThreadsScreen(),
      AccountScreen(onSwitchSchool: Api.I.isSuper ? _switchSchool : null, onSignOut: _signOut),
    ];
    return Scaffold(
      key: scaffold,
      drawer: _drawer(),
      appBar: tab == 0 ? null : dgBar(['Home', 'All modules', 'Messages', 'Account'][tab]),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: KeyedSubtree(key: ValueKey(tab), child: pages[tab])),
      floatingActionButton: tab == 0 && Api.I.user?['copilot'] == true && modules.any((m) => m.key == 'copilot')
          ? FloatingActionButton(
              tooltip: 'AI Copilot',
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              onPressed: () => _open(modules.firstWhere((m) => m.key == 'copilot')),
              child: const Icon(Icons.auto_awesome),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) { setState(() => tab = i); if (i == 0) _refresh(); },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps_rounded), label: 'Modules'),
          NavigationDestination(icon: Badge(isLabelVisible: msgs > 0, label: Text('$msgs'), child: const Icon(Icons.forum_outlined)), selectedIcon: const Icon(Icons.forum_rounded), label: 'Messages'),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }

  /* ---------------------------------------------------------------- drawer */
  Widget _drawer() {
    final u = Api.I.user ?? {};
    final groups = <String, List<AppModule>>{};
    for (final m in modules) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }
    return Drawer(
      width: 300,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 20),
          decoration: const BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.only(topRight: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Avatar(u['name']?.toString() ?? '?', size: 54, colors: const [Colors.white30, Colors.white10]),
            const SizedBox(height: 12),
            Text(u['name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('${u['role_label'] ?? ''} · ${u['login'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w300)),
            const SizedBox(height: 10),
            Glass(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              radius: 12,
              child: Row(children: [
                const Icon(Icons.school_outlined, color: Colors.white, size: 15),
                const SizedBox(width: 6),
                Expanded(child: Text(school ?? 'Platform — all schools', style: const TextStyle(color: Colors.white, fontSize: 11.5), overflow: TextOverflow.ellipsis)),
                if (year != null) Text(year!, style: const TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
          _dItem(Icons.home_rounded, 'Home', () => setState(() => tab = 0), selected: tab == 0),
          for (final g in groups.entries) ...[
            Padding(padding: const EdgeInsets.fromLTRB(22, 14, 22, 4), child: Text(g.key.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: kMuted, fontWeight: FontWeight.w600))),
            for (final m in g.value) _dItem(defFor(m.key).icon, m.title, () => _open(m), badge: (counts[defFor(m.key).badge] as int?) ?? 0, colors: defFor(m.key).colors),
          ],
          const Divider(height: 24),
          if (Api.I.isSuper) _dItem(Icons.swap_horiz_rounded, 'Switch school', _switchSchool),
          if (Api.I.isSuper && Api.I.schoolId != null) _dItem(Icons.public, 'Back to platform view', _leaveSchool),
          _dItem(Icons.logout_rounded, 'Sign out', _signOut, danger: true),
        ])),
        const Padding(padding: EdgeInsets.all(12), child: Text('DriverGuardian $kVersion · $kCredit', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: kMuted))),
      ]),
    );
  }

  Widget _dItem(IconData icon, String title, VoidCallback onTap, {int badge = 0, bool selected = false, bool danger = false, List<Color>? colors}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
        child: ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: kBlue.withValues(alpha: .08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: colors != null ? GradientIcon(icon, colors, size: 30) : Icon(icon, color: danger ? Colors.red : kBlue, size: 22),
          title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: danger ? Colors.red : kInk)),
          trailing: badge > 0 ? Badge(label: Text('$badge')) : null,
          onTap: () { Navigator.pop(context); onTap(); },
        ),
      );

  /* ---------------------------------------------------------------- home tab */
  Widget _homeTab() {
    final u = Api.I.user ?? {};
    final role = Api.I.role;
    final quick = modules.where((m) => !['messages', 'notifications', 'copilot'].contains(m.key)).take(7).toList();
    final ks = dash == null ? <Kpi>[] : kpisFor(dash!);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: Stack(children: [
          Container(
            margin: EdgeInsets.only(bottom: ks.isNotEmpty ? 56 : 0),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 8, 16, 70),
            decoration: const BoxDecoration(gradient: kHeroGradient, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.menu_rounded, color: Colors.white), onPressed: () => scaffold.currentState?.openDrawer()),
                const SizedBox(width: 2),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DriverGuardian', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(school ?? 'Platform — all schools', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w300), overflow: TextOverflow.ellipsis),
                ])),
                if (role == 'driver' || role == 'parent')
                  IconButton(tooltip: 'SOS', icon: const Icon(Icons.sos, color: Color(0xFFFF8A8A)), onPressed: () => sendSos(context)),
                IconButton(
                  tooltip: 'Notifications',
                  icon: Badge(isLabelVisible: unreadNotes > 0, label: Text('$unreadNotes'), child: const Icon(Icons.notifications_none_rounded, color: Colors.white)),
                  onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())); _poll(); },
                ),
              ]),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${greeting()},', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w300)),
                    Text(firstName(u['name']?.toString()), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700, height: 1.15)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _pill(Icons.verified_user_outlined, u['role_label']?.toString() ?? ''),
                      if (year != null) _pill(Icons.calendar_month_outlined, 'Session $year'),
                    ]),
                  ])),
                  GestureDetector(onTap: () => setState(() => tab = 3), child: Avatar(u['name']?.toString() ?? '?', size: 54, colors: const [Color(0xFFFDE68A), kYellow])),
                ]),
              ),
            ]),
          ),
          if (ks.isNotEmpty)
            Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: ks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => SizedBox(width: 168, child: ks[i]),
              ),
            )),
        ])),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        const SliverToBoxAdapter(child: WebAppBanner()),
        if (error != null && modules.isEmpty)
          SliverToBoxAdapter(child: Column(children: [
            EmptyState(Icons.cloud_off, errText(error!)),
            OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]))
        else if (modules.isEmpty)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))))
        else ...[
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: SectionTitle('Quick access', trailing: TextButton(onPressed: () => setState(() => tab = 1), child: const Text('All modules'))),
          )),
          SliverToBoxAdapter(child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: kLine)),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              childAspectRatio: .82,
              children: [
                for (final m in quick)
                  ModuleTile(title: m.title, icon: defFor(m.key).icon, colors: defFor(m.key).colors, badge: (counts[defFor(m.key).badge] as int?) ?? 0, onTap: () => _open(m)),
                ModuleTile(title: 'More', icon: Icons.grid_view_rounded, colors: gSlate, onTap: () => setState(() => tab = 1)),
              ],
            ),
          )),
          ..._roleSection(role),
          if (Api.I.isSuper && Api.I.schoolId == null)
            SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Card(child: ListTile(
                leading: const GradientIcon(Icons.apartment_rounded, gBlue, size: 40),
                title: const Text('Work inside a school'),
                subtitle: const Text('Open a school to manage its students, buses, cards and fees.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _switchSchool,
              )),
            )),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ]),
    );
  }

  Widget _pill(IconData i, String t) => Glass(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        radius: 20,
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, color: Colors.white, size: 13), const SizedBox(width: 5), Text(t, style: const TextStyle(color: Colors.white, fontSize: 11))]),
      );

  List<Widget> _roleSection(String role) {
    final d = dash;
    if (d == null) return [];
    Widget pad(Widget w) => SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: w));
    if (role == 'parent') {
      final kids = (d['children'] as List? ?? const []).cast<Map>();
      return [
        pad(const SectionTitle('My children')),
        if (kids.isEmpty) pad(const EmptyState(Icons.child_care, 'No children are linked to your account yet.')),
        for (final k in kids) pad(KidCard(k)),
      ];
    }
    if (role == 'driver') {
      final rs = (d['routes'] as List? ?? const []).cast<Map>();
      return [
        pad(const SectionTitle('Today’s routes')),
        if (rs.isEmpty) pad(const EmptyState(Icons.alt_route, 'No routes are assigned to you yet.')),
        for (final r in rs) pad(DriverRouteCard(r)),
      ];
    }
    final k = (d['kpi'] as Map?) ?? const {};
    final alerts = <Widget>[
      if (((counts['sos'] as int?) ?? 0) > 0) _alert(Icons.emergency, gRed, '${counts['sos']} open SOS alert(s)', 'sos'),
      if (((k['pending_approvals'] as int?) ?? 0) > 0) _alert(Icons.how_to_reg, gOrange, '${k['pending_approvals']} sign-up(s) waiting for approval', 'approvals'),
      if (((k['to_verify'] as int?) ?? 0) > 0) _alert(Icons.receipt_long, gGreen, '${k['to_verify']} UPI payment(s) to verify', 'fees'),
    ];
    return [
      if (alerts.isNotEmpty) ...[pad(const SectionTitle('Needs attention')), for (final a in alerts) pad(a)],
      if (d['months'] is List) ...[pad(const SectionTitle('Fee collection — last 6 months')), pad(FeeChart((d['months'] as List).cast<Map>()))],
    ];
  }

  Widget _alert(IconData icon, List<Color> g, String text, String key) {
    final m = modules.where((x) => x.key == key).firstOrNull;
    return Card(child: ListTile(
      leading: GradientIcon(icon, g, size: 38),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: m == null ? null : () => _open(m),
    ));
  }

  /* ---------------------------------------------------------------- modules tab */
  Widget _modulesTab() => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.only(top: 6, bottom: 90), children: [
          if (modules.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(strokeWidth: 2.4))),
          ModuleGrid(modules: modules, counts: counts, onReturn: _refresh),
        ]),
      );
}
