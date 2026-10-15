// ============================================================
//  test/scan_service_test.dart
//  Tests unitaires : résumé, mots-clés et génération du quiz
//  Lancer avec : flutter test
// ============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:projetstudyscan/services/scan.service.dart';

// Texte de cours tel que le renvoie l'OCR : retours à la ligne au milieu
// des phrases et mot coupé par un tiret en fin de ligne
const String coursHistoire = '''
La Révolution française commence en 1789 avec la prise de la Bastille.
Les députés du tiers état se proclament Assemblée nationale et rédigent
une constitution. La Déclaration des droits de l'homme et du citoyen
affirme l'égalité des citoyens devant la loi. La Révolution française
abolit les privilèges de la noblesse et du clergé. En 1792, la
République est proclamée après la chute de la monarchie. La Terreur
fait des milliers de victimes entre 1793 et 1794. Napoléon Bonaparte
prend le pouvoir en 1799 par un coup d'État. L'héritage de la
Révolution française marque durablement l'Europe et le monde en-
tier.''';

void main() {
  final service = ScanService();

  group('genererResume', () {
    test('texte vide → résumé vide', () {
      expect(service.genererResume('   \n  '), '');
    });

    test('texte court avec espaces à la fin → pas de plantage', () {
      expect(service.genererResume('Court texte.   \n\n'), 'Court texte.');
    });

    test('résumé plus court que le texte, sans retour à la ligne', () {
      final resume = service.genererResume(coursHistoire);
      expect(resume, isNotEmpty);
      expect(resume.length, lessThan(coursHistoire.length));
      expect(resume.contains('\n'), isFalse);
    });

    test('garde la première phrase et des idées variées', () {
      final resume = service.genererResume(coursHistoire);
      expect(resume, startsWith('La Révolution française commence en 1789'));
      // L'ancien algorithme répétait 3 phrases sur "la Révolution française"
      expect('Révolution française'.allMatches(resume).length, lessThan(3));
    });

    test('mot coupé en fin de ligne recollé', () {
      final resume = service.genererResume(coursHistoire);
      expect(resume.contains('en- tier'), isFalse);
    });
  });

  group('extraireMotsCles', () {
    test('les accents sont conservés', () {
      final motsCles = service.extraireMotsCles(coursHistoire);
      expect(motsCles, contains('Révolution'));
      expect(motsCles, contains('Française'));
      expect(motsCles.any((m) => m.contains('Rvolution')), isFalse);
    });

    test('pas de mots vides', () {
      final motsCles =
          service.extraireMotsCles(coursHistoire).map((m) => m.toLowerCase());
      for (final vide in ['dans', 'avec', 'pour', 'cette', 'entre']) {
        expect(motsCles, isNot(contains(vide)));
      }
    });
  });

  group('genererQuiz', () {
    final questions = service.genererQuiz(1, coursHistoire);

    test('génère des questions', () {
      expect(questions, isNotEmpty);
      expect(questions.length, lessThanOrEqualTo(8));
    });

    test('QCM : un trou dans la phrase et 4 réponses différentes', () {
      final qcms = questions.where((q) => q.type == 'qcm');
      expect(qcms, isNotEmpty);
      for (final q in qcms) {
        expect(q.question, contains('_____'));
        final options = [q.optionA, q.optionB, q.optionC, q.optionD];
        expect(options.toSet().length, 4);
        expect(['A', 'B', 'C', 'D'], contains(q.bonneReponse));
      }
    });

    test('Vrai/Faux : il y a des "Vrai" ET des "Faux"', () {
      final vraiFaux = questions.where((q) => q.type == 'vrai_faux').toList();
      expect(vraiFaux.length, greaterThanOrEqualTo(2));
      final reponses = vraiFaux.map((q) => q.bonneReponse).toSet();
      expect(reponses, containsAll(['A', 'B'])); // A = Vrai, B = Faux
    });

    test('une affirmation "Faux" est bien différente du cours', () {
      final texteNormalise = coursHistoire.replaceAll(RegExp(r'\s+'), ' ');
      for (final q in questions.where(
          (q) => q.type == 'vrai_faux' && q.bonneReponse == 'B')) {
        final affirmation = q.question.split('"')[1];
        expect(texteNormalise.contains(affirmation), isFalse);
      }
    });
  });
}
