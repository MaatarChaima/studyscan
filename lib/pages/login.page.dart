import 'package:flutter/material.dart';
import '../services/auth.service.dart';
import '../utils/validation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();

  // Clé du formulaire
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Contrôleurs des champs
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _mdpController      = TextEditingController();

  bool _mdpVisible   = false;   // Afficher/masquer le mot de passe
  bool _enChargement = false;   // Indicateur de chargement

  @override
  void dispose() {
    _emailController.dispose();
    _mdpController.dispose();
    super.dispose();
  }

  // ---- Soumission du formulaire de connexion ----
  Future<void> _connecter() async {
    if (_enChargement) return;     // évite un double envoi (Entrée + bouton)
    // Valider tous les champs du formulaire
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enChargement = true);

    // connecter() retourne null si succès, ou un message d'erreur
    String? erreur = await _authService.connecter(
      email:      _emailController.text.trim(),
      motDePasse: _mdpController.text,
    );

    if (!mounted) return;
    setState(() => _enChargement = false);

    if (erreur == null) {
      // Accueil, sans possibilité de revenir sur la connexion
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    } else {
      if (mounted) {
        // Afficher le message Firebase (ex: "Utilisateur inexistant")
        _afficherErreur(erreur);
      }
    }
  }

  // ---- Mot de passe oublié ----
  Future<void> _motDePasseOublie() async {
    final String email = _emailController.text.trim();
    if (validerEmail(email) != null) {
      _afficherErreur('Saisis d\'abord ton e-mail ci-dessus.');
      return;
    }
    final String? erreur = await _authService.reinitialiserMotDePasse(email);
    if (!mounted) return;
    if (erreur != null) {
      _afficherErreur(erreur);
      return;
    }
    // Message neutre : Firebase ne dit pas si le compte existe
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Si un compte existe pour $email, '
            'un e-mail de réinitialisation a été envoyé.'),
        backgroundColor: const Color(0xFF16A34A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              const SizedBox(height: 48),

              // ---- Logo + Titre ----
              _buildLogo(),

              const SizedBox(height: 40),

              // ---- Carte du formulaire ----
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      const Text(
                        'Connexion',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Bienvenue ! Connecte-toi pour continuer.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ---- Champ Email ----
                      _buildLabel('Adresse email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: 'exemple@universite.tn',
                          icon: Icons.email_outlined,
                        ),
                        // Validation
                        validator: validerEmail,
                      ),

                      const SizedBox(height: 16),

                      // ---- Champ Mot de passe ----
                      _buildLabel('Mot de passe'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _mdpController,
                        obscureText: !_mdpVisible,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _connecter(),
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _mdpVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _mdpVisible = !_mdpVisible),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Le mot de passe est obligatoire.';
                          }
                          if (val.length < 6) {
                            return 'Minimum 6 caractères.';
                          }
                          return null;
                        },
                      ),

                      // ---- Mot de passe oublié ----
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _enChargement ? null : _motDePasseOublie,
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ---- Bouton Se connecter ----
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _enChargement ? null : _connecter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _enChargement
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.login, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ---- Lien vers l'inscription ----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Pas encore de compte ?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text(
                      'S\'inscrire',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---- Widget Logo ----
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.document_scanner,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'StudyScan',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Scanne · Apprends · Progresse',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ---- Widget Label de champ ----
  Widget _buildLabel(String texte) {
    return Text(
      texte,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF374151),
      ),
    );
  }

  // ---- Décoration commune des champs ----
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF1E3A5F),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.5,
        ),
      ),
    );
  }
}
