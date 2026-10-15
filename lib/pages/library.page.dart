import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan.model.dart';
import '../services/scan.service.dart';
import '../menu/drawer.widget.dart';
import '../utils/route_observer.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> with RouteAware {
  final ScanService _scanService = ScanService();
  final TextEditingController _rechercheController = TextEditingController();

  List<ScanModel> _tousLesScans = [];
  List<ScanModel> _scansFiltres = [];
  String _filtreActif = 'Tous';
  int _pointsTotal = 0;

  @override
  void initState() {
    super.initState();
    _chargerScans();
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
    _rechercheController.dispose();
    super.dispose();
  }

  // Retour sur la bibliothèque : recharger la liste
  @override
  void didPopNext() => _chargerScans();

  Future<void> _chargerScans() async {
    final List<ScanModel> scans = await _scanService.listeScans();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _tousLesScans = scans;
      _pointsTotal  = prefs.getInt('points') ?? 0;
      // La matière filtrée a pu disparaître (scan supprimé)
      if (!_matieres.contains(_filtreActif)) _filtreActif = 'Tous';
      _appliquerFiltres();
    });
  }

  // Recherche ET filtre par matière sont appliqués ensemble
  void _appliquerFiltres() {
    final String q = _rechercheController.text.trim().toLowerCase();
    _scansFiltres = _tousLesScans.where((s) {
      final bool matiereOk =
          _filtreActif == 'Tous' || s.matiere == _filtreActif;
      final bool rechercheOk = q.isEmpty ||
          s.titre.toLowerCase().contains(q) ||
          s.matiere.toLowerCase().contains(q) ||
          s.motsCles.toLowerCase().contains(q) ||
          s.texteOcr.toLowerCase().contains(q);
      return matiereOk && rechercheOk;
    }).toList();
  }

  void _rechercher(String _) {
    setState(_appliquerFiltres);
  }

  void _filtrerParMatiere(String matiere) {
    setState(() {
      _filtreActif = matiere;
      _appliquerFiltres();
    });
  }

  void _ouvrir(String route, {Object? arguments}) {
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  // ---- Renommer un scan ----
  Future<void> _renommerScan(ScanModel scan) async {
    final ctrl = TextEditingController(text: scan.titre);
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Modifier le nom',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nom du document',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            child: const Text('Sauvegarder',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmer == true && ctrl.text.trim().isNotEmpty) {
      scan.titre = ctrl.text.trim();
      await _scanService.modifierScan(scan);
      await _chargerScans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nom modifié.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _supprimerScan(ScanModel scan) async {
    bool? confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le scan',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Veux-tu vraiment supprimer "${scan.titre}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Oui, supprimer'),
          ),
        ],
      ),
    );

    if (confirmer == true) {
      await _scanService.supprimerScan(scan);
      await _chargerScans();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scan supprimé.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<String> get _matieres {
    List<String> mat = _tousLesScans.map((s) => s.matiere).toSet().toList();
    return ['Tous', ...mat];
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

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text('Bibliothèque',
                style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                )),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _rechercheController,
              onChanged: _rechercher,
              decoration: InputDecoration(
                hintText: 'Rechercher un titre, une matière, un mot...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _matieres.length,
              itemBuilder: (_, i) {
                String m = _matieres[i];
                bool actif = _filtreActif == m;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _filtrerParMatiere(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: actif ? const Color(0xFF1E3A5F) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.center,
                      child: Text(m,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: actif ? Colors.white : const Color(0xFF64748B),
                          )),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _tousLesScans.isEmpty
                ? _buildVide()
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _scansFiltres.length + 2,
              itemBuilder: (_, index) {
                if (index == 0) {
                  return _scansFiltres.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('Aucun scan ne correspond à la recherche.',
                                style: TextStyle(
                                    fontSize: 13, color: Color(0xFF64748B))),
                          ),
                        )
                      : const SizedBox.shrink();
                }
                if (index == _scansFiltres.length + 1) return _buildStats();
                return _buildScanItem(_scansFiltres[index - 1]);
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _ouvrir('/scan'),
        backgroundColor: const Color(0xFFD97706),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildScanItem(ScanModel scan) {
    return InkWell(
      // Un scan enregistré s'ouvre sur ses insights (résumé, mots-clés, quiz)
      onTap: () => _ouvrir('/insights', arguments: scan),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52, height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description_outlined,
                  color: Color(0xFF94A3B8), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(scan.titre,
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            )),
                      ),
                      // Icône modifier le nom
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _renommerScan(scan),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.edit_outlined,
                              size: 15, color: Color(0xFF64748B)),
                        ),
                      ),
                      // Icône supprimer
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _supprimerScan(scan),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(Icons.delete_outline,
                              size: 15, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('Scanné : ${scan.dateCreation}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(scan.matiere,
                        style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700,
                          color: Color(0xFF5B21B6),
                        )),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: scan.scoreOcr / 100,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              scan.scoreOcr >= 80
                                  ? const Color(0xFF1E3A5F)
                                  : const Color(0xFFF59E0B),
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(scan.scoreOcr > 0 ? '${scan.scoreOcr}% OCR' : 'OCR n/d',
                          style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: scan.scoreOcr >= 80
                                ? const Color(0xFF1E3A5F)
                                : const Color(0xFFD97706),
                          )),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final Set<String> matieres = _tousLesScans.map((s) => s.matiere).toSet();
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatBanner('${_tousLesScans.length}', 'Total scans')),
            const SizedBox(width: 10),
            Expanded(child: _buildStatBanner('${matieres.length}', 'Matières')),
          ],
        ),
        const SizedBox(height: 10),
        _buildStatBanner('$_pointsTotal', 'Points gagnés'),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatBanner(String valeur, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A5F),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(valeur,
              style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white,
              )),
          const SizedBox(height: 4),
          Text(label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11, color: Colors.white60,
                fontWeight: FontWeight.w600, letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  Widget _buildVide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          const Text('Bibliothèque vide.',
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              )),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _ouvrir('/scan'),
            icon: const Icon(Icons.document_scanner),
            label: const Text('Premier scan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

}