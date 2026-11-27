// «Тағы» мәзірі және сайттағы қалған беттер: Кесте, Хабарлар, Белсенділік, Баптаулар.
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ui.dart';
import 'home_shell.dart';
import 'sheets.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key, required this.actions});

  final ShellActions actions;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (context, _) {
        final s = AppState.i;
        final user = s.user ?? const {};
        final tiles = [
          (Icons.calendar_month_outlined, 'Кесте', 'Сынама, спутник, кездесулер', () => actions.open(const ScheduleScreen()), 0),
          (Icons.inbox_outlined, 'Хабарлар', '${s.unreadMessages} оқылмаған', () => actions.open(const InboxScreen()), s.unreadMessages),
          (Icons.notifications_none_rounded, 'Хабарламалар', 'Спутник мен сынама жаңалықтары', () => showNotifications(context), s.unreadNotifs),
          (Icons.bolt_outlined, 'Белсенділік', 'Аккаунттағы соңғы оқиғалар', () => actions.open(const ActivityScreen()), 0),
          (Icons.description_outlined, 'MRV есебі', 'CSV мазмұны', () => showReport(context), 0),
          (Icons.search_rounded, 'Іздеу', 'Бетке өту немесе әрекет', actions.search, 0),
          (Icons.settings_outlined, 'Баптаулар', 'Профиль, сервер, шығу', () => actions.open(SettingsScreen(onLogout: actions.logout)), 0),
        ];
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Dc.green,
                  child: Text(s.dash?['initials'] as String? ?? 'DC',
                      style: const TextStyle(color: Dc.goldHi, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user['display_name'] as String? ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text(user['email'] as String? ?? '', style: const TextStyle(color: Dc.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              for (var i = 0; i < tiles.length; i++)
                Rise(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Dc.line)),
                        leading: CircleAvatar(backgroundColor: Dc.input, child: Icon(tiles[i].$1, color: Dc.green)),
                        title: Text(tiles[i].$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(tiles[i].$3, style: const TextStyle(fontSize: 12.5)),
                        trailing: tiles[i].$5 > 0
                            ? CircleAvatar(
                                radius: 11,
                                backgroundColor: Dc.gold,
                                child: Text('${tiles[i].$5}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Dc.ink)),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: tiles[i].$4,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Dc.danger,
                  side: const BorderSide(color: Dc.line),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: actions.logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Шығу', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
  }
}

AppBar _bar(String title) => AppBar(
      backgroundColor: Dc.paper,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );

// ---------- Кесте ----------
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late final DateTime _today = DateTime.tryParse(AppState.i.data['today'] as String? ?? '') ?? DateTime.now();
  late DateTime _sel = _today;

  @override
  Widget build(BuildContext context) {
    final events = (AppState.i.data['events'] as Json?) ?? const {};
    final first = DateTime(_today.year, _today.month, 1);
    final days = DateTime(_today.year, _today.month + 1, 0).day;
    final lead = first.weekday - 1;
    final items = ((events[isoDate(_sel)] as List?) ?? const []).cast<Json>();

    return Scaffold(
      backgroundColor: Dc.paper,
      appBar: _bar('Кесте'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Panel(
            child: Column(children: [
              Text('${monthsKk[_today.month - 1]} ${_today.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 10),
              Row(children: [
                for (final w in weekdaysShortKk)
                  Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 11.5, color: Dc.muted, fontWeight: FontWeight.w700)))),
              ]),
              const SizedBox(height: 6),
              GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                  for (var d = 1; d <= days; d++) _dayCell(DateTime(_today.year, _today.month, d), events),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('${weekdaysKk[_sel.weekday - 1]}, ${_sel.day} ${monthsKk[_sel.month - 1].toLowerCase()}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Column(
              key: ValueKey(isoDate(_sel)),
              children: items.isEmpty
                  ? [const Padding(padding: EdgeInsets.all(12), child: Text('Бұл күні жоспар жоқ', style: TextStyle(color: Dc.muted)))]
                  : [for (final e in items) EventTile(event: e)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime d, Json events) {
    final n = ((events[isoDate(d)] as List?) ?? const []).length;
    final active = isoDate(d) == isoDate(_sel);
    final today = isoDate(d) == isoDate(_today);
    return GestureDetector(
      onTap: () => setState(() => _sel = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: active ? Dc.gold : Dc.input,
          borderRadius: BorderRadius.circular(10),
          border: today && !active ? Border.all(color: Dc.gold, width: 1.5) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w800, color: today && !active ? Dc.gold : Dc.ink)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < n; i++)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.all(1),
                decoration: BoxDecoration(shape: BoxShape.circle, color: active ? Dc.ink : Dc.green2),
              ),
          ]),
        ]),
      ),
    );
  }
}

// ---------- Хабарлар ----------
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (context, _) {
        final s = AppState.i;
        final inbox = s.list('inbox');
        return Scaffold(
          backgroundColor: Dc.paper,
          appBar: AppBar(
            backgroundColor: Dc.paper,
            surfaceTintColor: Colors.transparent,
            title: const Text('Хабарлар', style: TextStyle(fontWeight: FontWeight.w800)),
            actions: [
              TextButton(onPressed: s.unreadMessages == 0 ? null : s.markAllRead, child: const Text('Барлығын оқу')),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            children: [
              Text('${s.unreadMessages} оқылмаған хат', style: const TextStyle(color: Dc.muted)),
              const SizedBox(height: 10),
              for (var i = 0; i < inbox.length; i++)
                Rise(
                  index: i,
                  child: _MessageTile(
                    m: inbox[i],
                    unread: inbox[i]['unread'] == true && !s.readMessages.contains(inbox[i]['id']),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.m, required this.unread});

  final Json m;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Dc.line)),
          leading: CircleAvatar(
            backgroundColor: Dc.green,
            child: Text((m['from'] as String).characters.first, style: const TextStyle(color: Dc.goldHi, fontWeight: FontWeight.w800)),
          ),
          title: Text(m['from'] as String, style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w500)),
          subtitle: Text(m['subject'] as String, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(m['time'] as String, style: const TextStyle(fontSize: 11.5, color: Dc.muted)),
            if (unread) const Padding(padding: EdgeInsets.only(top: 4), child: CircleAvatar(radius: 4, backgroundColor: Dc.gold)),
          ]),
          onTap: () {
            AppState.i.markRead(m['id'] as String);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => _Reader(m: m)));
          },
        ),
      ),
    );
  }
}

