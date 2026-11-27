// Алқаптар — сайттағы «Алқаптар» беті: PostgreSQL-дегі нақты учаскелер, қосу және өшіру (API арқылы).
import 'package:flutter/material.dart';

import '../../api/api.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../util/format.dart';
import '../../widgets/ui.dart';
import '../home_shell.dart';

class ParcelsTab extends StatelessWidget {
  const ParcelsTab({super.key, required this.actions});

  final ShellActions actions;

  Future<void> _delete(BuildContext context, Json p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Алқапты өшіру'),
        content: Text('«${p['name']}» алқабы дерекқордан өшіріледі. Бұл әрекетті қайтару мүмкін емес.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Болдырмау')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Dc.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Өшіру'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await Api.instance.deleteParcel(p['id'] as int);
      AppState.i.removeParcel(p['id'] as int);
      if (context.mounted) toast(context, '«${p['name']}» алқабы өшірілді');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.i,
      builder: (context, _) {
        final parcels = AppState.i.parcels;
        num sum(String k) => parcels.fold<num>(0, (a, p) => a + (p[k] as num));
        return Scaffold(
          backgroundColor: Dc.paper,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Dc.green,
            foregroundColor: Colors.white,
            onPressed: actions.addParcel,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Алқап қосу'),
          ),
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 96),
              children: [
                const Text('Менің алқаптарым', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text('Дерекқорда сақталады · бағалау ${fmtNum((AppState.i.data['netPerHa'] as num?) ?? 0, 4)} т CO₂e/га/жыл',
                    style: const TextStyle(color: Dc.muted)),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  children: [
                    _sum('Учаскелер', '${parcels.length}'),
                    _sum('Жалпы аудан', '${fmtNum(sum('area_ha'))} га'),
                    _sum('Секвестрация / жыл', '${fmtNum(sum('tonnes'))} т'),
                    _sum('Фермер табысы / жыл', money(sum('farmer_usd')), hot: true),
                  ],
                ),
                const SizedBox(height: 16),
                if (parcels.isEmpty)
                  Panel(
                    child: Column(children: [
                      const Icon(Icons.layers_outlined, size: 40, color: Dc.gold),
                      const SizedBox(height: 8),
                      const Text('Әзірге алқап жоқ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 4),
                      const Text('Алғашқы учаскеңізді қосыңыз — секвестрация мен табыс бірден есептеледі.',
                          textAlign: TextAlign.center, style: TextStyle(color: Dc.muted)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Dc.green),
                        onPressed: actions.addParcel,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Алқап қосу'),
                      ),
                    ]),
                  )
                else
                  for (var i = 0; i < parcels.length; i++)
                    Rise(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Panel(
                          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                          child: Row(children: [
                            CircleAvatar(
                              radius: 21,
                              backgroundColor: Dc.green2.withValues(alpha: 0.12),
                              child: const Icon(Icons.spa_outlined, color: Dc.green2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(parcels[i]['name'] as String,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                Text('${parcels[i]['crop']} · ${parcels[i]['practice']}',
                                    maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5, color: Dc.muted)),
                                const SizedBox(height: 6),
                                Text(
                                  '${fmtNum(parcels[i]['area_ha'] as num)} га · ${fmtNum(parcels[i]['tonnes'] as num)} т CO₂e · ${money(parcels[i]['farmer_usd'] as num)}/жыл',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Dc.green),
                                ),
                              ]),
                            ),
                            IconButton(
                              tooltip: 'Өшіру',
                              icon: const Icon(Icons.delete_outline_rounded, color: Dc.muted),
                              onPressed: () => _delete(context, parcels[i]),
                            ),
                          ]),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sum(String label, String value, {bool hot = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hot ? Dc.green : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: hot ? null : Border.all(color: Dc.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: hot ? Colors.white70 : Dc.muted)),
        FittedBox(
          child: Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: hot ? Colors.white : Dc.ink)),
        ),
      ]),
    );
  }
}
