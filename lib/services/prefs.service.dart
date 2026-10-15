// ============================================================
//  services/prefs.service.dart
//  shared_preferences : points de gamification
//  (les autres réglages sont lus directement par les pages)
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  // ---- Points gamification ----
  Future<void> addPoints(int points) async {
    if (points <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final int actuel = prefs.getInt('points') ?? 0;
    await prefs.setInt('points', actuel + points);
  }

  Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('points') ?? 0;
  }
}
