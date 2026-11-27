// Ортақ UI бөлшектері: карта, бөлім тақырыбы, KPI, оқиға жолы, ай күнтізбесі, кезекпен шығу анимациясы.
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../theme.dart';
import '../util/format.dart';

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.color = Colors.white});

  final Widget child;
  final EdgeInsets padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Dc.line),
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.sub, this.trailing});

  final String title;
  final String? sub;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Dc.ink)),
          if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12.5, color: Dc.muted)),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// KPI картасы: сан 0-ден мәніне дейін «санап» шығады.
class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.format,
    required this.note,
    this.hot = false,
  });

  final IconData icon;
  final String label;
  final num value;
  final String Function(num) format;
  final String note;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final fg = hot ? Colors.white : Dc.ink;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: hot ? const LinearGradient(colors: [Color(0xFF1E6A4C), Dc.green]) : null,
        color: hot ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: hot ? null : Border.all(color: Dc.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: hot ? Colors.white.withValues(alpha: 0.16) : Dc.input,
            child: Icon(icon, size: 17, color: hot ? Dc.goldHi : Dc.green),
          ),
        ]),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 1400),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(format(v), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: fg, letterSpacing: -0.6)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, maxLines: 2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        Text(note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: hot ? Colors.white.withValues(alpha: 0.72) : Dc.muted)),
      ]),
    );
  }
}

/// Пилоттық сценарийдің төрт KPI-ы (Шолу мен Талдау беттерінде).
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.numbers});

  final Json numbers;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        KpiCard(icon: Icons.crop_square_rounded, label: 'Пилоттық алаң, га', value: numbers['area_raw'] as num? ?? 0,
            format: fmtInt, note: 'Базалық сценарий'),
        KpiCard(icon: Icons.cloud_outlined, label: 'Таза секвестрация, т CO₂e/жыл', value: numbers['net_raw'] as num? ?? 0,
            format: fmtInt, note: '15% буферден кейін'),
        KpiCard(icon: Icons.payments_outlined, label: 'Фермер табысы / жыл', value: numbers['farmer_raw'] as num? ?? 0,
            format: money, note: 'Түсімнің 75%-ы', hot: true),
        KpiCard(icon: Icons.signal_cellular_alt_rounded, label: 'Деректер толықтығы', value: 99.2,
            format: (v) => '${fmtNum(v)}%', note: 'Sentinel-2 · 30 күн'),
      ],
    );
  }
}

class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event});

  final Json event;

  static Color colorOf(String? kind) => switch (kind) {
        'sat' => const Color(0xFF5B7BD5),
        'meet' => Dc.gold,
        _ => Dc.green2,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Dc.input, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        SizedBox(
          width: 46,
          child: Text(event['time'] as String,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Dc.muted)),
        ),
        Container(width: 3, height: 34, color: colorOf(event['kind'] as String?)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            Row(children: [
              const Icon(Icons.place_outlined, size: 13, color: Dc.muted),
              const SizedBox(width: 3),
              Text(event['place'] as String, style: const TextStyle(fontSize: 12, color: Dc.muted)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Тізім элементтерінің кезекпен шығуы.
class Rise extends StatelessWidget {
  const Rise({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// Бүкіл экранға «жүктелуде / қате» күйі.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 46, color: Dc.muted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Dc.ink, height: 1.45)),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Dc.green),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Қайта көру'),
          ),
        ]),
      ),
    );
  }
}
