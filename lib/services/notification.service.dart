// ============================================================
//  services/notification.service.dart
//  Notifications locales avec flutter_local_notifications
//  Rappels d'étude hebdomadaires (jours + heure choisis)
// ============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialise = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'rappels_etude',           // channel id
    "Rappels d'étude",         // channel name
    channelDescription: 'Rappels pour réviser avec StudyScan',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  // ---- Initialiser le plugin (appelé une fois dans main.dart) ----
  Future<void> init() async {
    if (_initialise) return;
    tz_data.initializeTimeZones();

    final InitializationSettings settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _initialise = true;
  }

  // ---- Demander l'autorisation (Android 13+), au moment d'activer les rappels ----
  Future<bool> demanderPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final bool? accordee = await android?.requestNotificationsPermission();
    return accordee ?? true;
  }

  // ---- Planifier les rappels : chaque jour choisi, à l'heure choisie ----
  // jours : 7 booléens, index 0 = dimanche, 1 = lundi, …, 6 = samedi
  Future<void> planifierRappel({
    required int heure,
    required int minute,
    required List<bool> jours,
  }) async {
    await init();
    await _plugin.cancelAll();

    for (int i = 0; i < 7; i++) {
      if (!jours[i]) continue;

      await _plugin.zonedSchedule(
        id: i, // un identifiant par jour de la semaine
        title: "📚 C'est l'heure d'étudier !",
        body: 'Ouvre StudyScan et révise tes documents scannés.',
        scheduledDate: _prochaineOccurrence(i, heure, minute),
        notificationDetails: _details,
        // Pas besoin de la permission "alarmes exactes" :
        // le rappel peut arriver avec quelques minutes de décalage
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // Répéter chaque semaine, même jour et même heure
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rappels_actives', jours.contains(true));
    await prefs.setInt('rappel_heure', heure);
    await prefs.setInt('rappel_minute', minute);
    await prefs.setStringList(
        'rappel_jours', jours.map((j) => j ? '1' : '0').toList());
  }

  // Prochaine date (dans le futur) qui tombe le jour [indexJour] à heure:minute.
  // Calculée en heure locale puis convertie en UTC : la répétition
  // hebdomadaire se fait donc à la même heure (sans gestion de l'heure d'été,
  // inutile en Tunisie).
  tz.TZDateTime _prochaineOccurrence(int indexJour, int heure, int minute) {
    // DateTime.weekday : lundi = 1 … dimanche = 7
    final int jourVoulu = indexJour == 0 ? DateTime.sunday : indexJour;
    final DateTime maintenant = DateTime.now();

    DateTime date = DateTime(
        maintenant.year, maintenant.month, maintenant.day, heure, minute);
    while (date.weekday != jourVoulu || !date.isAfter(maintenant)) {
      date = DateTime(date.year, date.month, date.day + 1, heure, minute);
    }
    return tz.TZDateTime.from(date, tz.UTC);
  }

  // ---- Notification immédiate (bouton "Tester") ----
  Future<void> afficherNotificationTest() async {
    await init();
    await _plugin.show(
      id: 99,
      title: "📚 C'est l'heure d'étudier !",
      body: 'Ouvre StudyScan et révise tes documents scannés.',
      notificationDetails: _details,
    );
  }

  // ---- Annuler tous les rappels ----
  Future<void> annulerTousRappels() async {
    await init();
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rappels_actives', false);
  }

  // ---- Charger l'état des rappels depuis SharedPreferences ----
  Future<Map<String, dynamic>> chargerEtatRappels() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jours = prefs.getStringList('rappel_jours');
    return {
      'actives': prefs.getBool('rappels_actives') ?? false,
      'heure':   prefs.getInt('rappel_heure')     ?? 20,
      'minute':  prefs.getInt('rappel_minute')    ?? 0,
      // Par défaut : du lundi au vendredi
      'jours': jours != null && jours.length == 7
          ? jours.map((j) => j == '1').toList()
          : [false, true, true, true, true, true, false],
    };
  }
}
