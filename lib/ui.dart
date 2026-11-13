// DriverGuardian mobile — design system: theme, gradients & shared widgets.
// Developed & Powered by Marian Anbu Juwan
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

const kNavy = Color(0xFF0F1535);
const kInk = Color(0xFF141B3D);
const kBlue = Color(0xFF4F46E5);
const kSky = Color(0xFF0EA5E9);
const kYellow = Color(0xFFF6B40E);
const kBg = Color(0xFFF4F6FB);
const kMuted = Color(0xFF6B7280);
const kLine = Color(0xFFE7EAF3);
const kCredit = 'Developed & Powered by Marian Anbu Juwan';
const kVersion = '2.12.0';

/// Hero gradient used on headers, the login screen and the drawer.
const kHeroGradient = LinearGradient(
  colors: [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF0EA5E9)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kBlue, primary: kBlue, secondary: kSky, surface: Colors.white);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  // Thin, compact type: Plus Jakarta Sans, light body weight, smaller sizes.
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
    titleLarge: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: kInk),
    titleMedium: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: kInk),
    titleSmall: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
    bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: kInk),
    bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w400, color: kInk),
    bodySmall: GoogleFonts.plusJakartaSans(fontSize: 11.5, fontWeight: FontWeight.w300, color: kMuted),
    labelLarge: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: kBg,
    appBarTheme: AppBarTheme(
      backgroundColor: kInk,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 16.5, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: kLine)),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: kInk),
      subtitleTextStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w300, color: kMuted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kLine)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kBlue, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(labelStyle: const TextStyle(fontSize: 12, color: kInk), backgroundColor: Colors.white, selectedColor: kBlue.withValues(alpha: .14), secondaryLabelStyle: const TextStyle(fontSize: 12, color: kBlue), side: const BorderSide(color: kLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: Colors.white,
      indicatorColor: kBlue.withValues(alpha: .12),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400)),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w400),
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: kSky,
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), textStyle: GoogleFonts.plusJakartaSans(fontSize: 13.5, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(48, 44), side: const BorderSide(color: kLine), textStyle: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: kInk, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: ZoomPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}),
  );
}

/// Gradient app bar used by every module page.
AppBar dgBar(String title, {String? subtitle, List<Widget>? actions, PreferredSizeWidget? bottom}) => AppBar(
      title: subtitle == null
          ? Text(title)
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title),
              Text(subtitle, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w300, color: Colors.white70)),
            ]),
      actions: actions,
      bottom: bottom,
      flexibleSpace: Container(decoration: const BoxDecoration(gradient: kHeroGradient)),
    );

/// Wraps a body-only widget in a page with the gradient bar.
class ModulePage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? fab;
  const ModulePage({super.key, required this.title, required this.child, this.actions, this.fab});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: dgBar(title, actions: actions), body: child, floatingActionButton: fab);
}

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String inr(num? v) => _inr.format(v ?? 0);

Color hexColor(String? hex, [Color fallback = kBlue]) {
  if (hex == null || !RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? Colors.red.shade200 : Colors.greenAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
    ));
}

/// Opens a payment / checkout page outside the app. In the web app (iPhone
/// Safari) a page opened after a network call is blocked as a pop-up, so the
/// user taps a button to open it.
Future<bool> openCheckout(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (!kIsWeb) return launchUrl(uri, mode: LaunchMode.externalApplication);
  final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
    icon: const Icon(Icons.lock_outline, color: kBlue, size: 34),
    title: const Text('Secure payment page'),
    content: const Text('The payment opens in a new tab. Come back to DriverGuardian when it is done.'),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
      FilledButton(onPressed: () { launchUrl(uri, mode: LaunchMode.externalApplication); Navigator.pop(c, true); }, child: const Text('Open payment page')),
    ],
  ));
  return ok == true;
}

String errText(Object e) => e is ApiException ? e.message : 'Something went wrong. Please try again.';

/* ------------------------------------------------------------------ gradients */
const gBlue = [Color(0xFF4F46E5), Color(0xFF6366F1)];
const gGreen = [Color(0xFF059669), Color(0xFF34D399)];
const gOrange = [Color(0xFFF59E0B), Color(0xFFF97316)];
const gPink = [Color(0xFFDB2777), Color(0xFF9333EA)];
const gCyan = [Color(0xFF0891B2), Color(0xFF22D3EE)];
const gRed = [Color(0xFFDC2626), Color(0xFFF87171)];
const gSlate = [Color(0xFF334155), Color(0xFF64748B)];
const gTeal = [Color(0xFF0D9488), Color(0xFF2DD4BF)];
const gViolet = [Color(0xFF7C3AED), Color(0xFFA78BFA)];
const gIndigo = [Color(0xFF312E81), Color(0xFF6366F1)];

/// Gradient KPI tile (dashboards).
class Kpi extends StatelessWidget {
  final String label;
  final String value;
  final String? meta;
  final IconData icon;
  final List<Color> colors;
  const Kpi({super.key, required this.label, required this.value, this.meta, required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: colors.first.withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Stack(children: [
        Positioned(right: -10, top: -10, child: Container(width: 56, height: 56, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .12)))),
        Positioned(right: 4, bottom: 0, child: Icon(icon, size: 34, color: Colors.white.withValues(alpha: .35))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: .8)),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
          if (meta != null) Text(meta!, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 11, fontWeight: FontWeight.w300), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ]),
    );
  }
}

