// ============================================================
//  utils/validation.dart
//  Validation commune des formulaires (connexion, inscription)
// ============================================================

final RegExp _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validerEmail(String? val) {
  if (val == null || val.trim().isEmpty) {
    return 'L\'email est obligatoire.';
  }
  if (!_regexEmail.hasMatch(val.trim())) {
    return 'Format d\'email invalide.';
  }
  return null;
}
