class ScanModel {
  int? id;
  String titre;
  String texteOcr;
  String resume;
  String motsCles;       // Stocké en JSON string : "mot1,mot2,mot3"
  String langue;         // 'fr', 'en', 'ar'
  String matiere;        // Ex: "CHIMIE", "HISTOIRE"
  String dateCreation;   // Format jj/mm/aaaa (intl)
  int scoreOcr;          // Pourcentage de fiabilité OCR (0-100)
  int points;            // Points gamification

  // Constructeur
  ScanModel({
    this.id,
    required this.titre,
    required this.texteOcr,
    this.resume = '',
    this.motsCles = '',
    this.langue = 'fr',
    this.matiere = 'GÉNÉRAL',
    required this.dateCreation,
    this.scoreOcr = 0,
    this.points = 50,
  });

  // Méthode fromJson() : convertit un Map en ScanModel
  factory ScanModel.fromJson(Map<String, dynamic> json) {
    return ScanModel(
      id:           json['id'],
      titre:        json['titre'],
      texteOcr:     json['texteOcr'],
      resume:       json['resume'] ?? '',
      motsCles:     json['motsCles'] ?? '',
      langue:       json['langue'] ?? 'fr',
      matiere:      json['matiere'] ?? 'GÉNÉRAL',
      dateCreation: json['dateCreation'],
      scoreOcr:     json['scoreOcr'] ?? 0,
      points:       json['points'] ?? 50,
    );
  }

  // Méthode toJson() : convertit un ScanModel en Map
  Map<String, dynamic> toJson() {
    return {
      'id':           id,
      'titre':        titre,
      'texteOcr':     texteOcr,
      'resume':       resume,
      'motsCles':     motsCles,
      'langue':       langue,
      'matiere':      matiere,
      'dateCreation': dateCreation,
      'scoreOcr':     scoreOcr,
      'points':       points,
    };
  }
}
