// Role-based module registry. The server decides WHICH modules a user gets
// (GET /modules); this file decides how each one looks and opens.
// Developed & Powered by Marian Anbu Juwan
import 'package:flutter/material.dart';

import 'api.dart';

import 'screens/admin.dart';
import 'screens/ai_insights.dart';
import 'screens/attendance.dart';
import 'screens/copilot.dart';
import 'screens/dashboard.dart';
import 'screens/driver_trip.dart';
import 'screens/messages.dart';
import 'screens/modules_admin.dart';
import 'screens/modules_business.dart';
import 'screens/modules_field.dart';
import 'screens/modules_fleet.dart';
import 'screens/more.dart';
import 'screens/payments.dart';
import 'screens/tracking.dart';
import 'ui.dart';

class AppModule {
  final String key;
  final String title;
  final String group;
  const AppModule(this.key, this.title, this.group);
  factory AppModule.fromJson(Map m) => AppModule(m['key'].toString(), m['title'].toString(), (m['group'] ?? 'Other').toString());
}

class ModuleDef {
  final IconData icon;
  final List<Color> colors;

  /// Builds the page. [bare] pages have no Scaffold and get the gradient bar.
  final Widget Function()? page;
  final bool bare;

  /// Badge key from GET /modules → counts.
  final String? badge;
  const ModuleDef(this.icon, this.colors, this.page, {this.bare = false, this.badge});
}

final Map<String, ModuleDef> kModules = {
  // overview / platform
  'dashboard': ModuleDef(Icons.space_dashboard_outlined, gIndigo, () => const AdminDashboard(), bare: true),
  'schools': ModuleDef(Icons.apartment_rounded, gBlue, () => const SchoolsScreen()),
  // people
  'approvals': ModuleDef(Icons.how_to_reg_outlined, gOrange, () => const ApprovalsScreen(), bare: true, badge: 'approvals'),
  'students': ModuleDef(Icons.groups_rounded, gBlue, () => const ClassesScreen()),
  'classes': ModuleDef(Icons.class_outlined, gTeal, () => const ClassesScreen()),
  'siblings': ModuleDef(Icons.diversity_3_rounded, gPink, () => const SiblingsScreen()),
  'people': ModuleDef(Icons.people_alt_outlined, gViolet, () => const PeopleScreen()),
  'drivers': ModuleDef(Icons.badge_outlined, gCyan, () => const DriversScreen()),
  'years': ModuleDef(Icons.calendar_month_outlined, gIndigo, () => const YearsScreen()),
  // transport
  'tracking': ModuleDef(Icons.my_location_rounded, gGreen, () => const TrackingScreen(), bare: true),
  'bus_routes': ModuleDef(Icons.alt_route_rounded, gOrange, () => const BusRoutesScreen()),
  'vehicles': ModuleDef(Icons.directions_bus_filled_outlined, gBlue, () => const VehiclesScreen()),
  'assignments': ModuleDef(Icons.link_rounded, gSlate, () => const AssignmentsScreen()),
  'attendance': ModuleDef(Icons.fact_check_outlined, gTeal, () => const AdminAttendanceScreen()),
  'cctv': ModuleDef(Icons.videocam_outlined, gRed, () => const CamerasScreen()),
  'cards': ModuleDef(Icons.contactless_outlined, gViolet, () => const CardsScreen()),
  'sos': ModuleDef(Icons.emergency_outlined, gRed, () => const SosListScreen(), badge: 'sos'),
  'trips': ModuleDef(Icons.history_rounded, gIndigo, () => const TripsScreen()),
  'incidents': ModuleDef(Icons.car_crash_outlined, gRed, () => const IncidentsScreen(), badge: 'incidents'),
  'maintenance': ModuleDef(Icons.build_circle_outlined, gSlate, () => const MaintenanceScreen(), badge: 'service'),
  'safety': ModuleDef(Icons.speed_rounded, gOrange, () => const SafetyScreen(), badge: 'safety'),
  'substitutes': ModuleDef(Icons.person_pin_circle_outlined, gTeal, () => const SubstitutesScreen()),
  // finance & comms
  'fees': ModuleDef(Icons.currency_rupee_rounded, gGreen, () => const PaymentsScreen(), bare: true, badge: 'verify'),
  'broadcast': ModuleDef(Icons.campaign_outlined, gOrange, () => const BroadcastScreen()),
  'subscription': ModuleDef(Icons.workspace_premium_outlined, gIndigo, () => const SubscriptionScreen(), badge: 'subscription'),
  'reports': ModuleDef(Icons.insert_chart_outlined_rounded, gCyan, () => const ReportsScreen()),
  'logs': ModuleDef(Icons.manage_history_rounded, gSlate, () => const LogsScreen()),
  'messages': ModuleDef(Icons.forum_outlined, gBlue, () => const ThreadsScreen(), bare: true, badge: 'messages'),
  'notifications': ModuleDef(Icons.notifications_none_rounded, gOrange, () => const NotificationsScreen()),
  'copilot': ModuleDef(Icons.auto_awesome, gPink, () => const CopilotScreen()),
  'ai_insights': ModuleDef(Icons.psychology_alt_rounded, gViolet, () => const AiInsightsScreen(), badge: 'ai'),
  'sos_send': const ModuleDef(Icons.sos, gRed, null),
  // parent
  'children': ModuleDef(Icons.child_care_rounded, gPink, () => const ParentDashboard(), bare: true),
  'child_attendance': ModuleDef(Icons.event_available_outlined, gTeal, () => const ChildAttendanceScreen()),
  'passes': ModuleDef(Icons.qr_code_2_rounded, gIndigo, () => const PassesScreen()),
  // driver
  'trip': ModuleDef(Icons.play_circle_outline_rounded, gGreen, () => const DriverTripPicker(), bare: true),
  'scan': ModuleDef(Icons.qr_code_scanner_rounded, gViolet, () => const ScanScreen()),
  'driver_attendance': ModuleDef(Icons.checklist_rounded, gTeal, () => const DriverTripPicker(), bare: true),
  'my_vehicle': ModuleDef(Icons.directions_bus_outlined, gOrange, () => const MyVehicleScreen()),
};

