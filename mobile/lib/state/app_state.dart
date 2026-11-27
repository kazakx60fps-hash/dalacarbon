// Қосымшаның ортақ күйі: пайдаланушы, басқару тақтасының деректері, оқылған хабарлар.
import 'package:flutter/foundation.dart';

import '../api/api.dart';

class AppState extends ChangeNotifier {
  AppState._();

  static final i = AppState._();

  Json? user;
  Json? dash; // /api/v1/dashboard жауабы
  final Set<String> readMessages = {};
  bool notifsRead = false;

  Json get data => (dash?['data'] as Json?) ?? const {};
  Json get numbers => (dash?['numbers'] as Json?) ?? const {};
  List<Json> list(String key) => ((dash?[key] as List?) ?? const []).cast<Json>();
  List<Json> get parcels => ((data['parcels'] as List?) ?? const []).cast<Json>();

  int get unreadMessages =>
      list('inbox').where((m) => m['unread'] == true && !readMessages.contains(m['id'])).length;
  int get unreadNotifs => notifsRead ? 0 : list('notifs').length;

  Future<void> loadDashboard() async {
    dash = await Api.instance.dashboard();
    user = dash?['user'] as Json?;
    notifyListeners();
  }

  void addParcel(Json p) {
    (data['parcels'] as List).add(p);
    notifyListeners();
  }

  void removeParcel(int id) {
    (data['parcels'] as List).removeWhere((p) => (p as Json)['id'] == id);
    notifyListeners();
  }

  void markRead(String id) {
    if (readMessages.add(id)) notifyListeners();
  }

  void markAllRead() {
    for (final m in list('inbox')) {
      readMessages.add(m['id'] as String);
    }
    notifyListeners();
  }

  void markNotifsRead() {
    notifsRead = true;
    notifyListeners();
  }

  void clear() {
    user = null;
    dash = null;
    readMessages.clear();
    notifsRead = false;
    notifyListeners();
  }
}
