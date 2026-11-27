// Төменнен шығатын терезелер: хабарламалар, іздеу, есеп, алқап қосу, құпиясөзді қалпына келтіру, сервер мекенжайы.
import 'package:flutter/material.dart';

import '../api/api.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/ui.dart';

Future<T?> _sheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Dc.paper,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    ),
  );
}

IconData iconFor(String? name) => switch (name) {
      'satellite' => Icons.satellite_alt,
      'flask' => Icons.science_outlined,
      'check' => Icons.check_circle_outline_rounded,
      'leaf' => Icons.eco_outlined,
      'user' => Icons.person_outline_rounded,
      _ => Icons.notifications_none_rounded,
    };

// ---------- Хабарламалар ----------
Future<void> showNotifications(BuildContext context) => _sheet(context, const _Notifications());

class _Notifications extends StatelessWidget {
  const _Notifications();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (context, _) {
        final s = AppState.i;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('Хабарламалар',
                trailing: TextButton(
                  onPressed: s.notifsRead ? null : s.markNotifsRead,
                  child: const Text('Оқылды деп белгілеу'),
                )),
            const SizedBox(height: 10),
            for (final n in s.list('notifs'))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(left: BorderSide(color: s.notifsRead ? Dc.line : Dc.gold, width: 3)),
                ),
                child: Row(children: [
                  CircleAvatar(
                      radius: 17,
                      backgroundColor: Dc.gold.withValues(alpha: 0.16),
                      child: Icon(iconFor(n['icon'] as String?), size: 18, color: Dc.green)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(n['text'] as String, style: const TextStyle(fontSize: 12.5, color: Dc.muted)),
                    ]),
                  ),
                  Text(n['time'] as String, style: const TextStyle(fontSize: 11.5, color: Dc.muted)),
                ]),
              ),
          ]),
        );
      },
    );
  }
}

// ---------- Іздеу (сайттағы Ctrl+K палитрасы) ----------
class SearchItem {
  const SearchItem(this.icon, this.label, this.kind, this.action);

  final IconData icon;
  final String label;
  final String kind; // 'Бет' / 'Әрекет'
  final VoidCallback action;
}

Future<void> showSearchSheet(BuildContext context, List<SearchItem> items) => _sheet(context, _Search(items));

class _Search extends StatefulWidget {
  const _Search(this.items);

  final List<SearchItem> items;

  @override
  State<_Search> createState() => _SearchState();
}