/// Compact white stat card with a coloured icon — used in "quick stats" strips.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> colors;
  final String? hint;
  const StatCard(this.label, this.value, this.icon, this.colors, {super.key, this.hint});
  @override
  Widget build(BuildContext context) => Container(
        width: 138,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: kLine)),
        child: Row(children: [
          GradientIcon(icon, colors, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: kMuted, fontWeight: FontWeight.w400)),
            if (hint != null) Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 9.5, color: colors.first)),
          ])),
        ]),
      );
}

/// Horizontal strip of [StatCard]s.
class StatStrip extends StatelessWidget {
  final List<StatCard> cards;
  const StatStrip(this.cards, {super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 74,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(14, 0, 4, 0), children: cards),
      );
}

/// Rounded-square gradient icon (module launcher, stat cards).
class GradientIcon extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;
  const GradientIcon(this.icon, this.colors, {super.key, this.size = 48});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .32),
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: colors.first.withValues(alpha: .3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Icon(icon, color: Colors.white, size: size * .48),
      );
}

/// Launcher tile: gradient icon + label + optional badge.
class ModuleTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> colors;
  final int badge;
  final VoidCallback onTap;
  const ModuleTile({super.key, required this.title, required this.icon, required this.colors, required this.onTap, this.badge = 0});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Badge(isLabelVisible: badge > 0, label: Text('$badge'), offset: const Offset(4, -4), child: GradientIcon(icon, colors, size: 50)),
            const SizedBox(height: 7),
            Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}

/// Frosted glass panel (on gradient backgrounds).
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 18});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(radius), border: Border.all(color: Colors.white.withValues(alpha: .22))),
            child: child,
          ),
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String? status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status ?? '—';
    final c = switch (s) {
      'active' || 'paid' || 'boarded' || 'resolved' || 'live' || 'entry' || 'promoted' || 'online' => Colors.green,
      'dropped' || 'exit' || 'graduated' => Colors.blue,
      'pending' || 'leave' || 'on_leave' || 'retained' || 'unknown' => Colors.orange,
      'submitted' => Colors.cyan,
      'absent' || 'rejected' || 'open' || 'suspended' || 'denied' || 'blocked' || 'lost' || 'overdue' || 'offline' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Text(s.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: c.shade700, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
    );
  }
}

/// Expiry chip for documents: red when expired, amber within 30 days.
class ExpiryChip extends StatelessWidget {
  final String label;
  final String? date;
  final int? days;
  const ExpiryChip(this.label, this.date, this.days, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = days == null ? Colors.blueGrey : (days! < 0 ? Colors.red : (days! <= 30 ? Colors.orange : Colors.green));
    final txt = date == null ? 'not set' : (days! < 0 ? 'expired ${-days!}d ago' : (days! <= 30 ? '$days d left' : DateFormat('d MMM yy').format(DateTime.parse(date!))));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: .25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: kMuted)),
        Text(txt, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.shade700)),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(shape: BoxShape.circle, color: kBlue.withValues(alpha: .07)),
            child: Icon(icon, size: 36, color: kBlue.withValues(alpha: .5)),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontWeight: FontWeight.w300)),
        ]),
      );
}

/// Loads data with pull-to-refresh, error and empty handling.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  const Loader({super.key, required this.load, required this.builder});
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  T? data;
  Object? error;
  bool busy = true;

  Future<void> reload() async {
    setState(() => busy = data == null);
    try {
      final d = await widget.load();
      if (mounted) setState(() { data = d; error = null; busy = false; });
    } catch (e) {
      if (mounted) setState(() { error = e; busy = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  Widget build(BuildContext context) {
    if (busy && data == null) return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.4)));
    if (error != null && data == null) {
      return ListView(children: [
        EmptyState(Icons.cloud_off, errText(error!)),
        Center(child: OutlinedButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Retry'))),
      ]);
    }
    return RefreshIndicator(onRefresh: reload, child: widget.builder(context, data as T, reload));
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Row(children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), gradient: const LinearGradient(colors: [kBlue, kSky], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Label / value row inside detail cards.
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  const InfoRow(this.icon, this.label, this.value, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 17, color: kBlue.withValues(alpha: .7)),
          const SizedBox(width: 10),
          SizedBox(width: 92, child: Text(label, style: const TextStyle(fontSize: 12, color: kMuted))),
          Expanded(child: Text((value == null || value!.isEmpty) ? '—' : value!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Search box that calls [onSearch] on submit / clear.
class SearchBox extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onSearch;
  const SearchBox({super.key, required this.hint, required this.onSearch});
  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final c = TextEditingController();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: TextField(
          controller: c,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) => widget.onSearch(v.trim()),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () { c.clear(); widget.onSearch(''); }),
          ),
        ),
      );
}

class Avatar extends StatelessWidget {
  final String name;
  final double size;
  final List<Color>? colors;
  const Avatar(this.name, {super.key, this.size = 40, this.colors});
  static const _palette = [gBlue, gPink, gTeal, gOrange, gViolet, gCyan];
  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(p[0])).take(2).map((p) => p[0].toUpperCase()).join();
    final g = colors ?? _palette[name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Text(parts.isEmpty ? '?' : parts, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: size * .36)),
    );
  }
}

/// Tabs on the gradient app bar.
PreferredSizeWidget dgTabs(List<String> tabs) => TabBar(isScrollable: tabs.length > 3, tabAlignment: tabs.length > 3 ? TabAlignment.start : null, tabs: [for (final t in tabs) Tab(text: t, height: 40)]);

String firstName(String? name) {
  final n = (name ?? '').replaceFirst(RegExp(r'^(mr|mrs|ms|miss|dr|smt|shri|sri)\.?\s+', caseSensitive: false), '').trim();
  return n.isEmpty ? (name ?? '') : n.split(' ').first;
}

String greeting() {
  final h = DateTime.now().hour;
  return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
}
