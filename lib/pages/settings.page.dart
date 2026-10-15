// ============================================================
//  pages/settings.page.dart
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth.service.dart';
import '../services/notification.service.dart';
import '../utils/niveau.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();

  bool   _vibration = true;
  String _nomUser   = 'Étudiant';
  String _emailUser = '';
  int    _points    = 0;

  @override
  void initState() {
    super.initState();
    _chargerPreferences();
  }

  Future<void> _chargerPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final infos = await _authService.getUtilisateur();
    if (!mounted) return;
    setState(() {
      _vibration = prefs.getBool('vibration') ?? true;
      _nomUser   = infos['nom'] ?? 'Étudiant';
      _points    = prefs.getInt('points')     ?? 0;
      _emailUser = (infos['email'] ?? '').isNotEmpty
          ? infos['email']!
          : 'non connecté';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // ---- Modifier le nom ----
  void _modifierNom() {
    final ctrl = TextEditingController(text: _nomUser);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le nom',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Ton nom',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final String nom = ctrl.text.trim();
              if (nom.isEmpty) return;
              // Firebase (displayName) + copie locale : même nom partout
              await _authService.modifierNom(nom);
              if (mounted) setState(() => _nomUser = nom);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Sauvegarder',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---- Notifications ----
  void _ouvrirNotifications() async {
    // Charger l'état actuel
    final etat = await NotificationService().chargerEtatRappels();
    bool rappelsActives     = etat['actives'] as bool;
    TimeOfDay heureRappel   = TimeOfDay(
      hour:   etat['heure']   as int,
      minute: etat['minute']  as int,
    );
    // Jours enregistrés (lundi → vendredi par défaut)
    final List<bool> joursSelects = List<bool>.from(etat['jours'] as List);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_outlined,
                    color: Color(0xFF1D4ED8), size: 18),
              ),
              const SizedBox(width: 10),
              const Text("Rappels d'étude",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Switch activer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.alarm_outlined,
                        size: 18, color: Color(0xFF475569)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Activer les rappels',
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500,
                            color: Color(0xFF1E293B),
                          )),
                    ),
                    Switch(
                      value: rappelsActives,
                      onChanged: (val) =>
                          setDialogState(() => rappelsActives = val),
                      activeThumbColor: const Color(0xFF1E3A5F),
                    ),
                  ],
                ),
              ),

              if (rappelsActives) ...[
                const SizedBox(height: 12),

                // Heure
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_outlined,
                          size: 18, color: Color(0xFF475569)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Heure du rappel',
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500,
                              color: Color(0xFF1E293B),
                            )),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: heureRappel,
                          );
                          if (picked != null) {
                            setDialogState(() => heureRappel = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${heureRappel.hour.toString().padLeft(2, '0')}:${heureRappel.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Jours
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('JOURS',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: Color(0xFF64748B), letterSpacing: 0.5,
                          )),
                      const SizedBox(height: 8),
                      // Sélecteur de jours inline avec setState du dialog
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          const labels = ['D','L','M','M','J','V','S'];
                          return GestureDetector(
                            onTap: () => setDialogState(
                                    () => joursSelects[i] = !joursSelects[i]),
                            child: Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: joursSelects[i]
                                    ? const Color(0xFF1E3A5F)
                                    : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(labels[i],
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: joursSelects[i]
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                    )),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Bouton tester la notification
                GestureDetector(
                  onTap: () async {
                    final bool autorise =
                        await NotificationService().demanderPermission();
                    if (autorise) {
                      await NotificationService().afficherNotificationTest();
                    } else {
                      _afficherMessage(
                          'Autorise les notifications dans les réglages du téléphone.',
                          Colors.orange);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 6),
                        Text('Tester la notification',
                            style: TextStyle(
                              fontSize: 12, color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                // Désactiver et annuler tous les rappels
                await NotificationService().annulerTousRappels();
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Désactiver',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (rappelsActives && !joursSelects.contains(true)) {
                  _afficherMessage('Choisis au moins un jour.', Colors.orange);
                  return;
                }
                if (rappelsActives) {
                  // Android 13+ : demander l'autorisation d'afficher des notifications
                  final bool autorise =
                      await NotificationService().demanderPermission();
                  if (!autorise) {
                    _afficherMessage(
                        'Autorise les notifications dans les réglages du téléphone.',
                        Colors.orange);
                    return;
                  }
                  // Planifier les rappels (jours + heure choisis)
                  await NotificationService().planifierRappel(
                    heure:  heureRappel.hour,
                    minute: heureRappel.minute,
                    jours:  joursSelects,
                  );
                } else {
                  await NotificationService().annulerTousRappels();
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(rappelsActives
                          ? 'Rappel activé à ${heureRappel.hour.toString().padLeft(2, '0')}:${heureRappel.minute.toString().padLeft(2, '0')}'
                          : 'Rappels désactivés'),
                      backgroundColor: const Color(0xFF16A34A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F)),
              child: const Text('Enregistrer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Déconnexion ----
  void _deconnecter() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Se déconnecter',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Es-tu sûr de vouloir te déconnecter ?\nTes données locales seront conservées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _authService.deconnecter();
              if (!mounted) return;
              // Vider la pile et revenir à la page de connexion
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  void _afficherMessage(String msg, Color couleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: couleur,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ---- Changer le mot de passe (Firebase demande l'ancien) ----
  void _changerMotDePasse() {
    final ancienCtrl  = TextEditingController();
    final nouveauCtrl = TextEditingController();
    String? erreur;
    bool enCours = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Changer le mot de passe',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ancienCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe actuel',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nouveauCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe (6 caractères min.)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (erreur != null) ...[
                const SizedBox(height: 10),
                Text(erreur!,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFDC2626))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler',
                  style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: enCours
                  ? null
                  : () async {
                      if (nouveauCtrl.text.length < 6) {
                        setDialogState(() =>
                            erreur = 'Minimum 6 caractères.');
                        return;
                      }
                      setDialogState(() {
                        enCours = true;
                        erreur  = null;
                      });
                      final String? resultat =
                          await _authService.modifierMotDePasse(
                        ancienMdp:  ancienCtrl.text,
                        nouveauMdp: nouveauCtrl.text,
                      );
                      if (resultat != null) {
                        setDialogState(() {
                          enCours = false;
                          erreur  = resultat;
                        });
                        return;
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _afficherMessage('Mot de passe modifié.',
                          const Color(0xFF16A34A));
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F)),
              child: const Text('Valider',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Confidentialité : où sont stockées les données ----
  void _afficherConfidentialite() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Données et vie privée',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '• Les documents scannés, résumés et quiz restent sur ton téléphone '
          '(base SQLite locale).\n\n'
          '• La reconnaissance de texte, la détection de langue, les entités et '
          'la traduction sont faites sur l\'appareil par Google ML Kit. '
          'Internet sert seulement à télécharger les modèles la première fois.\n\n'
          '• Ton compte (nom, e-mail, mot de passe) est géré par Firebase '
          'Authentication.',
          style: TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Fermer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ---- À propos ----
  void _afficherAPropos() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFF1E3A5F), shape: BoxShape.circle),
              child: const Icon(Icons.document_scanner,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('StudyScan',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application mobile éducative développée dans le cadre du module Mobile Development.',
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF374151), height: 1.6),
            ),
            SizedBox(height: 12),
            Text('Version : 1.0.0',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text('Framework : Flutter 3.x',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Fermer',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Paramètres',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _modifierNom,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  _nomUser.isNotEmpty ? _nomUser[0].toUpperCase() : 'E',
                  style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: ListView(
        children: [

          // ---- Profil ----
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFDBEAFE),
                      child: Text(
                        _nomUser.isNotEmpty ? _nomUser[0].toUpperCase() : 'E',
                        style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    GestureDetector(
                      onTap: _modifierNom,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nomUser,
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              )),
                          Text(_emailUser,
                              style: const TextStyle(
                                fontSize: 13, color: Color(0xFF64748B),
                              )),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.edit_outlined,
                        size: 16, color: Color(0xFF94A3B8)),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCD34D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_outline,
                          color: Color(0xFF92400E), size: 16),
                      const SizedBox(width: 8),
                      Text('Niveau : ${niveauDepuisPoints(_points)}',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: Color(0xFF92400E),
                          )),
                      const Spacer(),
                      Text('$_points pts',
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ---- Préférences ----
          _buildSectionHeader('PRÉFÉRENCES'),
          Container(
            color: Colors.white,
            child: Column(
              children: [

                // Notifications
                _buildSettingsRow(
                  icon: Icons.notifications_outlined,
                  label: 'Notifications',
                  description: "Rappels d'étude",
                  trailing: const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFFCBD5E1)),
                  onTap: _ouvrirNotifications,
                ),

                const Divider(height: 1, indent: 20),

                // Vibration
                _buildSettingsRow(
                  icon: Icons.vibration_outlined,
                  label: 'Vibration',
                  description: 'Vibre en cas de mauvaise réponse au quiz',
                  trailing: Switch(
                    value: _vibration,
                    onChanged: (val) {
                      setState(() => _vibration = val);
                      _saveBool('vibration', val);
                    },
                    activeThumbColor: const Color(0xFF1E3A5F),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ---- Compte ----
          _buildSectionHeader('COMPTE'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildSettingsRow(
                  icon: Icons.lock_outline,
                  label: 'Mot de passe',
                  description: 'Changer le mot de passe du compte',
                  trailing: const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFFCBD5E1)),
                  onTap: _changerMotDePasse,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ---- À propos ----
          _buildSectionHeader('À PROPOS'),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildSettingsRow(
                  icon: Icons.info_outline,
                  label: 'À propos de StudyScan',
                  description: 'Version 1.0.0',
                  trailing: const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFFCBD5E1)),
                  onTap: _afficherAPropos,
                ),
                const Divider(height: 1, indent: 20),
                _buildSettingsRow(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Politique de confidentialité',
                  description: 'Données et vie privée',
                  trailing: const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFFCBD5E1)),
                  onTap: _afficherConfidentialite,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ---- Déconnexion ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _deconnecter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: Color(0xFFDC2626), size: 16),
                    SizedBox(width: 8),
                    Text('Se déconnecter',
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        )),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Center(
            child: Text(
              'STUDYSCAN v1.0.0 (BUILD 001)\n2025 — 2026',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required String description,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      )),
                  Text(description,
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8),
                      )),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String titre) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Text(
        titre,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: Color(0xFF64748B), letterSpacing: 0.8,
        ),
      ),
    );
  }
}