class _SearchState extends State<_Search> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final found = widget.items.where((i) => q.isEmpty || i.label.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Бетке өту немесе әрекет…', prefixIcon: Icon(Icons.search_rounded)),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: found.isEmpty
                ? const Center(child: Text('Ештеңе табылмады', style: TextStyle(color: Dc.muted)))
                : ListView(children: [
                    for (final i in found)
                      ListTile(
                        leading: Icon(i.icon, color: Dc.green),
                        title: Text(i.label),
                        trailing: Text(i.kind, style: const TextStyle(fontSize: 12, color: Dc.muted)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () {
                          Navigator.pop(context);
                          i.action();
                        },
                      ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ---------- CSV есеп ----------
Future<void> showReport(BuildContext context) => _sheet(context, const _Report());

class _Report extends StatelessWidget {
  const _Report();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: FutureBuilder<String>(
        future: Api.instance.reportCsv(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}', textAlign: TextAlign.center));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Dc.green));
          final rows = snap.data!.split(RegExp(r'\r?\n')).map((l) => l.split(';')).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const SectionTitle('MRV есебі', sub: 'Сайттағы CSV есептің мазмұны · Excel үшін сайттан жүктеңіз'),
              const SizedBox(height: 12),
              for (final r in rows)
                if (r.every((c) => c.trim().isEmpty))
                  const SizedBox(height: 12)
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: Text(r.first, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      for (final c in r.skip(1))
                        Expanded(
                          flex: 2,
                          child: Text(c, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12.5, color: Dc.muted)),
                        ),
                    ]),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// ---------- Алқап қосу ----------
Future<Json?> showAddParcel(BuildContext context) => _sheet<Json>(context, const _AddParcel());

class _AddParcel extends StatefulWidget {
  const _AddParcel();

  @override
  State<_AddParcel> createState() => _AddParcelState();
}

class _AddParcelState extends State<_AddParcel> {
  final _name = TextEditingController();
  final _area = TextEditingController();
  String? _crop;
  String? _practice;
  final Map<String, String> _errors = {};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors.clear();
    });
    try {
      final p = await Api.instance.addParcel({
        'name': _name.text,
        'area_ha': _area.text,
        'crop': _crop ?? '',
        'practice': _practice ?? '',
      });
      AppState.i.addParcel(p);
      if (mounted) Navigator.pop(context, p);
    } on ApiException catch (e) {
      setState(() => _errors.addAll(e.errors.isEmpty ? {'name': e.message} : e.errors));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final crops = s.list('crops');
    final practices = s.list('practices');
    final net = (s.data['netPerHa'] as num?) ?? 0.6375;
    final price = (s.data['price'] as num?) ?? 16;
    final share = (s.data['farmerShare'] as num?) ?? 0.75;
    final area = double.tryParse(_area.text.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
    final tonnes = area * net;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Жаңа алқап', sub: 'Секвестрация мен табыс бірден есептеледі'),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          maxLength: 60,
          decoration: InputDecoration(hintText: 'Атауы, мысалы: Солтүстік алқап', errorText: _errors['name'], counterText: ''),
          onChanged: (_) => setState(() => _errors.remove('name')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _area,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'Ауданы, га', errorText: _errors['area_ha'], suffixText: 'га'),
          onChanged: (_) => setState(() => _errors.remove('area_ha')),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _crop,
          decoration: InputDecoration(hintText: 'Дақыл', errorText: _errors['crop']),
          items: [for (final c in crops) DropdownMenuItem(value: c['key'] as String, child: Text(c['label'] as String))],
          onChanged: (v) => setState(() {
            _crop = v;
            _errors.remove('crop');
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _practice,
          decoration: InputDecoration(hintText: 'Тәжірибе', errorText: _errors['practice']),
          items: [for (final p in practices) DropdownMenuItem(value: p['key'] as String, child: Text(p['label'] as String))],
          onChanged: (v) => setState(() {
            _practice = v;
            _errors.remove('practice');
          }),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Dc.green2.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Text(
            area > 0
                ? 'Бағалау: ${fmtNum(tonnes)} т CO₂e/жыл · фермерге ${money(roundHalfEven(tonnes * price * share))}'
                : 'Бағалау: — т CO₂e/жыл · фермерге —',
            style: const TextStyle(color: Dc.green, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Dc.green,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Сақталуда…' : 'Сақтау'),
        ),
      ]),
    );
  }
}

// ---------- Құпиясөзді қалпына келтіру ----------
Future<void> showForgot(BuildContext context) => _sheet(context, const _Forgot());

class _Forgot extends StatefulWidget {
  const _Forgot();

  @override
  State<_Forgot> createState() => _ForgotState();
}

class _ForgotState extends State<_Forgot> {
  final _email = TextEditingController();
  String? _error;
  String? _done;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await Api.instance.forgot(_email.text);
      setState(() => _done = msg);
    } on ApiException catch (e) {
      setState(() => _error = e.errors['email'] ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Құпиясөзді қалпына келтіру', sub: 'Тіркелген email-ге бір реттік сілтеме жібереміз (30 минут)'),
        const SizedBox(height: 16),
        if (_done != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Dc.green2.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.mark_email_read_outlined, color: Dc.green),
              const SizedBox(width: 10),
              Expanded(child: Text(_done!, style: const TextStyle(color: Dc.green, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 8),
          const Text('Сілтемені ашып, жаңа құпиясөзді сайтта орнатыңыз, сосын осы жерден кіріңіз.',
              style: TextStyle(color: Dc.muted, fontSize: 12.5)),
        ] else ...[
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(hintText: 'you@example.kz', prefixIcon: const Icon(Icons.mail_outline_rounded), errorText: _error),
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Dc.green,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _busy ? null : _send,
            child: Text(_busy ? 'Жіберілуде…' : 'Сілтеме жіберу'),
          ),
        ],
      ]),
    );
  }
}

// ---------- Сервер мекенжайы ----------
Future<bool?> showServerAddress(BuildContext context) => _sheet<bool>(context, const _Server());

class _Server extends StatefulWidget {
  const _Server();

  @override
  State<_Server> createState() => _ServerState();
}

class _ServerState extends State<_Server> {
  late final _ctrl = TextEditingController(text: Api.instance.base);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Сервер мекенжайы',
            sub: 'Эмулятор: http://10.0.2.2:5000 · Телефон: компьютердің Wi-Fi IP-і, мысалы http://192.168.1.5:5000'),
        const SizedBox(height: 14),
        TextField(controller: _ctrl, keyboardType: TextInputType.url, decoration: const InputDecoration(prefixIcon: Icon(Icons.dns_outlined))),
        const SizedBox(height: 14),
        Row(children: [
          TextButton(onPressed: () => _ctrl.text = Api.defaultBase, child: const Text('Әдепкі')),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Dc.green),
            onPressed: () async {
              await Api.instance.setBase(_ctrl.text);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Сақтау'),
          ),
        ]),
      ]),
    );
  }
}
