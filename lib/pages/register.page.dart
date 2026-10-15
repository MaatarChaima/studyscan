// ============================================================
//  pages/register.page.dart
//  Écran Inscription — Register
//  StatefulWidget, Scaffold, Column
//  TextFormField, Form, GlobalKey, validator, SharedPreferences
//  Navigator.pushReplacementNamed
// ============================================================

import 'package:flutter/material.dart';
import '../services/auth.service.dart';
import '../utils/validation.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();

  // Clé du formulaire
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Contrôleurs des champs
  final TextEditingController _nomController       = TextEditingController();
  final TextEditingController _prenomController    = TextEditingController();
  final TextEditingController _emailController     = TextEditingController();
  final TextEditingController _mdpController       = TextEditingController();
  final TextEditingController _confirmMdpController = TextEditingController();

  // État du formulaire
  bool   _mdpVisible        = false;
  bool   _confirmMdpVisible = false;
  bool   _enChargement      = false;
  String _matiereSelectionnee = 'Général';

  // Liste des matières
  final List<String> _matieres = [
    'Général',
    'Informatique',
    'Mathématiques',
    'Physique',
    'Chimie',
    'Biologie',
    'Histoire',
    'Économie',
    'Droit',
    'Médecine',
  ];

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _mdpController.dispose();
    _confirmMdpController.dispose();
    super.dispose();
  }

  // ---- Soumission du formulaire d'inscription ----
  Future<void> _inscrire() async {
    if (_enChargement) return;     // évite un double envoi
    if (!_formKey.currentState!.validate()) return;

    setState(() => _enChargement = true);

    // inscrire() retourne null si succès, ou un message d'erreur Firebase
    String? erreur = await _authService.inscrire(
      nom:        _nomController.text.trim(),
      prenom:     _prenomController.text.trim(),
      email:      _emailController.text.trim(),
      motDePasse: _mdpController.text,
      matiere:    _matiereSelectionnee,
    );

    if (!mounted) return;
    setState(() => _enChargement = false);

    if (erreur == null) {
      if (mounted) {
        // Afficher un message de succès puis naviguer
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Bienvenue, ${_prenomController.text} ! 🎉',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        // Délai puis navigation
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        }
      }
    } else {
      if (mounted) {
        // Afficher le message Firebase précis
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(erreur)),
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
    }
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

              const SizedBox(height: 32),

              // ---- Logo + Titre ----
              _buildLogo(),

              const SizedBox(height: 28),

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
                        'Créer un compte',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Rejoins StudyScan et commence à apprendre.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ---- Prénom + Nom (sur la même ligne) ----
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Prénom'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _prenomController,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    hint: 'Sami',
                                    icon: Icons.person_outline,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Nom'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nomController,
                                  textCapitalization:
                                      TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    hint: 'Ben Ali',
                                    icon: Icons.badge_outlined,
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Requis';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ---- Email ----
                      _buildLabel('Adresse email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: 'sami@universite.tn',
                          icon: Icons.email_outlined,
                        ),
                        validator: validerEmail,
                      ),

                      const SizedBox(height: 16),

                      // ---- Domaine d'étude ----
                      _buildLabel('Domaine d\'étude'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _matiereSelectionnee,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down,
                                color: Color(0xFF94A3B8)),
                            items: _matieres.map((String m) {
                              return DropdownMenuItem<String>(
                                value: m,
                                child: Row(
                                  children: [
                                    const Icon(Icons.school_outlined,
                                        size: 16,
                                        color: Color(0xFF94A3B8)),
                                    const SizedBox(width: 10),
                                    Text(m,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF374151),
                                        )),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(
                                () => _matiereSelectionnee = val!),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ---- Mot de passe ----
                      _buildLabel('Mot de passe'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _mdpController,
                        obscureText: !_mdpVisible,
                        textInputAction: TextInputAction.next,
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
                            onPressed: () => setState(
                                () => _mdpVisible = !_mdpVisible),
                          ),
                          helperText: 'Minimum 6 caractères',
                          helperStyle: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
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

                      const SizedBox(height: 16),

                      // ---- Confirmation mot de passe ----
                      _buildLabel('Confirmer le mot de passe'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _confirmMdpController,
                        obscureText: !_confirmMdpVisible,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _inscrire(),
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmMdpVisible
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _confirmMdpVisible =
                                    !_confirmMdpVisible),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Confirme ton mot de passe.';
                          }
                          if (val != _mdpController.text) {
                            return 'Les mots de passe ne correspondent pas.';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 28),

                      // ---- Bouton S'inscrire ----
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _enChargement ? null : _inscrire,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.person_add_outlined,
                                        size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'Créer mon compte',
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

              // ---- Lien vers la connexion ----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Déjà un compte ?',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E3A5F),
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
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF1E3A5F),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.document_scanner,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'StudyScan',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Crée ton compte gratuitement',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: Color(0xFFCBD5E1), fontSize: 14),
      prefixIcon:
          Icon(icon, color: const Color(0xFF94A3B8), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 14),
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
            color: Color(0xFF1E3A5F), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
            color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }
}
