// ============================================================
//  utils/scan.database.dart
//  SQLite avec sqflite + path
// ============================================================

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/scan.model.dart';
import '../models/quiz.model.dart';

class ScanDatabase {
  // Instance unique
  static Database? _database;

  // Initialisation de la base de données
  Future<Database> initDB() async {
    if (_database == null) {
      // Récupérer le chemin vers le dossier de la BDD
      String databasePath = await getDatabasesPath();
      String path = join(databasePath, 'studyscan.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
      );
    }
    return _database!;
  }

  // Création des tables au premier lancement
  Future<void> _onCreate(Database db, int version) async {
    // Table des scans
    await db.execute('''
      CREATE TABLE scans (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        titre        TEXT NOT NULL,
        texteOcr     TEXT,
        resume       TEXT,
        motsCles     TEXT,
        langue       TEXT,
        matiere      TEXT,
        dateCreation TEXT,
        scoreOcr     INTEGER,
        points       INTEGER
      )
    ''');

    // Table des questions de quiz
    await db.execute('''
      CREATE TABLE quiz_questions (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        scanId       INTEGER,
        question     TEXT,
        optionA      TEXT,
        optionB      TEXT,
        optionC      TEXT,
        optionD      TEXT,
        bonneReponse TEXT,
        type         TEXT,
        difficulte   TEXT,
        FOREIGN KEY (scanId) REFERENCES scans(id)
      )
    ''');
  }

  // ---- CRUD Scans ----

  // Insérer un scan
  Future<int> insertScan(ScanModel scan) async {
    Database db = await initDB();
    return await db.insert('scans', scan.toJson());
  }

  // Lire tous les scans
  Future<List<ScanModel>> listeScans() async {
    Database db = await initDB();
    List<Map<String, dynamic>> result =
        await db.query('scans', orderBy: 'id DESC');
    return result.map((e) => ScanModel.fromJson(e)).toList();
  }

  // Lire un scan par ID
  Future<ScanModel?> getScan(int id) async {
    Database db = await initDB();
    List<Map<String, dynamic>> result =
        await db.query('scans', where: 'id = ?', whereArgs: [id]);
    if (result.isEmpty) return null;
    return ScanModel.fromJson(result.first);
  }

  // Modifier un scan
  Future<int> modifierScan(ScanModel scan) async {
    Database db = await initDB();
    return await db.update(
      'scans',
      scan.toJson(),
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  // Supprimer un scan
  Future<int> supprimerScan(ScanModel scan) async {
    Database db = await initDB();
    // Supprimer d'abord les questions associées
    await db.delete('quiz_questions',
        where: 'scanId = ?', whereArgs: [scan.id]);
    return await db.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [scan.id],
    );
  }

  // Compter le nombre total de scans
  Future<int> countScans() async {
    Database db = await initDB();
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM scans'),
        ) ??
        0;
  }

  // ---- CRUD Quiz Questions ----

  // Insérer une question
  Future<int> insertQuestion(QuizQuestion question) async {
    Database db = await initDB();
    return await db.insert('quiz_questions', question.toJson());
  }

  // Lire les questions d'un scan
  Future<List<QuizQuestion>> listeQuestions(int scanId) async {
    Database db = await initDB();
    List<Map<String, dynamic>> result = await db.query(
      'quiz_questions',
      where: 'scanId = ?',
      whereArgs: [scanId],
    );
    return result.map((e) => QuizQuestion.fromJson(e)).toList();
  }

  // Supprimer toutes les questions d'un scan
  Future<int> supprimerQuestions(int scanId) async {
    Database db = await initDB();
    return await db.delete('quiz_questions',
        where: 'scanId = ?', whereArgs: [scanId]);
  }
}
