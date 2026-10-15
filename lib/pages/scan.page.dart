// ============================================================
//  pages/scan.page.dart
//  Scanner (Caméra / Galerie)
//  StatefulWidget, Scaffold, setState
//  Concepts ML Kit : DocumentScanner, TextRecognizer
//  Package : image_picker (galerie)
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import '../services/scan.service.dart';


class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ScanService _scanService = ScanService();
  final ImagePicker _picker = ImagePicker();

  bool _enChargement = false;
  bool _multiPages   = false;       // MULTI : jusqu'à 5 pages par scan
  String _messageEtat = 'PRÊT À SCANNER';

  void _etat(String message, {required bool chargement}) {
    if (!mounted) return;
    setState(() {
      _messageEtat  = message;
      _enChargement = chargement;
    });
  }

  // ---- Scan via ML Kit DocumentScanner (interface caméra de Google) ----
  Future<void> _lancerScanner() async {
    if (_enChargement) return;
    _etat('DÉTECTION EN COURS...', chargement: true);

    final documentScanner = DocumentScanner(
      options: DocumentScannerOptions(
        mode: ScannerMode.full,            // Détection automatique des bords
        isGalleryImport: false,
        pageLimit: _multiPages ? 5 : 1,
      ),
    );

    try {
      final DocumentScanningResult result =
          await documentScanner.scanDocument();

      final List<String> pages = result.images ?? [];
      if (pages.isNotEmpty) {
        await _traiterImages(pages.map((chemin) => File(chemin)).toList());
      }
    } catch (e) {
      _afficherErreur('Erreur scanner : $e');
    } finally {
      await documentScanner.close();
      _etat('PRÊT À SCANNER', chargement: false);
    }
  }

  // ---- Import depuis la galerie (image_picker) ----
  Future<void> _importerGalerie() async {
    if (_enChargement) return;
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (photo == null) return;

      _etat('OCR EN COURS...', chargement: true);
      await _traiterImages([File(photo.path)]);
    } catch (e) {
      _afficherErreur('Erreur galerie : $e');
    } finally {
      _etat('PRÊT À SCANNER', chargement: false);
    }
  }

  // ---- Traitement commun : OCR de chaque page + analyse + page résultat ----
  Future<void> _traiterImages(List<File> images) async {
    try {
      final List<String> textes = [];
      int sommeConfiance = 0;
      int nbConfiance = 0;

      for (int i = 0; i < images.length; i++) {
        if (images.length > 1) {
          _etat('OCR PAGE ${i + 1}/${images.length}...', chargement: true);
        }
        final resultat = await _scanService.extraireTexte(images[i]);
        if (resultat.texte.trim().isNotEmpty) textes.add(resultat.texte);
        if (resultat.confiance != null) {
          sommeConfiance += resultat.confiance!;
          nbConfiance++;
        }
      }

      final String texteExtrait = textes.join('\n\n');
      if (texteExtrait.trim().isEmpty) {
        _afficherErreur(
            'Aucun texte détecté. Essaie avec une image plus nette.');
        return;
      }

      _etat('ANALYSE...', chargement: true);

      // Identification de la langue (ML Kit)
      final String langue = await _scanService.identifierLangue(texteExtrait);

      // Extraction d'entités : dates, adresses… (ML Kit)
      final Map<String, List<String>> entites =
          await _scanService.extraireEntites(texteExtrait);

      // Confiance moyenne donnée par ML Kit (0 si non disponible)
      final int scoreOcr =
          nbConfiance == 0 ? 0 : (sommeConfiance / nbConfiance).round();

      // La page scanner est remplacée : le retour depuis le résultat
      // ramène à la page précédente (accueil ou bibliothèque)
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/ocr',
          arguments: {
            'texte':    texteExtrait,
            'langue':   langue,
            'entites':  entites,
            'scoreOcr': scoreOcr,
            'image':    images.first.path,   // aperçu de la 1re page
          },
        );
      }
    } catch (e) {
      _afficherErreur('Erreur OCR : $e');
    }
  }

  void _afficherErreur(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // ---- AppBar sombre ----
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Colors.white70),
            onPressed: () =>
                Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),

      body: Column(
        children: [

          // ---- Zone caméra / Viewfinder ----
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fond simulant la caméra
                Container(
                  width: double.infinity,
                  color: const Color(0xFF0D1A0D),
                  child: const Center(
                    child: Icon(
                      Icons.document_scanner_outlined,
                      color: Colors.white12,
                      size: 80,
                    ),
                  ),
                ),

                // Cadre de scan (coins orange)
                _buildScanFrame(),

                // Badge "PRÊT À SCANNER" en haut
                Positioned(
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        // Point clignotant
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(seconds: 1),
                          builder: (_, val, _) => Container(
                            width: 8, height: 8,
                            decoration: BoxDecoration(
                              color: Color.lerp(
                                  Colors.orange, Colors.transparent, val),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _messageEtat,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Carte "Détection automatique"
                Positioned(
                  bottom: 30,
                  child: Container(
                    width: 260,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lightbulb_outline,
                                  color: Color(0xFF1D4ED8), size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Scanner de documents',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'Appuie sur le bouton central : les bords '
                                    'sont détectés automatiquement.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Barre de progression pendant le traitement
                        if (_enChargement) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              backgroundColor: Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF22C55E),
                              ),
                              minHeight: 3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Indicateur de chargement
                if (_enChargement)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFF97316),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---- Modes de scan ----
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildModeBtn('1 PAGE', multi: false),
                const SizedBox(width: 10),
                _buildModeBtn('MULTI-PAGES (5 MAX)', multi: true),
              ],
            ),
          ),

          // ---- Contrôles bas : Galerie | Déclencheur | Multi ----
          Container(
            color: const Color(0xFF111111),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Bouton Galerie
                GestureDetector(
                  onTap: _enChargement ? null : _importerGalerie,
                  child: Column(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.photo_library_outlined,
                            color: Colors.white70, size: 22),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'GALERIE',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Déclencheur principal (Shutter)
                GestureDetector(
                  onTap: _enChargement ? null : _lancerScanner,
                  child: Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 4),
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.document_scanner,
                        color: Color(0xFF1E3A5F),
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // Bouton Multi-pages (active / désactive)
                GestureDetector(
                  onTap: () => setState(() => _multiPages = !_multiPages),
                  child: Column(
                    children: [
                      Container(
                        width: 46, height: 46,
                        decoration: BoxDecoration(
                          color: _multiPages
                              ? const Color(0xFF1D4ED8)
                              : Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.copy_all_outlined,
                            color: Colors.white70, size: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _multiPages ? 'MULTI ✓' : 'MULTI',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Cadre de visée avec coins orange
  Widget _buildScanFrame() {
    const double taille = 24;
    const double epaisseur = 3;
    const couleur = Color(0xFFF97316);

    Widget coin({bool top = true, bool left = true}) {
      return Container(
        width: taille, height: taille,
        decoration: BoxDecoration(
          border: Border(
            top:    top   ? const BorderSide(color: couleur, width: epaisseur) : BorderSide.none,
            bottom: !top  ? const BorderSide(color: couleur, width: epaisseur) : BorderSide.none,
            left:   left  ? const BorderSide(color: couleur, width: epaisseur) : BorderSide.none,
            right:  !left ? const BorderSide(color: couleur, width: epaisseur) : BorderSide.none,
          ),
        ),
      );
    }

    return SizedBox(
      width: 260, height: 180,
      child: Stack(
        children: [
          Positioned(top: 0, left: 0,  child: coin(top: true,  left: true)),
          Positioned(top: 0, right: 0, child: coin(top: true,  left: false)),
          Positioned(bottom: 0, left: 0,  child: coin(top: false, left: true)),
          Positioned(bottom: 0, right: 0, child: coin(top: false, left: false)),
        ],
      ),
    );
  }

  // Bouton de mode scan : une page ou plusieurs pages
  Widget _buildModeBtn(String mode, {required bool multi}) {
    final bool actif = _multiPages == multi;
    return GestureDetector(
      onTap: () => setState(() => _multiPages = multi),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: actif
              ? const Color(0xFF1D4ED8)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          mode,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: actif ? Colors.white : Colors.white60,
          ),
        ),
      ),
    );
  }

}