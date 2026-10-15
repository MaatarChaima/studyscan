// ============================================================
//  main.dart  –  Point d'entrée de StudyScan
//  MaterialApp, routes nommées, Firebase, notifications locales
// ============================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart'; // généré par `flutterfire configure`
import 'services/auth.service.dart';
import 'services/notification.service.dart';
import 'utils/route_observer.dart';
import 'pages/home.page.dart';
import 'pages/scan.page.dart';
import 'pages/ocr_result.page.dart';
import 'pages/insights.page.dart';
import 'pages/quiz.page.dart';
import 'pages/library.page.dart';
import 'pages/settings.page.dart';
import 'pages/login.page.dart';
import 'pages/register.page.dart';

Future<void> main() async {
  // Requis pour utiliser les plugins natifs avant runApp()
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().init();

  // La route de départ est choisie AVANT de construire l'application :
  // MaterialApp ne lit initialRoute qu'une seule fois.
  final bool estConnecte = await AuthService().estConnecte();

  runApp(StudyScanApp(routeInitiale: estConnecte ? '/' : '/login'));
}

class StudyScanApp extends StatelessWidget {
  final String routeInitiale;

  const StudyScanApp({super.key, this.routeInitiale = '/login'});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyScan',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF1E3A5F),       // Bleu marine
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E3A5F),
          secondary: Color(0xFFD97706),               // Orange accent
          surface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E293B),
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD97706),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        useMaterial3: true,
      ),

      navigatorObservers: [routeObserver],
      initialRoute: routeInitiale,
      // Une seule page au démarrage. Sans cela, initialRoute '/login'
      // empilerait aussi '/' (l'accueil) sous la page de connexion.
      onGenerateInitialRoutes: (route) => [
        MaterialPageRoute(
          settings: RouteSettings(name: route),
          builder: (_) =>
              route == '/' ? const HomePage() : const LoginPage(),
        ),
      ],
      routes: {
        '/':          (context) => const HomePage(),
        '/login':     (context) => const LoginPage(),
        '/register':  (context) => const RegisterPage(),
        '/scan':      (context) => const ScanPage(),
        '/ocr':       (context) => const OcrResultPage(),
        '/insights':  (context) => const InsightsPage(),
        '/quiz':      (context) => const QuizPage(),
        '/library':   (context) => const LibraryPage(),
        '/settings':  (context) => const SettingsPage(),
      },
    );
  }
}
