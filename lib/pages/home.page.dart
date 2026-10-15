import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan.model.dart';
import '../services/auth.service.dart';
import '../services/scan.service.dart';
import '../utils/niveau.dart';
import '../utils/route_observer.dart';
import '../widgets/scan_card.widget.dart';
import '../menu/drawer.widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with RouteAware {
  final ScanService _scanService = ScanService();

  String _nomUtilisateur = 'Étudiant';
  int _points = 0;
  late Future<List<ScanModel>> _scansFuture;

  @override
  void initState() {
    super.initState();
    _scansFuture = _scanService.listeScans();
    _chargerPreferences();
  }

  Future<void> _chargerPreferences() async {
    final infos = await AuthService().getUtilisateur();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nomUtilisateur = infos['nom'] ?? 'Étudiant';
      _points = prefs.getInt('points') ?? 0;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Retour sur l'accueil (après un scan, un quiz, un changement de nom…) :
  // recharger points, nom et scans
  @override
  void didPopNext() {
    setState(() => _scansFuture = _scanService.listeScans());
    _chargerPreferences();
  }

  void _ouvrir(String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  String get _texteProgression {
    final String? suivant = niveauSuivant(_points);
    if (suivant == null) return 'Niveau maximum atteint : Expert';
    return '${pointsAvantNiveauSuivant(_points)} pts pour atteindre $suivant';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A5F), shape: BoxShape.circle),
              child: const Icon(Icons.document_scanner,
                  color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('StudyScan',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: Color(0xFF64748B)),
            onPressed: () => _ouvrir('/settings'),
          ),
        ],
      ),

      drawer: const MyDrawer(),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              color: Colors.white,
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, $_nomUtilisateur.',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Prêt à transformer tes notes ?',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'NOUVELLE SESSION',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Colors.white, letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Scanne tes documents pour créer des guides d\'étude instantanés.',
                      style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _ouvrir('/scan'),
                        icon: const Icon(Icons.document_scanner,
                            color: Colors.white),
                        label: const Text('Scanner un document'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PROGRESSION D\'APPRENTISSAGE',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B), letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('$_points',
                            style: const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            )),
                        const SizedBox(width: 4),
                        const Text('PTS',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: Color(0xFF94A3B8),
                            )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressionNiveau(_points),
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF1E3A5F),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${niveauDepuisPoints(_points)} · $_texteProgression',
                      style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildBadge(Icons.bolt, const Color(0xFFFEF3C7),
                            const Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        _buildBadge(Icons.add_circle_outline,
                            const Color(0xFFDCFCE7),
                            const Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        _buildBadge(Icons.local_fire_department,
                            const Color(0xFFFEE2E2),
                            const Color(0xFFDC2626)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Scans récents',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _ouvrir('/library'),
                    child: const Text(
                      'Voir la bibliothèque',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: FutureBuilder<List<ScanModel>>(
                future: _scansFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1E3A5F)),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.document_scanner_outlined,
                              size: 48, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 12),
                          Text('Aucun scan pour le moment.',
                              style: TextStyle(
                                fontSize: 14, color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    );
                  }
                  final scans = snapshot.data!.take(3).toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: scans.length,
                    itemBuilder: (context, index) {
                      return ScanCardWidget(
                        scan: scans[index],
                        // Un scan déjà enregistré s'ouvre sur ses insights
                        // (la page OCR créerait un doublon en sauvegardant)
                        onTap: () =>
                            _ouvrir('/insights', arguments: scans[index]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, Color bg, Color color) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: bg,
          borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
