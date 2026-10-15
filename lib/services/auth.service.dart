// ============================================================
//  services/auth.service.dart
//  Authentification Firebase (e-mail + mot de passe)
//  createUserWithEmailAndPassword(), signInWithEmailAndPassword(), signOut()
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Instance FirebaseAuth
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // -------------------------------------------------------
  //  INSCRIPTION — createUserWithEmailAndPassword
  // -------------------------------------------------------
  Future<String?> inscrire({
    required String nom,
    required String prenom,
    required String email,
    required String motDePasse,
    String matiere = 'Général',
  }) async {
    try {
      // Création du compte Firebase
      await _auth.createUserWithEmailAndPassword(
        email:    email,
        password: motDePasse,
      );
      // Mettre à jour le displayName avec prénom + nom
      await _auth.currentUser?.updateDisplayName('$prenom $nom');
      // Sauvegarder localement pour affichage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nomUser', '$prenom $nom');
      await prefs.setString('matiere', matiere);
      return null; // null = succès
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'Email déjà utilisé par un autre compte.';
        case 'weak-password':
          return 'Mot de passe trop faible (minimum 6 caractères).';
        case 'invalid-email':
          return 'Format d\'email invalide.';
        default:
          return 'Erreur d\'inscription : ${e.message}';
      }
    }
  }

  // -------------------------------------------------------
  //  CONNEXION — signInWithEmailAndPassword
  // -------------------------------------------------------
  Future<String?> connecter({
    required String email,
    required String motDePasse,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email:    email,
        password: motDePasse,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        // Firebase renvoie 'invalid-credential' dans les deux cas
        // (protection contre la découverte des e-mails inscrits)
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'E-mail ou mot de passe incorrect.';
        case 'invalid-email':
          return 'Format d\'email invalide.';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessaie plus tard.';
        default:
          return 'Erreur de connexion : ${e.message}';
      }
    }
  }

  // -------------------------------------------------------
  //  DÉCONNEXION — signOut
  // -------------------------------------------------------
  Future<void> deconnecter() async {
    await _auth.signOut();
  }

  // Utilisateur courant Firebase
  User? get utilisateurCourant => _auth.currentUser;

  // Vérifier si connecté.
  // authStateChanges().first attend que Firebase ait restauré la session
  // enregistrée sur le téléphone (currentUser peut être null au démarrage).
  Future<bool> estConnecte() async =>
      (await _auth.authStateChanges().first) != null;

  // Stream authStateChanges
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ---- Modifier le nom affiché (Firebase + copie locale) ----
  Future<void> modifierNom(String nom) async {
    await _auth.currentUser?.updateDisplayName(nom);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nomUser', nom);
  }

  // Infos utilisateur courant
  Future<Map<String, String>> getUtilisateur() async {
    User? user = _auth.currentUser;
    final prefs = await SharedPreferences.getInstance();
    return {
      'nom':     user?.displayName ?? prefs.getString('nomUser') ?? 'Étudiant',
      'email':   user?.email ?? '',
      'uid':     user?.uid ?? '',
      'matiere': prefs.getString('matiere') ?? 'Général',
    };
  }
  // ---- Mot de passe oublié : e-mail de réinitialisation Firebase ----
  Future<String?> reinitialiserMotDePasse(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') return 'Format d\'email invalide.';
      return 'Erreur : ${e.message}';
    }
  }

  // ---- MODIFIER le mot de passe via Firebase ----
  Future<String?> modifierMotDePasse({
    required String ancienMdp,
    required String nouveauMdp,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Non connecté.';

      // Ré-authentifier avant de changer le mot de passe (Firebase l'exige)
      final credential = EmailAuthProvider.credential(
        email:    user.email!,
        password: ancienMdp,
      );
      await user.reauthenticateWithCredential(credential);

      // Changer le mot de passe
      await user.updatePassword(nouveauMdp);
      return null; // null = succès
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Ancien mot de passe incorrect.';
        case 'weak-password':
          return 'Nouveau mot de passe trop faible (minimum 6 caractères).';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessaie plus tard.';
        default:
          return 'Erreur : ${e.message}';
      }
    }
  }
}
