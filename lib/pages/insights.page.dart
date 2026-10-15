import 'package:flutter/material.dart';
import '../models/scan.model.dart';
import '../services/scan.service.dart';


class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final ScanService _scanService = ScanService();
  ScanModel? _scan;
  List<String> _motsCles = [];
  bool _chargement = true;
  bool _argumentsLus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsLus) return;
    _argumentsLus = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ScanModel) {
      _afficherScan(args);
    } else {
      // Ouvert depuis le menu : afficher le dernier scan enregistré
      _chargerDernierScan();
    }
  }

  Future<void> _chargerDernierScan() async {
    final scans = await _scanService.listeScans(); // triés du plus récent
    if (!mounted) return;
    if (scans.isEmpty) {
      setState(() => _chargement = false);
    } else {
      _afficherScan(scans.first);
    }
  }

  void _afficherScan(ScanModel scan) {
    setState(() {
      _scan       = scan;
      _chargement = false;
      _motsCles   = scan.motsCles.isNotEmpty
          ? scan.motsCles.split(',')
          : _scanService.extraireMotsCles(scan.texteOcr);
    });
  }

  // Corriger le texte OCR, puis revenir avec le scan mis à jour
  Future<void> _corrigerTexte() async {
    final resultat =
        await Navigator.pushNamed(context, '/ocr', arguments: _scan);
    if (resultat is ScanModel && mounted) _afficherScan(resultat);
  }

  int get _nbMots {
    if (_scan == null) return 0;
    return _scan!.texteOcr
        .split(RegExp(r'\s+'))
        .where((m) => m.isNotEmpty)
        .length;
  }

  // « Matière détectée » seulement si le texte a vraiment permis de la
  // reconnaître ; sinon c'est la matière choisie à l'inscription
  String get _libelleMatiere {
    final String matiere = _scan!.matiere;
    if (matiere == 'GÉNÉRAL') return 'Matière';
    return _scanService.detecterMatiere(_scan!.texteOcr) == matiere
        ? 'Matière détectée'
        : 'Matière (profil)';
  }

  // Temps de lecture estimé (200 mots / minute, au moins 1 min)
  int get _tempsLecture => _nbMots == 0 ? 0 : (_nbMots / 200).ceil();

  int get _nbConcepts => _motsCles.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F), shape: BoxShape.circle),
              child: const Icon(Icons.document_scanner,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('StudyScan',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFF64748B)),
            onPressed: () =>
                Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),

      body: _chargement
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E3A5F)))
          : _scan == null
          ? _buildVide()
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge IA
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Color(0xFF1D4ED8), size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        'INSIGHTS D\'ÉTUDE',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8), letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  Text(
                    _scan!.titre,
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Matière : ${_scan!.matiere}',
                    style: const TextStyle(
                      fontSize: 13, color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---- Résumé ----
                  Container(
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Résumé',
                              style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _scan!.scoreOcr > 0
                                    ? '${_scan!.scoreOcr} %\nOCR'
                                    : 'OCR\nn/d',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _scan!.resume.isNotEmpty
                              ? _scan!.resume
                              : _scanService.genererResume(_scan!.texteOcr),
                          style: const TextStyle(
                            fontSize: 13, color: Color(0xFF374151),
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ---- Statistiques ----
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.8,
                    children: [
                      _buildStatCard(
                        '$_nbMots',
                        'Mots scannés',
                        color: const Color(0xFF1E3A5F),
                      ),
                      _buildStatCard(
                        '$_nbConcepts',
                        'Concepts clés',
                        color: const Color(0xFF1E3A5F),
                      ),
                      _buildStatCard(
                        '$_tempsLecture min',
                        'Durée de lecture',
                        color: const Color(0xFF1E3A5F),
                      ),
                      _buildStatCard(
                        _scan!.matiere,
                        _libelleMatiere,
                        color: const Color(0xFFD97706),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ---- Mots-clés ----
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
                        const Row(
                          children: [
                            Icon(Icons.label_outline,
                                size: 15, color: Color(0xFF1E3A5F)),
                            SizedBox(width: 6),
                            Text(
                              'Termes clés',
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7, runSpacing: 7,
                          children: _motsCles.map((mc) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                border: Border.all(
                                    color: const Color(0xFFBFDBFE)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                mc,
                                style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ---- Bouton Lancer le Quiz ----
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(
                        context,
                        '/quiz',
                        arguments: _scan,
                      ),
                      icon: const Icon(Icons.quiz_outlined),
                      label: const Text('Lancer le Quiz'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ---- Corriger le texte (met à jour le scan) ----
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _corrigerTexte,
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Corriger le texte scanné'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A5F),
                        side: const BorderSide(color: Color(0xFF1E3A5F)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
    );
  }

  Widget _buildVide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bar_chart, size: 60, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text(
            'Aucun document analysé.',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            child: const Text('Scanner un document',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String valeur, String label,
      {Color color = const Color(0xFF1E3A5F)}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Une seule ligne : un texte long (ex. « INFORMATIQUE ») est
          // réduit pour tenir dans la carte au lieu de déborder
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valeur,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color,
                )),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11, color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              )),
        ],
      ),
    );
  }

}