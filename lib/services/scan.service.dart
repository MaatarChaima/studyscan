// ============================================================
//  services/scan.service.dart
//  Couche service
//  Appels ML Kit OCR + Entity Extraction + Language ID + Translation
//  Résumé, mots-clés et quiz générés sur l'appareil (sans IA externe)
// ============================================================

import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_entity_extraction/google_mlkit_entity_extraction.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:intl/intl.dart';
import '../models/scan.model.dart';
import '../models/quiz.model.dart';
import '../utils/scan.database.dart';

class ScanService {
  final ScanDatabase _db = ScanDatabase();
  final Random _random = Random();

  // -------------------------------------------------------
  //  Outils texte (compatibles avec les accents)
  // -------------------------------------------------------

  // Un "mot" = suite de lettres (accents compris) ou de chiffres.
  // unicode: true est indispensable : sans lui, \w ne reconnaît pas
  // é, è, à, ç… et "Révolution" devient "Rvolution".
  static final RegExp _regexMot = RegExp(r'[\p{L}\p{N}]+', unicode: true);

  // Fin de phrase : . ! ? … suivis d'un espace
  static final RegExp _regexFinPhrase = RegExp(r'(?<=[.!?…])\s+');

  // Mots vides français + anglais (ignorés pour le résumé, les mots-clés et le quiz)
  static const Set<String> _motsVides = {
    // Français
    'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'au', 'aux',
    'et', 'ou', 'mais', 'donc', 'or', 'ni', 'car', 'que', 'qui', 'quoi',
    'dont', 'où', 'ce', 'cet', 'cette', 'ces', 'son', 'sa', 'ses',
    'leur', 'leurs', 'notre', 'nos', 'votre', 'vos', 'mon', 'ma', 'mes',
    'ton', 'ta', 'tes', 'il', 'elle', 'ils', 'elles', 'on', 'nous',
    'vous', 'je', 'tu', 'se', 'en', 'ne', 'pas', 'plus', 'moins',
    'est', 'sont', 'été', 'être', 'avoir', 'ont', 'avait', 'était',
    'sur', 'sous', 'dans', 'par', 'pour', 'avec', 'sans', 'entre',
    'vers', 'chez', 'comme', 'aussi', 'très', 'bien', 'tout', 'tous',
    'toute', 'toutes', 'même', 'fait', 'faire', 'peut', 'alors', 'lors',
    'après', 'avant', 'puis', 'encore', 'ainsi', 'cela', 'ceci',
    'celui', 'celle', 'ceux', 'selon', 'chaque', 'autre', 'autres',
    'deux', 'trois', 'quand', 'comment', 'pourquoi', 'si',
    // Anglais
    'the', 'of', 'and', 'to', 'in', 'is', 'are', 'was', 'were', 'be',
    'been', 'for', 'with', 'as', 'by', 'at', 'from', 'that',
    'this', 'these', 'those', 'it', 'its', 'an', 'not', 'which',
    'has', 'have', 'had', 'can', 'will', 'also', 'into', 'than',
    // Anglais (suite) : mots courants à exclure des mots-clés et du quiz
    'they', 'their', 'them', 'there', 'what', 'when', 'where', 'while',
    'who', 'whom', 'why', 'how', 'about', 'other', 'others', 'such',
    'called', 'many', 'much', 'more', 'most', 'some', 'each', 'every',
    'only', 'very', 'made', 'make', 'makes', 'all', 'any', 'may', 'would',
    'could', 'should', 'does', 'did', 'our', 'your', 'his', 'her', 'she',
    'him', 'you', 'we', 'one', 'two', 'new', 'used', 'use', 'like', 'just',
    'being', 'because', 'between', 'through', 'during', 'without',
    'within', 'then', 'thus', 'here', 'both', 'either', 'neither', 'after',
    'before', 'over', 'under', 'again', 'same', 'own',
  };

