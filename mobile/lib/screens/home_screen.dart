// Басты бет: сәлемдесу, іздеу, маусым баннері, жылдық табыс картасы, қызметтер, төменгі мәзір.
// Сандар — сайттағы пилоттық сценарий (демо): 5 000 га, 3 188 т CO₂e, фермерге $38 250.
import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/fade_route.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.name});

  final String name;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  int _tab = 0;

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String get _initials {
    final parts = widget.name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final letters = parts.take(2).map((p) => p.characters.first.toUpperCase()).join();
    return letters.isEmpty ? 'DC' : letters;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Қайырлы таң,';
    if (h >= 12 && h < 18) return 'Қайырлы күн,';
    if (h >= 18 && h < 23) return 'Қайырлы кеш,';
    return 'Қайырлы түн,';
  }

  Widget _stagger(int i, Widget child) {
    final start = (i * 0.09).clamp(0.0, 0.7).toDouble();
    final anim = CurvedAnimation(
      parent: _intro,
      curve: Interval(start, (start + 0.35).clamp(0.0, 1.0).toDouble(), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.18), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Dc.paper,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_tab) {
          0 => _home(),
          1 => const _Placeholder(key: ValueKey(1), icon: Icons.map_outlined, title: 'NDVI картасы',
              text: 'Алқаптарыңыздың спутниктік картасы келесі нұсқада — сайттағыдай Sentinel-2 / MODIS.'),
          2 => const _Placeholder(key: ValueKey(2), icon: Icons.insert_chart_outlined_rounded, title: 'Есептер',
              text: 'Ай сайынғы секвестрация және табыс есебі (CSV) келесі нұсқада.'),
          _ => _profile(),
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: Colors.white,
        indicatorColor: Dc.gold.withValues(alpha: 0.25),
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Басты'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Карта'),
          NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined_rounded), selectedIcon: Icon(Icons.insert_chart_rounded), label: 'Есептер'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Профиль'),
        ],
      ),
    );
  }

  Widget _home() {
    return Container(
      key: const ValueKey(0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment(0, -0.2),
          colors: [Color(0xFFF7E9CC), Dc.paper],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            _stagger(0, _header()),
            const SizedBox(height: 18),
            _stagger(1, _search()),
            const SizedBox(height: 18),
            _stagger(2, _promo()),
            const SizedBox(height: 18),
            _stagger(3, _income()),
            const SizedBox(height: 24),
            _stagger(4, _servicesTitle()),
            const SizedBox(height: 12),
            _stagger(5, _services()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(children: [
      CircleAvatar(
        radius: 23,
        backgroundColor: Dc.green,
        child: Text(_initials, style: const TextStyle(color: Dc.goldHi, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_greeting, style: const TextStyle(color: Dc.muted, fontSize: 13)),
          Text(widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Dc.ink, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ),
      Stack(clipBehavior: Clip.none, children: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          tooltip: 'Хабарламалар',
          onPressed: () => _toast('Жаңа спутник суреті: 4 учаске бойынша NDVI жаңартылды'),
          icon: const Icon(Icons.notifications_none_rounded, color: Dc.ink),
        ),
        const Positioned(
          right: 10,
          top: 9,
          child: CircleAvatar(radius: 4.5, backgroundColor: Dc.danger),
        ),
      ]),
    ]);
  }

  Widget _search() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Алқап, есеп немесе қызмет іздеу',
        prefixIcon: const Icon(Icons.search_rounded),
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Dc.line),
        ),
      ),
      onSubmitted: (q) => _toast(q.trim().isEmpty ? 'Іздеу сөзін жазыңыз' : '«${q.trim()}» бойынша іздеу келесі нұсқада'),
    );
  }

  Widget _promo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 12, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Dc.green, Color(0xFF1E6A4C)]),
        boxShadow: [BoxShadow(color: Dc.green.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('2026 маусымы',
                  style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            const Text('Топырақ сынамасын\nалдын ала жоспарлаңыз',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
            const SizedBox(height: 6),
            Text('Агроном алқапқа келіп, 12 нүктеден сынама алады',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Dc.gold,
                foregroundColor: Dc.ink,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _toast('Сынама алу өтінімі қабылданды (демо)'),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.arrow_forward_rounded, size: 17),
              label: const Text('Жазылу', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
        const SizedBox(width: 6),
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          alignment: Alignment.center,
          child: const LogoMark(size: 60, color: Dc.cream),
        ),
      ]),
    );
  }

  Widget _income() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Dc.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Жылдық табыс', style: TextStyle(color: Dc.muted, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: Dc.green2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.trending_up_rounded, size: 15, color: Dc.green2),
              SizedBox(width: 3),
              Text('5%', style: TextStyle(color: Dc.green2, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        const Text.rich(TextSpan(children: [
          TextSpan(text: r'$38 250', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
          TextSpan(text: '  / жыл', style: TextStyle(fontSize: 13, color: Dc.muted)),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          _pill(Icons.description_outlined, 'Есеп', () => _toast('CSV есеп сайттан жүктеледі: /dashboard/report.csv')),
          const SizedBox(width: 8),
          _pill(Icons.add_rounded, 'Алқап', () => _toast('Алқап қосу келесі нұсқада (сайтта бар)')),
          const SizedBox(width: 8),
          _pill(Icons.more_horiz_rounded, 'Тағы', () => _toast('Қосымша әрекеттер келесі нұсқада')),
        ]),
        const SizedBox(height: 16),
        const Divider(color: Dc.line, height: 1),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _mini(Icons.eco_rounded, Dc.green2, 'Секвестрация', '3 188 т CO₂e')),
          Expanded(child: _mini(Icons.crop_square_rounded, Dc.gold, 'Пилоттық алаң', '5 000 га')),
        ]),
      ]),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: Dc.input,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 18, color: Dc.ink),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _mini(IconData icon, Color color, String label, String value) {
    return Row(children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: color.withValues(alpha: 0.14),
        child: Icon(icon, size: 18, color: color),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Dc.muted, fontSize: 11.5)),
        Text(value, style: const TextStyle(color: Dc.ink, fontWeight: FontWeight.w800, fontSize: 14)),
      ]),
    ]);
  }

  Widget _servicesTitle() {
    return Row(children: [
      const Text('Қызметтер', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Dc.ink)),
      const Spacer(),
      TextButton(
        onPressed: () => _toast('Барлық қызметтер тізімі келесі нұсқада'),
        child: const Text('Барлығы', style: TextStyle(color: Dc.green2, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  Widget _services() {
    const items = [
      (Icons.satellite_alt, 'NDVI'),
      (Icons.science_outlined, 'Сынама'),
      (Icons.grid_view_rounded, 'Алқаптар'),
      (Icons.eco_outlined, 'Кредит'),
      (Icons.wb_sunny_outlined, 'Ауа райы'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (icon, label) in items)
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _toast('«$label» бөлімі келесі нұсқада'),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Dc.line),
                  ),
                  child: Icon(icon, color: Dc.green, size: 26),
                ),
                const SizedBox(height: 6),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Dc.ink)),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _profile() {
    return SafeArea(
      key: const ValueKey(3),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 40,
            backgroundColor: Dc.green,
            child: Text(_initials, style: const TextStyle(color: Dc.goldHi, fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 14),
          Text(widget.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Демо аккаунт · Ақмола облысы', style: TextStyle(color: Dc.muted)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Dc.danger,
                side: const BorderSide(color: Dc.line),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                fadeRoute(const LoginScreen()),
                (route) => false,
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Шығу', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key, required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: Dc.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(24)),
              child: Icon(icon, size: 36, color: Dc.green),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Dc.muted, height: 1.45)),
          ]),
        ),
      ),
    );
  }
}
