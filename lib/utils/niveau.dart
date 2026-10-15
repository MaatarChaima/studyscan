// ============================================================
//  utils/niveau.dart
//  Niveaux de l'étudiant selon ses points (gamification)
//  Utilisé par l'accueil, le menu et les paramètres
// ============================================================

// Seuil de points à partir duquel chaque niveau commence
const List<int> _seuils = [0, 500, 1500, 3000];
const List<String> _niveaux = ['Débutant', 'Érudit I', 'Érudit II', 'Expert'];

int _indexNiveau(int points) {
  int index = 0;
  for (int i = 0; i < _seuils.length; i++) {
    if (points >= _seuils[i]) index = i;
  }
  return index;
}

String niveauDepuisPoints(int points) => _niveaux[_indexNiveau(points)];

// Niveau suivant, ou null si le niveau maximum est atteint
String? niveauSuivant(int points) {
  final int i = _indexNiveau(points);
  return i + 1 < _niveaux.length ? _niveaux[i + 1] : null;
}

// Points restants avant le niveau suivant (0 au niveau maximum)
int pointsAvantNiveauSuivant(int points) {
  final int i = _indexNiveau(points);
  return i + 1 < _seuils.length ? _seuils[i + 1] - points : 0;
}

// Progression dans le niveau courant, entre 0 et 1
double progressionNiveau(int points) {
  final int i = _indexNiveau(points);
  if (i + 1 >= _seuils.length) return 1.0;
  return (points - _seuils[i]) / (_seuils[i + 1] - _seuils[i]);
}
