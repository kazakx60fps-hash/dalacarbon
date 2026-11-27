// Шолу — сайттағы «Шолу» беті: сәлемдесу, маусым картасы (68%), апта күнтізбесі, KPI, жылдам әрекеттер,
// секвестрация графигі (3/6/12 ай), учаскелер сақинасы.
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/charts.dart';
import '../../widgets/ui.dart';
import '../home_shell.dart';
import '../more_screens.dart';
import '../sheets.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.actions});

  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (context, _) {
        final s = AppState.i;
        final dash = s.dash!;
        final user = s.user ?? const {};
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment(0, -0.4), colors: [Color(0xFFF7E9CC), Dc.paper]),
          ),
          child: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: Dc.green,
              onRefresh: actions.reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
                children: [
                  Rise(index: 0, child: _header(context, dash, user, s)),
                  const SizedBox(height: 16),
                  Rise(index: 1, child: _searchBar()),
                  const SizedBox(height: 16),
                  Rise(index: 2, child: _hero()),
                  const SizedBox(height: 16),
                  Rise(index: 3, child: _WeekCard(events: (s.data['events'] as Json?) ?? const {}, today: s.data['today'] as String?)),
                  const SizedBox(height: 16),
                  Rise(index: 4, child: KpiGrid(numbers: s.numbers)),
                  const SizedBox(height: 20),
                  const SectionTitle('Жылдам әрекеттер'),
                  const SizedBox(height: 10),
                  Rise(index: 5, child: _quick(context, s)),
                  const SizedBox(height: 20),
                  Rise(
                    index: 6,
                    child: Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionTitle('Көміртегі жинақталуы', sub: 'т CO₂e · өлшенген және болжам'),
                        const SizedBox(height: 8),
                        SeriesChart(series: ((s.data['series'] as List?) ?? const []).cast<Json>()),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Rise(
                    index: 7,
                    child: Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionTitle('Учаскелер бойынша', sub: 'Таза секвестрация · бөлікті таңдаңыз'),
                        const SizedBox(height: 12),
                        Center(child: SplitDonut(split: ((s.data['split'] as List?) ?? const []).cast<Json>())),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, Json dash, Json user, AppState s) {
    final unread = s.unreadNotifs;
    return Row(children: [
      CircleAvatar(
        radius: 23,
        backgroundColor: Dc.green,
        child: Text(dash['initials'] as String? ?? 'DC', style: const TextStyle(color: Dc.goldHi, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${dash['greeting'] ?? 'Сәлем'},', style: const TextStyle(color: Dc.muted, fontSize: 13)),
          Text(user['display_name'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Dc.ink, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
      ),
      Stack(clipBehavior: Clip.none, children: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(backgroundColor: Colors.white),
          tooltip: 'Хабарламалар',
          onPressed: () => showNotifications(context),
          icon: const Icon(Icons.notifications_none_rounded, color: Dc.ink),
        ),
        if (unread > 0)
          Positioned(
            right: 6,
            top: 4,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Dc.danger,
              child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    ]);
  }

  Widget _searchBar() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: actions.search,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Dc.line)),
          child: const Row(children: [
            Icon(Icons.search_rounded, color: Dc.muted),
            SizedBox(width: 12),
            Expanded(child: Text('Іздеу немесе өту…', style: TextStyle(color: Dc.muted))),
          ]),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Dc.green, Color(0xFF1E6A4C)]),
        boxShadow: [BoxShadow(color: Dc.green.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
          child: const Text('2026 маусымы · 4 учаске бақылауда',
              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Алқаптарыңыз биыл жақсы нәтиже көрсетуде',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, height: 1.25)),
              SizedBox(height: 6),
              Text('MRV жоспарының 68%-ы орындалды, үш учаске верификацияға дайын.',
                  style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5, height: 1.4)),
            ]),
          ),
          const SizedBox(width: 10),
          const ProgressRing(value: 0.68, size: 104),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final (v, l) in const [('4', 'учаске'), ('12', 'сынама'), ('98%', 'уақытында')])
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(v, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(l, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 11.5)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Dc.ink),
            onPressed: () => actions.open(const ScheduleScreen()),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Жоспар'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x8CFFFFFF))),
            onPressed: actions.addParcel,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Алқап қосу'),
          ),
        ]),
      ]),
    );
  }

  Widget _quick(BuildContext context, AppState s) {
    final items = [
      (Icons.add_rounded, 'Алқап қосу', 'Жаңа учаске', actions.addParcel),
      (Icons.satellite_alt, 'Спутник', 'NDVI қабаты', () async => actions.goTab(3)),
      (Icons.description_outlined, 'MRV есебі', 'CSV мазмұны', () async => showReport(context)),
      (Icons.mail_outline_rounded, 'Хабарлар', '${s.unreadMessages} оқылмаған', () async => actions.open(const InboxScreen())),
      (Icons.calendar_month_outlined, 'Кесте', 'Айдың жоспары', () async => actions.open(const ScheduleScreen())),
      (Icons.bolt_outlined, 'Белсенділік', 'Соңғы оқиғалар', () async => actions.open(const ActivityScreen())),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.6,
      children: [
        for (final (icon, title, sub, onTap) in items)
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Dc.line)),
                child: Row(children: [
                  CircleAvatar(radius: 17, backgroundColor: Dc.input, child: Icon(icon, size: 18, color: Dc.green)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11.5, color: Dc.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Апта күнтізбесі: күнді басса — сол күннің оқиғалары.
class _WeekCard extends StatefulWidget {
  const _WeekCard({required this.events, required this.today});

  final Json events;
  final String? today;

  @override
  State<_WeekCard> createState() => _WeekCardState();
}

class _WeekCardState extends State<_WeekCard> {
  late final DateTime _today = DateTime.tryParse(widget.today ?? '') ?? DateTime.now();
  late DateTime _sel = _today;

  @override
  Widget build(BuildContext context) {
    final monday = _today.subtract(Duration(days: _today.weekday - 1));
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final items = ((widget.events[isoDate(_sel)] as List?) ?? const []).cast<Json>();
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(_sel.day.toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Dc.gold, height: 1)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(weekdaysKk[_sel.weekday - 1], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${monthsKk[_sel.month - 1]} ${_sel.year} · ${items.length} оқиға',
                  style: const TextStyle(color: Dc.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: Dc.input, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _sel = days[i]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isoDate(days[i]) == isoDate(_sel) ? Dc.gold : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      Text(weekdaysShortKk[i],
                          style: TextStyle(fontSize: 11, color: isoDate(days[i]) == isoDate(_sel) ? Dc.ink : Dc.muted)),
                      Text('${days[i].day}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (widget.events[isoDate(days[i])] as List?)?.isNotEmpty == true ? Dc.green : Colors.transparent,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Column(
            key: ValueKey(isoDate(_sel)),
            children: items.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Бұл күні жоспар жоқ', style: TextStyle(color: Dc.muted)),
                    ),
                  ]
                : [for (final e in items) EventTile(event: e)],
          ),
        ),
      ]),
    );
  }
}
