// ============================================================
//  pages/quiz.page.dart
//  Écran 5 — Quiz interactif
//  StatefulWidget, setState, Column
//  SharedPreferences (score/points)
//  FutureBuilder, SQLite (quiz questions)
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../models/scan.model.dart';
import '../models/quiz.model.dart';
import '../services/scan.service.dart';
import '../services/prefs.service.dart';


class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final ScanService  _scanService  = ScanService();
  final PrefsService _prefsService = PrefsService();

  ScanModel? _scan;
  List<QuizQuestion> _questions = [];

  int _questionActuelle  = 0;
  int _score             = 0;
  int _serie             = 0;      // Streak de bonnes réponses
  int _xpTotal           = 0;
  String? _reponseChoisie;         // 'A', 'B', 'C' ou 'D'
  bool _repondueCette    = false;
  bool _chargement       = true;
  bool _vibrationActive  = true;   // réglage "Vibration" des paramètres
  bool _argumentsLus     = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsLus) return;
    _argumentsLus = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    _initialiser(args is ScanModel ? args : null);
  }

  Future<void> _initialiser(ScanModel? scan) async {
    final prefs = await SharedPreferences.getInstance();
    _vibrationActive = prefs.getBool('vibration') ?? true;

    if (scan == null) {
      // Ouvert depuis le menu : quiz sur le dernier scan enregistré
      final scans = await _scanService.listeScans();
      if (scans.isNotEmpty) scan = scans.first;
    }
    _scan = scan;
    await _chargerQuestions();
  }

  Future<void> _chargerQuestions() async {
    if (_scan == null) {
      if (mounted) setState(() => _chargement = false);
      return;
    }

    // Toujours régénérer pour avoir des questions variées (QCM + Vrai/Faux)
    // Supprimer les anciennes questions du cache SQLite
    await _scanService.supprimerQuestions(_scan!.id!);

    List<QuizQuestion> questions = _scanService.genererQuiz(
      _scan!.id!,
      _scan!.texteOcr,
    );

    // Sauvegarder les nouvelles questions
    for (var q in questions) {
      await _scanService.ajouterQuestion(q);
    }

    if (!mounted) return;
    setState(() {
      _questions        = questions;
      _chargement       = false;
      _questionActuelle = 0;
      _score            = 0;
      _serie            = 0;
      _xpTotal          = 0;
      _reponseChoisie   = null;
      _repondueCette    = false;
    });
  }

  // ---- Sélection d'une réponse ----
  void _selectionnerReponse(String lettre) {
    if (_repondueCette) return; // Déjà répondu à cette question

    QuizQuestion q = _questions[_questionActuelle];
    bool correct = lettre == q.bonneReponse;

    setState(() {
      _reponseChoisie = lettre;
      _repondueCette  = true;

      if (correct) {
        _score++;
        _serie++;
        int xpGagne = 10;
        // Bonus série
        if (_serie >= 3) xpGagne += 5;
        if (_serie >= 5) xpGagne += 10;
        _xpTotal += xpGagne;
      } else {
        _serie = 0; // Réinitialiser la série
        // Vibration en cas de mauvaise réponse (si activée dans les paramètres)
        if (_vibrationActive) Vibration.vibrate(duration: 200);
      }
    });
  }

  // ---- Question suivante ----
  void _questionSuivante() {
    if (_questionActuelle < _questions.length - 1) {
      setState(() {
        _questionActuelle++;
        _reponseChoisie = null;
        _repondueCette  = false;
      });
    } else {
      _terminerQuiz();
    }
  }

  // ---- Fin du quiz ----
  Future<void> _terminerQuiz() async {
    // Sauvegarder les points
    await _prefsService.addPoints(_xpTotal);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Quiz terminé !',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$_score / ${_questions.length}',
              style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w700,
                color: Color(0xFF1E3A5F),
              ),
            ),
            const SizedBox(height: 8),
            Text('Tu as gagné $_xpTotal XP !',
                style: const TextStyle(
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _score == _questions.length
                  ? '🎉 Score parfait !'
                  : _score > _questions.length / 2
                  ? '👍 Bon travail !'
                  : '💪 Continue à t\'entraîner !',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushReplacementNamed(context, '/library');
            },
            child: const Text('Bibliothèque'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Rejouer avec de nouvelles questions (options mélangées)
              setState(() => _chargement = true);
              _chargerQuestions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('Rejouer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Couleur d'une option selon l'état
  Color _couleurOption(String lettre) {
    if (!_repondueCette) return Colors.white;
    QuizQuestion q = _questions[_questionActuelle];
    if (lettre == q.bonneReponse) return const Color(0xFFF0FDF4);
    if (lettre == _reponseChoisie) return const Color(0xFFFEF2F2);
    return Colors.white;
  }

  Color _couleurBordure(String lettre) {
    if (!_repondueCette) return const Color(0xFFE2E8F0);
    QuizQuestion q = _questions[_questionActuelle];
    if (lettre == q.bonneReponse) return const Color(0xFF22C55E);
    if (lettre == _reponseChoisie) return const Color(0xFFEF4444);
    return const Color(0xFFE2E8F0);
  }

  Color _couleurLettre(String lettre) {
    if (!_repondueCette) return const Color(0xFF94A3B8);
    QuizQuestion q = _questions[_questionActuelle];
    if (lettre == q.bonneReponse) return Colors.white;
    if (lettre == _reponseChoisie) return Colors.white;
    return const Color(0xFF94A3B8);
  }

  Color _bgLettre(String lettre) {
    if (!_repondueCette) return const Color(0xFFE2E8F0);
    QuizQuestion q = _questions[_questionActuelle];
    if (lettre == q.bonneReponse) return const Color(0xFF22C55E);
    if (lettre == _reponseChoisie) return const Color(0xFFEF4444);
    return const Color(0xFFE2E8F0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      body: _chargement
          ? const Center(child: CircularProgressIndicator(
          color: Color(0xFF1E3A5F)))
          : _questions.isEmpty
          ? _buildVideOuPasDeScans()
          : Column(
        children: [
          // ---- Header Quiz (bleu marine) ----
          _buildHeader(),

          // ---- Corps : question + options ----
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [

                  // Bannière Streak (si ≥ 3 bonnes réponses)
                  if (_serie >= 3) _buildStreakBanner(),

                  // Carte question
                  _buildCarteQuestion(),

                  const SizedBox(height: 12),

                  // Options de réponse
                  ..._buildOptions(),

                  const SizedBox(height: 16),

                  // Boutons bas
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.flag_outlined,
                            size: 13),
                        label: const Text('Signaler',
                            style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                          const Color(0xFF64748B),
                          side: const BorderSide(
                              color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _repondueCette
                                ? _questionSuivante
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                              const Color(0xFF475569),
                              backgroundColor:
                              const Color(0xFFF1F5F9),
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Passer',
                                style:
                                TextStyle(fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _repondueCette
                                ? _questionSuivante
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _questionActuelle <
                                  _questions.length - 1
                                  ? 'Suivant →'
                                  : 'Terminer ✓',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    double progression = _questions.isEmpty
        ? 0
        : (_questionActuelle + 1) / _questions.length;

    return Container(
      color: const Color(0xFF1E3A5F),
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 12, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Session Quiz',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$_xpTotal XP',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${_questionActuelle + 1}/${_questions.length}',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white60),
              ),
              Text(
                '${(progression * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progression,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFF97316)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.12),
        border: Border.all(
            color: const Color(0xFFF97316).withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt,
                color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BONUS SÉRIE !',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
              Text(
                '$_serie bonnes réponses de suite !  '
                    '+${_serie >= 5 ? 20 : 5} XP',
                style: const TextStyle(
                  fontSize: 12, color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarteQuestion() {
    QuizQuestion q = _questions[_questionActuelle];
    // Couleur et libellé selon le type
    final bool isQcm = q.type == 'qcm';
    final Color typeColor = isQcm
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    final Color typeBg = isQcm
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFEF3C7);
    final String typeLabel = isQcm ? 'QCM' : 'VRAI / FAUX';

    // Couleur difficulté
    final Map<String, Color> diffColor = {
      'facile':    const Color(0xFF16A34A),
      'moyen':     const Color(0xFFD97706),
      'difficile': const Color(0xFFDC2626),
    };
    final Map<String, Color> diffBg = {
      'facile':    const Color(0xFFDCFCE7),
      'moyen':     const Color(0xFFFEF3C7),
      'difficile': const Color(0xFFFEF2F2),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Badge type QCM / Vrai-Faux
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(typeLabel,
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: typeColor,
                    )),
              ),
              const SizedBox(width: 7),
              // Badge matière
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _scan?.matiere ?? 'GÉNÉRAL',
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              // Badge difficulté
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: diffBg[q.difficulte] ?? const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  q.difficulte.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: diffColor[q.difficulte] ?? const Color(0xFF5B21B6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            q.question,
            style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B), height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOptions() {
    QuizQuestion q = _questions[_questionActuelle];
    List<Map<String, String>> opts = [
      {'lettre': 'A', 'texte': q.optionA},
      {'lettre': 'B', 'texte': q.optionB},
    ];
    if (q.type == 'qcm') {
      opts.addAll([
        {'lettre': 'C', 'texte': q.optionC},
        {'lettre': 'D', 'texte': q.optionD},
      ]);
    }

    return opts.where((o) => o['texte']!.isNotEmpty).map((opt) {
      String lettre = opt['lettre']!;
      String texte  = opt['texte']!;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => _selectionnerReponse(lettre),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: _couleurOption(lettre),
              border: Border.all(
                  color: _couleurBordure(lettre), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _bgLettre(lettre),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      lettre,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: _couleurLettre(lettre),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    texte,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                // Icône check si bonne réponse
                if (_repondueCette &&
                    lettre == _questions[_questionActuelle].bonneReponse)
                  const Icon(Icons.check_circle_outline,
                      color: Color(0xFF22C55E), size: 18),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildVideOuPasDeScans() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.quiz_outlined,
                size: 64, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 16),
            const Text(
              'Aucun quiz disponible.',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scanne un document pour générer ton premier quiz !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F),
              ),
              child: const Text('Scanner maintenant',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

}