  // Recolle les mots coupés en fin de ligne ("prob-\nlème") et
  // remplace les retours à la ligne de l'OCR par des espaces
  String _normaliser(String texte) {
    return texte
        .replaceAll(RegExp(r'-\n'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _decouperPhrases(String texte) {
    return _normaliser(texte)
        .split(_regexFinPhrase)
        .map((p) => p.trim())
        .where((p) => p.length >= 25)
        .toList();
  }

  // Mots porteurs de sens (minuscules, sans mots vides ni nombres)
  List<String> _motsPleins(String texte) {
    return _regexMot
        .allMatches(texte.toLowerCase())
        .map((m) => m.group(0)!)
        .where((m) =>
            m.length >= 3 &&
            !_motsVides.contains(m) &&
            int.tryParse(m) == null)
        .toList();
  }

  // Coupe un texte à [max] caractères sans couper un mot
  String _couper(String texte, int max) {
    if (texte.length <= max) return texte;
    final int dernierEspace = texte.lastIndexOf(' ', max);
    return '${texte.substring(0, dernierEspace > 0 ? dernierEspace : max)}…';
  }

  // Regex qui trouve [mot] comme mot entier, sans tenir compte de la casse
  RegExp _regexMotEntier(String mot) => RegExp(
        '(?<![\\p{L}\\p{N}])${RegExp.escape(mot)}(?![\\p{L}\\p{N}])',
        caseSensitive: false,
        unicode: true,
      );

  String _majuscule(String mot) =>
      mot.isEmpty ? mot : mot.substring(0, 1).toUpperCase() + mot.substring(1);

  // -------------------------------------------------------
  //  1. OCR — Reconnaissance de texte (ML Kit)
  //     Renvoie le texte et la confiance moyenne de ML Kit (0-100),
  //     pondérée par la longueur des lignes. La confiance n'est
  //     fournie que sur Android : null sinon.
  // -------------------------------------------------------
  Future<({String texte, int? confiance})> extraireTexte(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final RecognizedText result =
          await textRecognizer.processImage(inputImage);

      double somme = 0;
      int poidsTotal = 0;
      for (final bloc in result.blocks) {
        for (final ligne in bloc.lines) {
          final double? c = ligne.confidence;
          if (c == null) continue;
          somme += c * ligne.text.length;
          poidsTotal += ligne.text.length;
        }
      }
      final int? confiance =
          poidsTotal == 0 ? null : (somme / poidsTotal * 100).round().clamp(0, 100);

      return (texte: result.text, confiance: confiance);
    } finally {
      await textRecognizer.close();
    }
  }

  // -------------------------------------------------------
  //  2. Extraction d'entités (ML Kit)
  //     Le modèle doit être téléchargé une première fois (internet).
  //     En cas d'échec, on renvoie des listes vides au lieu de bloquer
  //     tout le traitement du scan.
  // -------------------------------------------------------
  Future<Map<String, List<String>>> extraireEntites(String texte) async {
    final Set<String> dates = {};
    final Set<String> lieux = {};
    final Set<String> autres = {};

    final entityExtractor = EntityExtractor(
      language: EntityExtractorLanguage.french,
    );
    try {
      // Le modèle doit être présent sur l'appareil avant l'analyse
      final modelManager = EntityExtractorModelManager();
      final String modele = EntityExtractorLanguage.french.name;
      if (!await modelManager.isModelDownloaded(modele)) {
        await modelManager.downloadModel(modele, isWifiRequired: false);
      }

      final List<EntityAnnotation> annotations =
          await entityExtractor.annotateText(texte);

      for (final annotation in annotations) {
        // Une annotation peut avoir plusieurs types : on garde le premier
        if (annotation.entities.isEmpty) continue;
        final type = annotation.entities.first.type;
        if (type == EntityType.dateTime) {
          dates.add(annotation.text);
        } else if (type == EntityType.address) {
          lieux.add(annotation.text);
        } else {
          autres.add(annotation.text);
        }
      }
    } catch (_) {
      // Modèle indisponible (pas de connexion au premier lancement…)
    } finally {
      await entityExtractor.close();
    }
    return {
      'dates': dates.toList(),
      'lieux': lieux.toList(),
      'autres': autres.toList(),
    };
  }

  // -------------------------------------------------------
  //  3. Identification de la langue (ML Kit)
  // -------------------------------------------------------
  Future<String> identifierLangue(String texte) async {
    final languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
    try {
      return await languageIdentifier.identifyLanguage(texte);
    } finally {
      await languageIdentifier.close();
    }
  }

  // Langues proposées dans l'application
  static const Map<String, TranslateLanguage> _languesTraduction = {
    'fr': TranslateLanguage.french,
    'en': TranslateLanguage.english,
    'ar': TranslateLanguage.arabic,
  };

  Future<void> _telechargerModele(
      OnDeviceTranslatorModelManager manager, TranslateLanguage langue) async {
    final bool dispo = await manager.isModelDownloaded(langue.bcpCode);
    // isWifiRequired vaut true par défaut : sans Wi-Fi, le téléchargement
    // échouait. On l'autorise aussi en données mobiles.
    if (!dispo) {
      await manager.downloadModel(langue.bcpCode, isWifiRequired: false);
    }
  }

  // -------------------------------------------------------
  //  3b. Vérification et téléchargement du modèle de la langue cible
  //      (le modèle de la langue source est géré dans traduire())
  // -------------------------------------------------------
  Future<bool> verifierModeleTraduction(String versLangue) async {
    final cible = _languesTraduction[versLangue] ?? TranslateLanguage.english;
    try {
      await _telechargerModele(OnDeviceTranslatorModelManager(), cible);
      return true;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------
  //  4. Traduction du texte (ML Kit)
  // -------------------------------------------------------
  Future<String> traduire(String texte, String versLangue) async {
    final String codeSource = await identifierLangue(texte);

    // Langue source détectée parmi toutes les langues ML Kit (fr par défaut)
    final TranslateLanguage source = TranslateLanguage.values.firstWhere(
      (l) => l.bcpCode == codeSource,
      orElse: () => TranslateLanguage.french,
    );
    final TranslateLanguage cible =
        _languesTraduction[versLangue] ?? TranslateLanguage.english;

    // Déjà dans la bonne langue : rien à traduire
    if (source == cible) return texte;

    // Le modèle de la langue source doit aussi être présent
    await _telechargerModele(OnDeviceTranslatorModelManager(), source);

    final onDeviceTranslator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: cible,
    );
    try {
      return await onDeviceTranslator.translateText(texte);
    } finally {
      await onDeviceTranslator.close();
    }
  }

  // -------------------------------------------------------
  //  5. Génération de résumé (extractif, algorithme SumBasic)
  //     - garde les phrases dont les mots sont les plus fréquents
  //     - après chaque phrase choisie, ses mots perdent du poids :
  //       la phrase suivante parle d'autre chose (pas de répétition)
  //     - longueur proportionnelle au document (30 %, entre 2 et 5 phrases)
  //     - phrases remises dans l'ordre du document
  // -------------------------------------------------------
  String genererResume(String texte) {
    final String propre = _normaliser(texte);
    if (propre.isEmpty) return '';

    final List<String> phrases = _decouperPhrases(propre);

    // Texte trop court ou sans ponctuation : on renvoie le début
    if (phrases.isEmpty) return _couper(propre, 300);
    if (phrases.length <= 2) return phrases.join(' ');

    // Probabilité de chaque mot dans le document
    final List<String> tousLesMots = _motsPleins(propre);
    if (tousLesMots.isEmpty) return _couper(propre, 300);
    final Map<String, double> poids = {};
    for (final mot in tousLesMots) {
      poids[mot] = (poids[mot] ?? 0) + 1 / tousLesMots.length;
    }

    final List<Set<String>> motsParPhrase =
        phrases.map((p) => _motsPleins(p).toSet()).toList();

    final int nbPhrases = (phrases.length * 0.3).ceil().clamp(2, 5);
    final List<int> choisies = [];

    while (choisies.length < nbPhrases) {
      int meilleure = -1;
      double meilleurScore = -1;

      for (int i = 0; i < phrases.length; i++) {
        final mots = motsParPhrase[i];
        if (choisies.contains(i) || mots.length < 3) continue;

        double score =
            mots.fold<double>(0, (s, m) => s + poids[m]!) / mots.length;
        if (i == 0) score *= 1.2; // la 1re phrase introduit souvent le sujet

        if (score > meilleurScore) {
          meilleurScore = score;
          meilleure = i;
        }
      }
      if (meilleure == -1) break;

      choisies.add(meilleure);
      // Réduire le poids des mots déjà couverts
      for (final mot in motsParPhrase[meilleure]) {
        poids[mot] = poids[mot]! * poids[mot]!;
      }
    }

    if (choisies.isEmpty) return _couper(propre, 300);
    choisies.sort();
    return choisies.map((i) => phrases[i]).join(' ');
  }

  // -------------------------------------------------------
  //  6. Extraction de mots-clés (mots les plus fréquents,
  //     sans mots vides, accents conservés)
  // -------------------------------------------------------
  List<String> _motsImportants(String texte, int nb) {
    final Map<String, int> freq = {};
    final Map<String, int> premiereApparition = {};
    final mots = _motsPleins(texte).where((m) => m.length >= 4).toList();

    for (int i = 0; i < mots.length; i++) {
      freq[mots[i]] = (freq[mots[i]] ?? 0) + 1;
      premiereApparition.putIfAbsent(mots[i], () => i);
    }

    final tries = freq.keys.toList()
      ..sort((a, b) {
        final cmp = freq[b]!.compareTo(freq[a]!);
        return cmp != 0
            ? cmp
            : premiereApparition[a]!.compareTo(premiereApparition[b]!);
      });
    return tries.take(nb).toList();
  }

  List<String> extraireMotsCles(String texte) {
    return _motsImportants(texte, 8).map(_majuscule).toList();
  }

  // -------------------------------------------------------
  //  6b. Détection de la matière (français + anglais)
  //      On compte les mots du texte qui commencent par l'une des
  //      racines d'une matière ; la matière avec le plus de mots gagne
  //      (au moins 2, sinon 'GÉNÉRAL'). Les noms correspondent à ceux
  //      proposés à l'inscription, en majuscules.
  // -------------------------------------------------------
  static const Map<String, List<String>> _racinesParMatiere = {
    'CHIMIE': [
      'chimi', 'molécul', 'atome', 'atomi', 'réaction', 'acide', 'électron',
      'oxyd', 'liaison', 'isotope',
      'chemi', 'molecul', 'atom', 'reaction', 'acid', 'electron', 'oxid',
      'compound', 'isotop',
    ],
    'HISTOIRE': [
      'histoir', 'guerre', 'révolution', 'empire', 'empereur', 'roi', 'siècle',
      'traité', 'colonis', 'indépendance', 'dynastie', 'bataille',
      'histor', 'revolution', 'emperor', 'king', 'centur', 'treaty',
      'coloni', 'independen', 'dynast', 'battle',
    ],
    'BIOLOGIE': [
      'biolog', 'cellul', 'adn', 'gène', 'génét', 'organisme', 'protéine',
      'enzyme', 'espèce', 'photosynth',
      'cell', 'dna', 'genetic', 'genome', 'organism', 'protein', 'enzym',
      'species', 'chromosom',
    ],
    'MATHÉMATIQUES': [
      'mathémat', 'équation', 'calcul', 'fonction', 'dérivée', 'intégral',
      'matrice', 'théorème', 'vecteur', 'probabilit',
      'mathemat', 'equation', 'function', 'derivative', 'integral', 'matri',
      'theorem', 'vector', 'probabil',
    ],
    'PHYSIQUE': [
      'physiqu', 'force', 'énergie', 'vitesse', 'masse', 'onde', 'électri',
      'newton', 'gravit', 'tension',
      'physic', 'energ', 'velocit', 'wave', 'electric', 'voltage', 'momentum',
    ],
    'INFORMATIQUE': [
      'informati', 'algorithm', 'programm', 'logiciel', 'ordinateur',
      'donnée', 'réseau', 'serveur',
      'software', 'computer', 'database', 'network', 'server', 'compil',
    ],
  };

  String detecterMatiere(String texte) {
    final List<String> mots = RegExp(r'\p{L}+', unicode: true)
        .allMatches(texte.toLowerCase())
        .map((m) => m.group(0)!)
        .toList();

    String meilleure = 'GÉNÉRAL';
    int meilleurScore = 0;
    _racinesParMatiere.forEach((matiere, racines) {
      final int score = mots
          .where((mot) => racines.any((r) => mot.startsWith(r)))
          .length;
      if (score > meilleurScore) {
        meilleurScore = score;
        meilleure = matiere;
      }
    });
    // Au moins 2 mots, pour ne pas classer un texte sur un seul mot isolé
    return meilleurScore >= 2 ? meilleure : 'GÉNÉRAL';
  }

  // -------------------------------------------------------
  //  7. Génération de quiz
  //     - QCM : phrase du cours avec un mot-clé masqué (_____),
  //       4 propositions distinctes
  //     - Vrai/Faux : phrase originale (vrai) ou modifiée (faux),
  //       en alternance
  // -------------------------------------------------------
  List<QuizQuestion> genererQuiz(int scanId, String texte) {
    final List<QuizQuestion> questions = [];

    final List<String> phrases = _decouperPhrases(texte)
        .where((p) => p.length > 40 && p.length < 250)
        .toList();
    if (phrases.isEmpty) return questions;

    // Vocabulaire du document : sert de réponses et de distracteurs
    final List<String> vocabulaire = _motsImportants(texte, 30);

    final int nbQuestions = min(phrases.length, 8);
    final List<String> selection = _selectionnerPhrases(phrases, nbQuestions);

    int nbVraiFaux = 0;
    for (int i = 0; i < selection.length; i++) {
      final String phrase = selection[i];

      if (i.isEven) {
        final qcm = _genererQCM(scanId, phrase, vocabulaire);
        if (qcm != null) {
          questions.add(qcm);
          continue;
        }
        // QCM impossible (pas assez de distracteurs) → Vrai/Faux
      }
      questions.add(
          _genererVraiFaux(scanId, phrase, vocabulaire, nbVraiFaux.isEven));
      nbVraiFaux++;
    }

    return questions;
  }

  // Sélectionner des phrases réparties uniformément dans le document
  List<String> _selectionnerPhrases(List<String> phrases, int nb) {
    if (phrases.length <= nb) return phrases;
    final double pas = phrases.length / nb;
    return List.generate(nb, (i) => phrases[(i * pas).floor()]);
  }

  // QCM : masquer un mot important de la phrase
  QuizQuestion? _genererQCM(
      int scanId, String phrase, List<String> vocabulaire) {
    final Set<String> motsPhrase = _motsPleins(phrase).toSet();

    // Réponse : le mot le plus important du document présent dans la phrase,
    // sinon le mot le plus long de la phrase
    String? reponse;
    for (final mot in vocabulaire) {
      if (motsPhrase.contains(mot)) {
        reponse = mot;
        break;
      }
    }
    if (reponse == null) {
      final candidats = motsPhrase.where((m) => m.length >= 5).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      if (candidats.isEmpty) return null;
      reponse = candidats.first;
    }

    // Distracteurs : autres mots du document, absents de la phrase
    final List<String> distracteurs = vocabulaire
        .where((m) => m != reponse && !motsPhrase.contains(m))
        .toList()
      ..shuffle(_random);
    if (distracteurs.length < 3) return null;

    final List<String> options =
        [reponse, ...distracteurs.take(3)].map(_majuscule).toList()
          ..shuffle(_random);
    final int indexBonne = options.indexOf(_majuscule(reponse));

    final String phraseATrous =
        phrase.replaceAll(_regexMotEntier(reponse), '_____');

    return QuizQuestion(
      scanId:       scanId,
      question:     'Quel mot complète cette phrase ?\n"$phraseATrous"',
      optionA:      options[0],
      optionB:      options[1],
      optionC:      options[2],
      optionD:      options[3],
      bonneReponse: ['A', 'B', 'C', 'D'][indexBonne],
      type:         'qcm',
      difficulte:   'moyen',
    );
  }

  // Vrai/Faux : si la phrase ne peut pas être falsifiée, elle reste vraie
  QuizQuestion _genererVraiFaux(int scanId, String phrase,
      List<String> vocabulaire, bool vraieVoulue) {
    String affirmation = phrase;
    bool estVraie = true;

    if (!vraieVoulue) {
      final String? fausse = _falsifierPhrase(phrase, vocabulaire);
      if (fausse != null) {
        affirmation = fausse;
        estVraie = false;
      }
    }

    return QuizQuestion(
      scanId:       scanId,
      question:     'Cette affirmation est-elle vraie ou fausse ?\n"$affirmation"',
      optionA:      'Vrai',
      optionB:      'Faux',
      bonneReponse: estVraie ? 'A' : 'B', // 'A' = Vrai, 'B' = Faux
      type:         'vrai_faux',
      difficulte:   'facile',
    );
  }

  // Rendre une phrase fausse :
  //  1) changer un nombre ou une date (1789 → 1792)
  //  2) sinon remplacer un mot-clé par un autre mot-clé du document
  // Renvoie null si aucune modification fiable n'est possible.
  String? _falsifierPhrase(String phrase, List<String> vocabulaire) {
    final nombre = RegExp(r'\b\d{1,4}\b').firstMatch(phrase);
    if (nombre != null) {
      final int valeur = int.parse(nombre.group(0)!);
      final int decalage = 1 + _random.nextInt(5);
      final int nouvelle =
          (valeur > decalage && _random.nextBool()) ? valeur - decalage : valeur + decalage;
      return phrase.replaceRange(nombre.start, nombre.end, '$nouvelle');
    }

    final Set<String> motsPhrase = _motsPleins(phrase).toSet();
    final String? motARemplacer =
        vocabulaire.where((m) => motsPhrase.contains(m)).firstOrNull;
    if (motARemplacer == null) return null;

    final remplacants = vocabulaire
        .where((m) => m != motARemplacer && !motsPhrase.contains(m))
        .toList();
    if (remplacants.isEmpty) return null;
    final String remplacant = remplacants[_random.nextInt(remplacants.length)];

    // Remplacer la 1re occurrence en gardant la majuscule éventuelle
    return phrase.replaceFirstMapped(_regexMotEntier(motARemplacer), (m) {
      final original = m.group(0)!;
      final majuscule = original[0] != original[0].toLowerCase();
      return majuscule ? _majuscule(remplacant) : remplacant;
    });
  }

  // -------------------------------------------------------
  //  8. Date au format jj/mm/aaaa
  // -------------------------------------------------------
  String dateAujourdhui() {
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }

  // -------------------------------------------------------
  //  CRUD
  // -------------------------------------------------------
  Future<int> ajouterScan(ScanModel scan) => _db.insertScan(scan);
  Future<List<ScanModel>> listeScans() => _db.listeScans();
  Future<ScanModel?> getScan(int id) => _db.getScan(id);
  Future<int> modifierScan(ScanModel scan) => _db.modifierScan(scan);
  Future<int> supprimerScan(ScanModel scan) => _db.supprimerScan(scan);
  Future<int> countScans() => _db.countScans();
  Future<int> ajouterQuestion(QuizQuestion q) => _db.insertQuestion(q);
  Future<List<QuizQuestion>> listeQuestions(int scanId) => _db.listeQuestions(scanId);
  Future<int> supprimerQuestions(int scanId) => _db.supprimerQuestions(scanId);
}
