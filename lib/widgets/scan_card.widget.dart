// ============================================================
//  widgets/scan_card.widget.dart
//  StatelessWidget avec paramètres
//  Utilisé dans HomePage et LibraryPage
// ============================================================

import 'package:flutter/material.dart';
import '../models/scan.model.dart';

class ScanCardWidget extends StatelessWidget {
  final ScanModel scan;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ScanCardWidget({
    super.key,
    required this.scan,
    required this.onTap,
    this.onDelete,
  });

  // Couleur de tag selon la matière
  Color _tagColor(String matiere) {
    switch (matiere.toUpperCase()) {
      case 'CHIMIE':    return const Color(0xFF1D4ED8);
      case 'BIOLOGIE':  return const Color(0xFF065F46);
      case 'HISTOIRE':  return const Color(0xFF92400E);
      case 'CALCUL':
      case 'MATHS':     return const Color(0xFF5B21B6);
      case 'ÉCONOMIE':  return const Color(0xFF92400E);
      default:          return const Color(0xFF374151);
    }
  }

  Color _tagBg(String matiere) {
    switch (matiere.toUpperCase()) {
      case 'CHIMIE':    return const Color(0xFFDBEAFE);
      case 'BIOLOGIE':  return const Color(0xFFD1FAE5);
      case 'HISTOIRE':  return const Color(0xFFFEF3C7);
      case 'CALCUL':
      case 'MATHS':     return const Color(0xFFEDE9FE);
      case 'ÉCONOMIE':  return const Color(0xFFFEF3C7);
      default:          return const Color(0xFFF3F4F6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature du scan
            Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.description_outlined,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 40,
                ),
              ),
            ),

            // Informations du scan
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre
                  Text(
                    scan.titre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),

                  Row(
                    children: [
                      // Date
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        scan.dateCreation,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const Spacer(),

                      // Tag matière
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _tagBg(scan.matiere),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          scan.matiere,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _tagColor(scan.matiere),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Bouton supprimer (optionnel)
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Barre de progression OCR
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: scan.scoreOcr / 100,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scan.scoreOcr >= 80
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFF59E0B),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        scan.scoreOcr > 0 ? '${scan.scoreOcr}% OCR' : 'OCR n/d',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scan.scoreOcr >= 80
                              ? const Color(0xFF1E3A5F)
                              : const Color(0xFFD97706),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
