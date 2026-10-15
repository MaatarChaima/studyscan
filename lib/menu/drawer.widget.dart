import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth.service.dart';
import '../utils/niveau.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  String _nomUser = 'Étudiant';
  int    _points  = 0;

  @override
  void initState() {
    super.initState();
    _chargerNom();
  }

  Future<void> _chargerNom() async {
    // Même source que l'accueil : nom Firebase, sinon copie locale
    final infos = await AuthService().getUtilisateur();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nomUser = infos['nom'] ?? 'Étudiant';
      _points  = prefs.getInt('points') ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // ---- DrawerHeader ----
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                Row(
                  children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.document_scanner,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'StudyScan',
                      style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Nom utilisateur
                Text(
                  _nomUser,
                  style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                // Points
                Text(
                  '$_points points · ${niveauDepuisPoints(_points)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // ---- Items du menu  ----
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.home_outlined,
                  label: 'Accueil',
                  route: '/',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.document_scanner_outlined,
                  label: 'Scanner',
                  route: '/scan',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.menu_book_outlined,
                  label: 'Bibliothèque',
                  route: '/library',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.bar_chart_outlined,
                  label: 'Insights',
                  route: '/insights',
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.quiz_outlined,
                  label: 'Quiz',
                  route: '/quiz',
                ),

                const Divider(height: 20),

                _buildDrawerItem(
                  context,
                  icon: Icons.settings_outlined,
                  label: 'Paramètres',
                  route: '/settings',
                ),

                // À propos (obligatoire CDC)
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: Color(0xFF64748B), size: 22),
                  title: const Text(
                    'À propos',
                    style: TextStyle(
                      fontSize: 14, color: Color(0xFF374151),
                    ),
                  ),
                  onTap: () {
                    // Récupérer le contexte de la page AVANT de fermer le drawer
                    final pageContext = Navigator.of(context).context;
                    Navigator.pop(context);
                    showDialog(
                      context: pageContext,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        title: const Text('À propos de StudyScan',
                            style: TextStyle(
                                fontWeight: FontWeight.w700)),
                        content: const Text(
                          'StudyScan est une application éducative '
                          'développée en Flutter.\n\n'
                          'Elle utilise Google ML Kit (sur l\'appareil) '
                          'pour le scan de documents, l\'OCR, la détection '
                          'd\'entités, l\'identification de langue et la '
                          'traduction, et Firebase Authentication pour les comptes.\n\n'
                          'Module : Mobile Development',
                          style: TextStyle(
                              fontSize: 13, height: 1.6),
                        ),
                        actions: [
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(ctx).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF1E3A5F),
                            ),
                            child: const Text('Fermer',
                                style: TextStyle(
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const Divider(height: 1),

                // Déconnexion depuis le Drawer
                ListTile(
                  leading: const Icon(Icons.logout,
                      color: Color(0xFFDC2626), size: 22),
                  title: const Text(
                    'Se déconnecter',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    // Le drawer va être fermé : on garde le Navigator de la page
                    final navigator = Navigator.of(context);
                    navigator.pop();                        // 1. Fermer le drawer
                    await AuthService().deconnecter();      // 2. Déconnexion Firebase
                    // 3. Vider toute la pile et revenir à la connexion
                    navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                ),
              ],
            ),
          ),

          // ---- Pied du Drawer ----
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'StudyScan v1.0.0',
              style: TextStyle(
                fontSize: 11, color: Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ListTile de navigation
  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF64748B), size: 22),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 14, color: Color(0xFF374151),
        ),
      ),
      onTap: () {
        final navigator = Navigator.of(context);
        navigator.pop();                                   // Fermer le drawer
        if (route == '/') {
          // Accueil : repartir d'une pile propre
          navigator.pushNamedAndRemoveUntil('/', (r) => false);
        } else {
          navigator.pushNamed(route);
        }
      },
    );
  }
}
