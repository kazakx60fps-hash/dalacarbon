// Кіргеннен кейінгі қабық: деректерді жүктейді (бұлдыр жүктелу анимациясымен) және төменгі мәзір.
// Бөлімдер — сайттағы басқару тақтасының беттері: Шолу, Талдау, Алқаптар, Карта, Тағы (Кесте, Хабарлар,
// Белсенділік, Баптаулар).
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/fade_route.dart';
import '../widgets/scan_loading.dart';
import '../widgets/ui.dart';
import 'login_screen.dart';
import 'more_screens.dart';
import 'sheets.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/map_tab.dart';
import 'tabs/overview_tab.dart';
import 'tabs/parcels_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final started = DateTime.now();
    try {
      await AppState.i.loadDashboard();
      // Жүктелу анимациясы бір сәт те болса көрінсін
      final wait = const Duration(milliseconds: 1200) - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    } on ApiException catch (e) {
      if (e.status == 401) return _expired(e.message);
      _error = e.message;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _expired(String message) async {
    await Api.instance.clearToken();
    AppState.i.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(LoginScreen(notice: message)), (r) => false);
  }

  Future<void> logout() async {
    await Api.instance.logout();
    AppState.i.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const LoginScreen()), (r) => false);
  }

  void goTab(int i) => setState(() => _tab = i);

  void open(Widget screen) => Navigator.of(context).push(fadeRoute(screen, ms: 350));

  List<SearchItem> get searchItems => [
        SearchItem(Icons.home_outlined, 'Шолу', 'Бет', () => goTab(0)),
        SearchItem(Icons.insert_chart_outlined_rounded, 'Талдау', 'Бет', () => goTab(1)),
        SearchItem(Icons.grid_view_rounded, 'Алқаптар', 'Бет', () => goTab(2)),
        SearchItem(Icons.map_outlined, 'NDVI картасы', 'Бет', () => goTab(3)),
        SearchItem(Icons.calendar_month_outlined, 'Кесте', 'Бет', () => open(const ScheduleScreen())),
        SearchItem(Icons.inbox_outlined, 'Хабарлар', 'Бет', () => open(const InboxScreen())),
        SearchItem(Icons.bolt_outlined, 'Белсенділік', 'Бет', () => open(const ActivityScreen())),
        SearchItem(Icons.settings_outlined, 'Баптаулар', 'Бет', () => open(SettingsScreen(onLogout: logout))),
        SearchItem(Icons.add_rounded, 'Алқап қосу', 'Әрекет', addParcel),
        SearchItem(Icons.description_outlined, 'MRV есебі (CSV)', 'Әрекет', () => showReport(context)),
        SearchItem(Icons.notifications_none_rounded, 'Хабарламалар', 'Әрекет', () => showNotifications(context)),
      ];

  Future<void> addParcel() async {
    final p = await showAddParcel(context);
    if (p != null && mounted) {
      toast(context, '«${p['name']}» алқабы қосылды');
      goTab(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ShellActions(
      goTab: goTab,
      open: open,
      addParcel: addParcel,
      search: () => showSearchSheet(context, searchItems),
      logout: logout,
      reload: _load,
    );
    Widget body;
    if (_error != null) {
      body = LoadError(message: _error!, onRetry: _load);
    } else if (AppState.i.dash == null) {
      body = const SizedBox.shrink();
    } else {
      body = IndexedStack(index: _tab, children: [
        OverviewTab(actions: actions),
        const AnalyticsTab(),
        ParcelsTab(actions: actions),
        const MapTab(),
        MoreTab(actions: actions),
      ]);
    }

    return Scaffold(
      backgroundColor: Dc.paper,
      body: Stack(children: [
        Positioned.fill(child: body),
        if (_loading) const Positioned.fill(child: ScanLoading()),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: Dc.gold.withValues(alpha: 0.25),
        onDestinationSelected: goTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Шолу'),
          NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined_rounded), selectedIcon: Icon(Icons.insert_chart_rounded), label: 'Талдау'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Алқаптар'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Карта'),
          NavigationDestination(icon: Icon(Icons.menu_rounded), selectedIcon: Icon(Icons.menu_open_rounded), label: 'Тағы'),
        ],
      ),
    );
  }
}

/// Бөлімдерге берілетін әрекеттер (басқа бөлімге өту, экран ашу, т.б.).
class ShellActions {
  const ShellActions({
    required this.goTab,
    required this.open,
    required this.addParcel,
    required this.search,
    required this.logout,
    required this.reload,
  });

  final void Function(int) goTab;
  final void Function(Widget) open;
  final Future<void> Function() addParcel;
  final VoidCallback search;
  final Future<void> Function() logout;
  final Future<void> Function() reload;
}