ModuleDef defFor(String key) => kModules[key] ?? ModuleDef(Icons.widgets_outlined, gSlate, () => EmptyState(Icons.widgets_outlined, 'Update the app to use “$key”.'), bare: true);

Future<void> openModule(BuildContext context, AppModule m) async {
  final d = defFor(m.key);
  if (m.key == 'sos_send') return sendSos(context);
  if (d.page == null) return;
  final fab = m.key == 'fees' && Api.I.isAdmin
      ? Builder(builder: (c) => FloatingActionButton.extended(
          onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const InvoiceScreen())),
          icon: const Icon(Icons.receipt_long), label: const Text('New invoice')))
      : null;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => d.bare ? ModulePage(title: m.title, fab: fab, child: d.page!()) : d.page!()));
}

/// Grid of module tiles grouped by section — the "All modules" launcher.
class ModuleGrid extends StatelessWidget {
  final List<AppModule> modules;
  final Map counts;
  final bool grouped;
  final VoidCallback? onReturn;
  const ModuleGrid({super.key, required this.modules, this.counts = const {}, this.grouped = true, this.onReturn});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AppModule>>{};
    for (final m in modules) {
      groups.putIfAbsent(grouped ? m.group : '', () => []).add(m);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in groups.entries) ...[
        if (e.key.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(18, 14, 18, 2), child: Text(e.key.toUpperCase(), style: const TextStyle(fontSize: 10.5, letterSpacing: 1.2, color: kMuted, fontWeight: FontWeight.w600))),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          childAspectRatio: .82,
          children: [
            for (final m in e.value)
              ModuleTile(
                title: m.title,
                icon: defFor(m.key).icon,
                colors: defFor(m.key).colors,
                badge: (counts[defFor(m.key).badge] as int?) ?? 0,
                onTap: () async { await openModule(context, m); onReturn?.call(); },
              ),
          ],
        ),
      ],
    ]);
  }
}
