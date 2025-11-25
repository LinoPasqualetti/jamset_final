// lib/screens/gestione_dati_globali_screen.dart
import 'package:flutter/material.dart';
import 'package:jamset_final/main.dart' as app_main;
import 'varia_catalogo_screen.dart'; // Creeremo questo dopo

class GestioneDatiGlobaliScreen extends StatefulWidget {
  const GestioneDatiGlobaliScreen({super.key});

  @override
  State<GestioneDatiGlobaliScreen> createState() => _GestioneDatiGlobaliScreenState();
}

class _GestioneDatiGlobaliScreenState extends State<GestioneDatiGlobaliScreen> {
  Map<String, dynamic> datiSistema = {};
  List<Map<String, dynamic>> catalogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _caricaDati();
  }

  Future<void> _caricaDati() async {
    setState(() => isLoading = true);

    try {
      await _caricaDatiSistema();
      await _caricaElencoCataloghi();
    } catch (e) {
      print("Errore caricamento dati: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _caricaDatiSistema() async {
    final db = app_main.dbGlobale;
    if (db == null) return;

    final result = await db.query('DatiSistremaApp', limit: 1);
    if (result.isNotEmpty) {
      setState(() {
        datiSistema = result.first;
      });
    }
  }

  Future<void> _caricaElencoCataloghi() async {
    final db = app_main.dbGlobale;
    if (db == null) return;

    final result = await db.rawQuery('SELECT * FROM elenco_cataloghi ORDER BY id');
    setState(() {
      catalogs = result;
    });
  }

  Future<void> _modificaDatiSistema(BuildContext context) async {
    final controllerPercorsoPdf = TextEditingController(
        text: datiSistema['PercorsoPdf']?.toString() ?? ''
    );
    final controllerPercorsoApp = TextEditingController(
        text: datiSistema['PercorsoApp']?.toString() ?? ''
    );
    final controllerPercorsoDb = TextEditingController(
        text: datiSistema['Percorsodatabase']?.toString() ?? ''
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Dati Sistema'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controllerPercorsoPdf,
                decoration: const InputDecoration(
                  labelText: 'Percorso PDF',
                  hintText: 'C:\\JamsetPDF',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllerPercorsoApp,
                decoration: const InputDecoration(
                  labelText: 'Percorso App',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controllerPercorsoDb,
                decoration: const InputDecoration(
                  labelText: 'Percorso Database',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controllerPercorsoPdf.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _salvaDatiSistema(
        controllerPercorsoPdf.text,
        controllerPercorsoApp.text,
        controllerPercorsoDb.text,
      );
    }
  }

  Future<void> _salvaDatiSistema(String percorsoPdf, String percorsoApp, String percorsoDb) async {
    final db = app_main.dbGlobale;
    if (db == null) return;

    try {
      await db.update('DatiSistremaApp', {
        'PercorsoPdf': percorsoPdf,
        'PercorsoApp': percorsoApp.isNotEmpty ? percorsoApp : null,
        'Percorsodatabase': percorsoDb.isNotEmpty ? percorsoDb : null,
      });

      // Aggiorna variabili globali
      app_main.gPercorsoPdf = percorsoPdf;

      await _caricaDati();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dati sistema aggiornati!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore aggiornamento: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _impostaPercorsoPredefinito() async {
    await _salvaDatiSistema(r'C:\JamsetPDF', '', '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Dati Globali'),
        backgroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _caricaDati,
            tooltip: 'Ricarica dati',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContenuto(context),
    );
  }

  Widget _buildContenuto(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SEZIONE DATI SISTEMA
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.settings, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('DATI SISTEMA', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoItem('Percorso PDF', datiSistema['PercorsoPdf']?.toString() ?? 'Non impostato'),
                  _buildInfoItem('Percorso App', datiSistema['PercorsoApp']?.toString() ?? 'Non impostato'),
                  _buildInfoItem('Percorso DB', datiSistema['Percorsodatabase']?.toString() ?? 'Non impostato'),
                  _buildInfoItem('Catalogo Attivo', datiSistema['id_catalogo_attivo']?.toString() ?? '1'),
                  _buildInfoItem('Modo Files', datiSistema['ModoFiles']?.toString() ?? 'dataSQL'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _modificaDatiSistema(context),
                          icon: const Icon(Icons.edit),
                          label: const Text('Modifica Dati Sistema'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _impostaPercorsoPredefinito,
                          icon: const Icon(Icons.folder_special),
                          label: const Text('Percorso PDF Predefinito'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // SEZIONE CATALOGHI
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.storage, color: Colors.green),
                      SizedBox(width: 8),
                      Text('ELENCO CATALOGHI', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...catalogs.map((catalog) => _buildCatalogItem(catalog, context)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _aggiungiCatalogo(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi Nuovo Catalogo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('● $label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontFamily: 'Monospace'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogItem(Map<String, dynamic> catalog, BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.blue),
        title: Text('${catalog['id']} - ${catalog['nome_catalogo']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${catalog['nome_file_db']}'),
            if (catalog['descrizione'] != null && (catalog['descrizione'] as String).isNotEmpty)
              Text(
                catalog['descrizione'] as String,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new, color: Colors.teal),
          onPressed: () => _apriAnaliticoCatalogo(context, catalog),
          tooltip: 'Apri analitico catalogo',
        ),
      ),
    );
  }

  Future<void> _apriAnaliticoCatalogo(BuildContext context, Map<String, dynamic> catalog) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VariaCatalogoScreen(
          catalogoData: catalog,
          totalCataloghi: catalogs.length,
        ),
      ),
    ).then((_) {
      // Ricarica i dati quando si torna indietro
      _caricaDati();
    });
  }

  Future<void> _aggiungiCatalogo(BuildContext context) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VariaCatalogoScreen(
          catalogoData: null,
          totalCataloghi: 0,
        ),
      ),
    ).then((_) {
      // Ricarica i dati quando si torna indietro
      _caricaDati();
    });
  }
}