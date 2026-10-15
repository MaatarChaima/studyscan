class QuizQuestion {
  int? id;
  int scanId;           // Référence au scan parent
  String question;
  String optionA;
  String optionB;
  String optionC;
  String optionD;
  String bonneReponse;  // 'A', 'B', 'C' ou 'D'
  String type;          // 'qcm' ou 'vrai_faux'
  String difficulte;    // 'facile', 'moyen', 'difficile'

  QuizQuestion({
    this.id,
    required this.scanId,
    required this.question,
    this.optionA = '',
    this.optionB = '',
    this.optionC = '',
    this.optionD = '',
    required this.bonneReponse,
    this.type = 'qcm',
    this.difficulte = 'moyen',
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id:           json['id'],
      scanId:       json['scanId'],
      question:     json['question'],
      optionA:      json['optionA'] ?? '',
      optionB:      json['optionB'] ?? '',
      optionC:      json['optionC'] ?? '',
      optionD:      json['optionD'] ?? '',
      bonneReponse: json['bonneReponse'],
      type:         json['type'] ?? 'qcm',
      difficulte:   json['difficulte'] ?? 'moyen',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id':           id,
      'scanId':       scanId,
      'question':     question,
      'optionA':      optionA,
      'optionB':      optionB,
      'optionC':      optionC,
      'optionD':      optionD,
      'bonneReponse': bonneReponse,
      'type':         type,
      'difficulte':   difficulte,
    };
  }
}
