
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan.model.dart';
import '../services/prefs.service.dart';
import '../services/scan.service.dart';


class OcrResultPage extends StatefulWidget {
  const OcrResultPage({super.key});

  @override
  State<OcrResultPage> createState() => _OcrResultPageState();
}

class _OcrResultPageState extends State<OcrResultPage> {
  final ScanService _scanService = ScanService();
  final FocusNode _focusTexte = FocusNode();

  // Données reçues depuis ScanPage
  String _texteOcr = '';
  String _langue   = 'fr';
  int    _scoreOcr = 0;
  String? _cheminImage;              // aperçu du scan (nouveau scan uniquement)
  ScanModel? _scanExistant;          // ouvert depuis la bibliothèque
  bool   _argumentsLus = false;
  Map<String, List<String>> _entites = {};

  // Contrôleur du champ de texte éditable
  late TextEditingController _texteController;

  // Traduction
  String _texteTraduIt     = '';
  String _langueTraduction = 'en';
  bool   _enTraduction     = false;
  bool   _modeleEnCours    = false; // téléchargement modèle ML en cours

  // Sauvegarde
  bool _enSauvegarde = false;

  @override
  void initState() {
    super.initState();
    _texteController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies peut être rappelé (clavier, rotation…) :
    // on ne lit les arguments qu'une fois, sinon les corrections
    // de l'utilisateur seraient effacées
    if (_argumentsLus) return;
    _argumentsLus = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      _texteOcr    = args['texte']    ?? '';
      _langue      = args['langue']   ?? 'fr';
      _scoreOcr    = args['scoreOcr'] ?? 0;
      _cheminImage = args['image'];
      _entites     = Map<String, List<String>>.from(
        args['entites'] ?? {},
      );
    } else if (args is ScanModel) {
      // Correction d'un scan déjà enregistré
      _scanExistant = args;
      _texteOcr     = args.texteOcr;
      _langue       = args.langue;
      _scoreOcr     = args.scoreOcr;
    }
    _texteController.text = _texteOcr;
  }

  @override
  void dispose() {
    _texteController.dispose();
    _focusTexte.dispose();
    super.dispose();
  }

  // ---- Changement de langue cible (sans déclencher la traduction) ----
  void _changerLangueCible(String? nouvelleLangue) {
    if (nouvelleLangue == null) return;
    setState(() {
      _langueTraduction = nouvelleLangue;
      // Réinitialiser l'ancienne traduction si la langue change
      _texteTraduIt = '';
    });
  }

  // ---- Traduction (ML Kit) ----
  // Problème principal : ML Kit Translation doit télécharger le modèle
  // on-device avant la première utilisation. On gère ce cas explicitement.
  Future<void> _traduire() async {
    final texte = _texteController.text.trim();

    // Vérifications préalables
    if (texte.isEmpty) {
      _afficherMsg('Aucun texte à traduire.', Colors.orange);
      return;
    }
    if (_enTraduction || _modeleEnCours) return;

    setState(() {
      _enTraduction  = true;
      _texteTraduIt  = '';
    });

    try {
      // Étape 1 : Vérifier et télécharger le modèle si nécessaire
      setState(() => _modeleEnCours = true);
      final bool modeleOk =
          await _scanService.verifierModeleTraduction(_langueTraduction);
      setState(() => _modeleEnCours = false);

      if (!modeleOk) {
        _afficherMsg(
          'Modèle de traduction indisponible. '
          'Vérifie ta connexion internet.',
          Colors.orange,
        );
        return;
      }

      // Étape 2 : Traduire
      final String resultat = await _scanService.traduire(
        texte,
        _langueTraduction,
      );

      if (resultat.trim().isEmpty) {
        _afficherMsg('Traduction vide. Réessaie.', Colors.orange);
        return;
      }

      setState(() => _texteTraduIt = resultat);
    } catch (e) {
      // Message d'erreur lisible selon le type d'erreur
      String msg = 'Erreur de traduction.';
      final err = e.toString().toLowerCase();
      if (err.contains('network') || err.contains('internet')) {
        msg = 'Pas de connexion. Le modèle ML doit être téléchargé.';
      } else if (err.contains('model') || err.contains('download')) {
        msg = 'Modèle non disponible. Lance l\'app avec internet la 1ère fois.';
      }
      _afficherMsg(msg, Colors.red);
    } finally {
      setState(() {
        _enTraduction  = false;
        _modeleEnCours = false;
      });
    }
  }

  // ---- Sauvegarde dans SQLite ----
  Future<void> _sauvegarder() async {
    final String texte = _texteController.text;
    if (texte.trim().isEmpty) {
      _afficherMsg('Texte vide, impossible de sauvegarder.', Colors.orange);
      return;
    }

    setState(() => _enSauvegarde = true);

    try {
      final String resume = _scanService.genererResume(texte);
      final List<String> mcs = _scanService.extraireMotsCles(texte);
      String matiere = _scanService.detecterMatiere(texte);
      if (matiere == 'GÉNÉRAL') {
        // Rien de détecté : on prend la matière choisie à l'inscription
        final prefs = await SharedPreferences.getInstance();
        matiere = (prefs.getString('matiere') ?? 'Général').toUpperCase();
      }
      final ScanModel scan;

      if (_scanExistant != null) {
        // Scan déjà en bibliothèque : on le met à jour (pas de doublon)
        scan = _scanExistant!
          ..texteOcr = texte
          ..resume   = resume
          ..motsCles = mcs.join(',')
          ..matiere  = matiere;
        await _scanService.modifierScan(scan);
        // L'ancien quiz ne correspond plus au texte corrigé
        await _scanService.supprimerQuestions(scan.id!);
      } else {
        scan = ScanModel(
          titre:        'Scan du ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
          texteOcr:     texte,
          resume:       resume,
          motsCles:     mcs.join(','),
          langue:       _langue,
          matiere:      matiere,
          dateCreation: _scanService.dateAujourdhui(),
          scoreOcr:     _scoreOcr,
          points:       50,
        );
        scan.id = await _scanService.ajouterScan(scan);
        // Les points du scan sont ajoutés au total de l'étudiant
        await PrefsService().addPoints(scan.points);
      }

      _afficherMsg(
        _scanExistant == null
            ? '✅ Scan sauvegardé (+${scan.points} pts)'
            : '✅ Scan mis à jour',
        const Color(0xFF16A34A),
      );

      if (!mounted) return;
      if (_scanExistant != null) {
        // Correction : retour aux insights, qui affichent le scan mis à jour
        Navigator.pop(context, scan);
      } else {
        // Nouveau scan : la page OCR est remplacée par les insights,
        // le bouton retour ne ramène pas sur un texte déjà sauvegardé
        Navigator.pushReplacementNamed(
          context,
          '/insights',
          arguments: scan,
        );
      }
    } catch (e) {
      _afficherMsg('Erreur sauvegarde : $e', Colors.red);
    } finally {
      if (mounted) setState(() => _enSauvegarde = false);
    }
  }

  void _afficherMsg(String msg, Color couleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: couleur,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Résultat OCR',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              'Résultat OCR',
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Consulte et affine ton document scanné.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // ---- Aperçu du scan ----
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'APERÇU DU SCAN ORIGINAL',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B), letterSpacing: 0.5,
                          ),
                        ),
                        Icon(Icons.zoom_in,
                            size: 16, color: const Color(0xFF64748B)),
                      ],
                    ),
                  ),
                  Container(
                    height: 90,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF334155),
                      borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(16)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Image réellement scannée, sinon icône
                        if (_cheminImage != null &&
                            File(_cheminImage!).existsSync())
                          Positioned.fill(
                            child: Image.file(
                              File(_cheminImage!),
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          const Icon(Icons.description_outlined,
                              color: Colors.white24, size: 40),
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFF97316)
                                    .withValues(alpha: 0.7),
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---- Texte OCR éditable ----
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Actions : Éditer, Traduire, Supprimer
                  Row(
                    children: [
                      _buildActionChip(
                        Icons.edit_outlined, 'Éditer',
                        // Place le curseur dans le texte pour le corriger
                        onTap: () => _focusTexte.requestFocus(),
                      ),
                      const SizedBox(width: 8),
                      // Sélecteur de langue pour traduction
                      _buildTranslateChip(),
                      const Spacer(),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _texteController.clear()),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: const Color(0xFFFCA5A5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.delete_outline,
                              size: 14, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Champ texte éditable
                  TextField(
                    controller: _texteController,
                    focusNode: _focusTexte,
                    maxLines: null,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF374151),
                      height: 1.7,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Le texte OCR apparaîtra ici...',
                    ),
                  ),

                  // ---- Zone résultat traduction ----

                  // Téléchargement modèle en cours
                  if (_modeleEnCours)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E3A5F), strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Téléchargement du modèle ML...',
                            style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Traduction en cours (modèle prêt)
                  if (_enTraduction && !_modeleEnCours)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E3A5F), strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Traduction en cours...',
                            style: TextStyle(
                              fontSize: 12, color: Color(0xFF64748B),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Résultat de la traduction
                  if (_texteTraduIt.isNotEmpty) ...[
                    const Divider(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _langueTraduction.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8), letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'TRADUCTION',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B), letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        // Bouton copier la traduction
                        GestureDetector(
                          onTap: () async {
                            // Copier dans le presse-papier
                            await Clipboard.setData(
                                ClipboardData(text: _texteTraduIt));
                            _afficherMsg(
                              'Traduction copiée !',
                              const Color(0xFF16A34A),
                            );
                          },
                          child: const Icon(Icons.copy_outlined,
                              size: 14, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text(
                        _texteTraduIt,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E3A5F),
                          height: 1.7,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---- Insights clés (Entités ML Kit #3) ----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 5),
                      const Text(
                        'Insights clés',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  const Text(
                    'SUJET IDENTIFIÉ',
                    style: TextStyle(
                      fontSize: 10, color: Colors.white54,
                      letterSpacing: 0.5, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _scanService.detecterMatiere(_texteController.text),
                    style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildEntiteCell(
                        'DATES',
                        '${(_entites['dates'] ?? []).length} trouvées',
                      ),
                      const SizedBox(width: 8),
                      _buildEntiteCell(
                        'LIEUX',
                        '${(_entites['lieux'] ?? []).length} trouvés',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---- Score OCR ----
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fiabilité de la reconnaissance',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      const Expanded(
                        child: Text('Confiance moyenne de ML Kit',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF64748B))),
                      ),
                      Text(
                        _scoreOcr > 0 ? '$_scoreOcr %' : 'n/d',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: _scoreOcr >= 80
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: _scoreOcr / 100,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _scoreOcr >= 80
                          ? const Color(0xFF22C55E)
                          : const Color(0xFFF59E0B),
                    ),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ---- Bouton Analyser ----
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _enSauvegarde ? null : _sauvegarder,
                icon: _enSauvegarde
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _enSauvegarde
                      ? 'Sauvegarde...'
                      : 'Analyser et sauvegarder',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildActionChip(IconData icon, String label,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF475569)),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                )),
          ],
        ),
      ),
    );
  }

  // Widget traduction : Dropdown langue SÉPARÉ du bouton Traduire
  // Fix : le GestureDetector englobant causait une double action
  // (sélection langue + déclenchement immédiat de la traduction)
  Widget _buildTranslateChip() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- Sélecteur de langue (Dropdown seul) ----
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.translate,
                  size: 13, color: Color(0xFF475569)),
              const SizedBox(width: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _langueTraduction,
                  isDense: true,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('EN')),
                    DropdownMenuItem(value: 'fr', child: Text('FR')),
                    DropdownMenuItem(value: 'ar', child: Text('AR')),
                  ],
                  // onChanged change la langue SANS déclencher la traduction
                  onChanged: _changerLangueCible,
                  style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // ---- Bouton Traduire (séparé) ----
        GestureDetector(
          onTap: (_enTraduction || _modeleEnCours) ? null : _traduire,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (_enTraduction || _modeleEnCours)
                  ? const Color(0xFFE2E8F0)
                  : const Color(0xFF1E3A5F),
              borderRadius: BorderRadius.circular(8),
            ),
            child: (_enTraduction || _modeleEnCours)
                ? const SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                      color: Color(0xFF64748B), strokeWidth: 2),
                  )
                : const Text(
                    'Traduire',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildEntiteCell(String label, String valeur) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                  fontSize: 10, color: Colors.white54,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5,
                )),
            const SizedBox(height: 3),
            Text(valeur,
                style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.white,
                )),
          ],
        ),
      ),
    );
  }

}