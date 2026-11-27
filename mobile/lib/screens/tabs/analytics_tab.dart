// Талдау — сайттағы «Талдау» беті: KPI, 12 айлық секвестрация, 1 гектардан түсетін табыс (75 / 25).
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final user = s.user ?? const {};
    final n = s.numbers;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
        children: [
          const Text('Талдау', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('${user['region_label'] ?? ''} · ${user['farm_type_label'] ?? ''}', style: const TextStyle(color: Dc.muted)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Dc.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: const Text('Демо деректер', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF7A5200))),
            ),
          ]),
          const SizedBox(height: 16),
          Rise(index: 0, child: KpiGrid(numbers: n)),
          const SizedBox(height: 16),
          Rise(
            index: 1,
            child: Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SectionTitle('Ай сайынғы секвестрация', sub: 'т CO₂e'),
                const SizedBox(height: 8),
                SeriesChart(series: ((s.data['series'] as List?) ?? const []).cast<Json>(), initialRange: 12, height: 220),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Rise(index: 2, child: _IncomeCard(n: n)),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({required this.n});

  final Json n;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('1 гектардан түсетін табыс', sub: '15% буфер шегерілген'),
        const SizedBox(height: 12),
        Text.rich(TextSpan(children: [
          TextSpan(text: n['revenue_per_ha'] as String? ?? '', style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const TextSpan(text: '  / га / жыл', style: TextStyle(color: Dc.muted)),
        ])),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1300),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(children: [
                Expanded(flex: (750 * t).round() + 1, child: Container(color: Dc.gold)),
                const SizedBox(width: 3),
                Expanded(flex: (250 * t).round() + 1, child: Container(color: Dc.ink)),
                Expanded(flex: (1000 * (1 - t)).round() + 1, child: Container(color: Dc.input)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _row(Dc.gold, 'Фермер · 75%', n['farmer_per_ha'] as String? ?? ''),
        _row(Dc.ink, 'DalaCarbon AI · 25%', n['platform_per_ha'] as String? ?? ''),
        const SizedBox(height: 8),
        Text('${n['net_per_ha']} т CO₂e × ${n['price']} · Әдістеме: Verra VM0042 / VT0014 · RothC + ML',
            style: const TextStyle(fontSize: 12, color: Dc.muted)),
      ]),
    );
  }

  Widget _row(Color c, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          CircleAvatar(radius: 5, backgroundColor: c),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(color: Dc.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}