class _Reader extends StatelessWidget {
  const _Reader({required this.m});

  final Json m;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Dc.paper,
      appBar: _bar('Хат'),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(m['subject'] as String, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25)),
        const SizedBox(height: 6),
        Text('${m['from']} · ${m['time']}', style: const TextStyle(color: Dc.muted)),
        const SizedBox(height: 18),
        Text(m['body'] as String, style: const TextStyle(fontSize: 15.5, height: 1.6)),
      ]),
    );
  }
}

// ---------- Белсенділік ----------
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  static Color toneColor(String? t) => switch (t) {
        'mint' => Dc.green2,
        'clay' => const Color(0xFFC2553F),
        'gold' => Dc.gold,
        _ => Dc.ink,
      };

  @override
  Widget build(BuildContext context) {
    final items = AppState.i.list('activity');
    return Scaffold(
      backgroundColor: Dc.paper,
      appBar: _bar('Белсенділік'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          for (var i = 0; i < items.length; i++)
            Rise(
              index: i,
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Column(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: toneColor(items[i]['tone'] as String?).withValues(alpha: 0.14),
                      child: Icon(iconFor(items[i]['icon'] as String?), size: 18, color: toneColor(items[i]['tone'] as String?)),
                    ),
                    if (i < items.length - 1) Expanded(child: Container(width: 2, color: Dc.line)),
                  ]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18, top: 2),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(items[i]['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(items[i]['text'] as String, style: const TextStyle(color: Dc.muted, fontSize: 13)),
                        Text(items[i]['time'] as String, style: const TextStyle(color: Dc.muted, fontSize: 11.5)),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------- Баптаулар ----------
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final u = AppState.i.user ?? const {};
    final methods = ((u['login_methods'] as List?) ?? const []).map((m) => m == 'google' ? 'Google' : 'Құпиясөз').join(' + ');
    final rows = [
      ('Логин', '@${u['username'] ?? ''}'),
      ('Email', '${u['email'] ?? ''}'),
      ('Облыс', '${u['region_label'] ?? ''}'),
      ('Шаруашылық түрі', '${u['farm_type_label'] ?? ''}'),
      ('Кіру тәсілі', methods),
      ('Тіркелген күні', '${u['created_at'] ?? ''}'),
    ];
    return Scaffold(
      backgroundColor: Dc.paper,
      appBar: _bar('Баптаулар'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Panel(
            child: Column(children: [
              for (final (k, v) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Text(k, style: const TextStyle(color: Dc.muted)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Dc.line)),
              leading: const Icon(Icons.dns_outlined, color: Dc.green),
              title: const Text('Сервер мекенжайы', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(Api.instance.base),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                final changed = await showServerAddress(context);
                if (changed == true && context.mounted) toast(context, 'Келесі кіруде жаңа сервер қолданылады');
              },
            ),
          ),
          const SizedBox(height: 14),
          const Center(child: Opacity(opacity: 0.8, child: BrandRow(logo: 24, text: 15))),
          const SizedBox(height: 4),
          const Center(child: Text('Нұсқа 0.2 · сайтпен бір API', style: TextStyle(color: Dc.muted, fontSize: 12))),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Dc.danger,
              side: const BorderSide(color: Dc.line),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Аккаунттан шығу', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
