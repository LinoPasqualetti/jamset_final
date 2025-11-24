// lib/screens/system_config_screen.dart - VERSIONE CON AGGIORNAMENTO VISIBILE
import 'package:flutter/material.dart';
import 'dart:io' show File, Platform;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:jamset_final/main.dart' as app_main;

class SystemConfigScreen extends StatefulWidget {
  const SystemConfigScreen({super.key});

  @override
  State<SystemConfigScreen> createState() => _SystemConfigScreenState();
}

class _SystemConfigScreenState extends State<SystemConfigScreen> {
  Map<String, dynamic> currentConfig = {};
  Map<int, CatalogInfo> catalogs = {};
  bool isLoading = true;
  String databasePath = '';
  final TextEditingController _pdfPathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => isLoading = true);

    try {
      await _loadSystemConfig();
      await _checkCatalogsStatus();
    } catch (e) {
      print("Errore caricamento configurazione: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSystemConfig() async {
    final db = app_main.dbGlobale;
    if (db == null) throw Exception("Database globale non disponibile");

    databasePath = app_main.gDatabasePath;

    // LEGGI SEMPRE I DATI AGGIORNATI DAL DATABASE
    final configData = await db.query('DatiSistremaApp', limit: 1);
    if (configData.isNotEmpty) {
      setState(() {
        currentConfig = {
          'sistemaOperativo': Platform.operatingSystem,
          'tipoInterfaccia': _getInterfaceType(),
          'percorsoPdf': configData.first['PercorsoPdf'] ?? 'Non impostato',
          'idCatalogoAttivo': configData.first['id_catalogo_attivo'] ?? 1,
        };
        _pdfPathController.text = currentConfig['percorsoPdf']?.toString() ?? '';
      });
    }

    final catalogData = await db.rawQuery('SELECT * FROM elenco_cataloghi');
    catalogs.clear();
    for (var catalog in catalogData) {
      catalogs[catalog['id'] as int] = CatalogInfo(
        name: catalog['nome_file_db'] as String,
        id: catalog['id'] as int,
      );
    }
  }

  Future<void> _checkCatalogsStatus() async {
    final dbPath = app_main.gDatabasePath;

    for (var catalog in catalogs.values) {
      final dbFile = File(join(dbPath, catalog.name));
      final exists = await dbFile.exists();

      if (exists) {
        try {
          final db = await openDatabase(join(dbPath, catalog.name));
          final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM spartiti');
          catalog.recordCount = countResult.first['count'] as int;
          catalog.exists = true;
          await db.close();
        } catch (e) {
          catalog.exists = true;
          catalog.recordCount = -1;
        }
      } else {
        catalog.exists = false;
        catalog.recordCount = 0;
      }
    }
  }

  String _getInterfaceType() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'Desktop';
    } else if (Platform.isAndroid || Platform.isIOS) {
      return 'Mobile';
    }
    return 'Web';
  }

  Future<void> _createNuovoDb(BuildContext context, String nomeFileDb) async {
    try {
      setState(() => isLoading = true);

      final dbPath = app_main.gDatabasePath;
      final nuovoDb = File(join(dbPath, nomeFileDb));

      if (await nuovoDb.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$nomeFileDb esiste già!')),
        );
        return;
      }

      final db = await openDatabase(join(dbPath, nomeFileDb));
      await _copyDatabaseStructure(db, nomeFileDb);
      await db.close();

      // RICARICA LA CONFIGURAZIONE DOPO LA CREAZIONE
      await _loadCurrentConfig();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$nomeFileDb creato con successo!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore creazione database $nomeFileDb: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _copyDatabaseStructure(Database targetDb, String dbName) async {
    await targetDb.execute('''
      CREATE TABLE spartiti (
        IdBra INTEGER PRIMARY KEY AUTOINCREMENT,
        titolo TEXT,
        autore TEXT,
        volume TEXT,
        ArchivioProvenienza TEXT,
        strumento TEXT,
        percResto TEXT,
        created_at INTEGER DEFAULT (strftime('%s', 'now')),
        updated_at INTEGER DEFAULT (strftime('%s', 'now'))
      )
    ''');

    if (Platform.isWindows) {
      await targetDb.execute('''
        CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
          titolo, autore, volume, ArchivioProvenienza, strumento,
          content = 'spartiti', content_rowid = 'IdBra'
        )
      ''');

      await targetDb.execute('''
        CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti BEGIN
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza, strumento)
          VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza, new.strumento);
        END;
      ''');

      await targetDb.execute('''
        CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
          INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza, strumento) 
          VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza, old.strumento);
        END;
      ''');

      await targetDb.execute('''
        CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
          INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza, strumento) 
          VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza, old.strumento);
          INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza, strumento)
          VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza, new.strumento);
        END;
      ''');
    }

    print("Struttura database $dbName creata con successo!");
  }

  Future<void> _aggiungiCatalogo(BuildContext context) async {
    final nomeController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi Nuovo Catalogo'),
        content: TextField(
          controller: nomeController,
          decoration: const InputDecoration(
            labelText: 'Nome catalogo',
            hintText: 'es. ClassicalMusic.db',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nomeController.text.isNotEmpty) {
                Navigator.pop(context, nomeController.text);
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _creaENuovoCatalogo(context, result);
    }
  }

  Future<void> _creaENuovoCatalogo(BuildContext context, String nomeCatalogo) async {
    try {
      setState(() => isLoading = true);

      String nomeFile = nomeCatalogo.endsWith('.db') ? nomeCatalogo : '$nomeCatalogo.db';

      await _createNuovoDb(context, nomeFile);

      final dbGlobale = app_main.dbGlobale;
      if (dbGlobale != null) {
        final maxIdResult = await dbGlobale.rawQuery(
            'SELECT MAX(id) as max_id FROM elenco_cataloghi'
        );
        final nextId = (maxIdResult.first['max_id'] as int? ?? 0) + 1;

        await dbGlobale.insert('elenco_cataloghi', {
          'id': nextId,
          'nome_file_db': nomeFile,
        });

        // RICARICA LA CONFIGURAZIONE DOPO L'AGGIUNTA
        await _loadCurrentConfig();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catalogo $nomeFile aggiunto con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore aggiunta catalogo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _cambiaCatalogoAttivo(BuildContext context, int nuovoIdCatalogo) async {
    try {
      setState(() => isLoading = true);

      final dbGlobale = app_main.dbGlobale;
      if (dbGlobale != null) {
        // AGGIORNA NEL DATABASE
        await dbGlobale.update(
          'DatiSistremaApp',
          {'id_catalogo_attivo': nuovoIdCatalogo},
        );

        // AGGIORNA VARIABILI GLOBALI
        final catalogoAttivo = catalogs[nuovoIdCatalogo];
        if (catalogoAttivo != null) {
          app_main.gActiveCatalogDbName = catalogoAttivo.name;
        }

        // RIAPRI IL DATABASE
        await _apriDatabaseCatalogoAttivo();

        // RICARICA LA CONFIGURAZIONE PER VEDERE LE MODIFICHE
        await _loadCurrentConfig();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catalogo attivo cambiato a: ${catalogoAttivo?.name ?? "N/D"}'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore cambio catalogo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _apriDatabaseCatalogoAttivo() async {
    try {
      // CHIUDI IL DATABASE PRECEDENTE
      if (app_main.dbCatalogoAttivo != null) {
        await app_main.dbCatalogoAttivo!.close();
        app_main.dbCatalogoAttivo = null;
      }

      // APRI IL NUOVO DATABASE
      if (app_main.gActiveCatalogDbName.isNotEmpty) {
        final dbPath = app_main.gDatabasePath;
        final dbFile = File(join(dbPath, app_main.gActiveCatalogDbName));

        if (await dbFile.exists()) {
          app_main.dbCatalogoAttivo = await openDatabase(
            join(dbPath, app_main.gActiveCatalogDbName),
          );
          print("Database catalogo attivo riaperto: ${app_main.gActiveCatalogDbName}");
        } else {
          print("File database non trovato: ${app_main.gActiveCatalogDbName}");
        }
      }
    } catch (e) {
      print("Errore apertura database catalogo attivo: $e");
    }
  }

  Future<void> _rimuoviCatalogo(BuildContext context, CatalogInfo catalogo) async {
    final catalogoAttivo = currentConfig['idCatalogoAttivo'] as int? ?? 1;
    if (catalogo.id == catalogoAttivo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Non puoi rimuovere il catalogo attivo!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Rimozione'),
        content: Text('Vuoi rimuovere il catalogo "${catalogo.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (conferma == true) {
      try {
        setState(() => isLoading = true);

        final dbGlobale = app_main.dbGlobale;
        if (dbGlobale != null) {
          await dbGlobale.delete(
            'elenco_cataloghi',
            where: 'id = ?',
            whereArgs: [catalogo.id],
          );

          // RICARICA LA CONFIGURAZIONE DOPO LA RIMOZIONE
          await _loadCurrentConfig();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Catalogo ${catalogo.name} rimosso!'),
              backgroundColor: Colors.green,
            ),
          );
        }

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore rimozione catalogo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _modificaPercorsoPdf(BuildContext context) async {
    final nuovoPercorsoController = TextEditingController(
        text: currentConfig['percorsoPdf']?.toString() ?? ''
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Percorso PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inserisci il percorso della cartella PDF:'),
            const SizedBox(height: 10),
            TextField(
              controller: nuovoPercorsoController,
              decoration: const InputDecoration(
                labelText: 'Percorso cartella PDF',
                hintText: 'es. C:\\Spartiti o /storage/emulated/0/Spartiti',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nuovoPercorsoController.text.isNotEmpty) {
                Navigator.pop(context, nuovoPercorsoController.text);
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _salvaPercorsoPdf(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Percorso PDF salvato: $result'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _salvaPercorsoPdf(String percorso) async {
    final dbGlobale = app_main.dbGlobale;
    if (dbGlobale != null) {
      // AGGIORNA NEL DATABASE
      await dbGlobale.update(
        'DatiSistremaApp',
        {'PercorsoPdf': percorso},
      );

      // AGGIORNA VARIABILI GLOBALI
      app_main.gPercorsoPdf = percorso;

      // RICARICA LA CONFIGURAZIONE PER VEDERE LE MODIFICHE
      await _loadCurrentConfig();
    }
  }

  Future<void> _usaPercorsoPredefinito(BuildContext context) async {
    try {
      String defaultPath;

      if (Platform.isWindows) {
        defaultPath = r'C:\Spartiti';
      } else if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        defaultPath = '${directory?.path}/Spartiti';
      } else {
        final directory = await getApplicationDocumentsDirectory();
        defaultPath = '${directory.path}/Spartiti';
      }

      await _salvaPercorsoPdf(defaultPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Percorso predefinito impostato: $defaultPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore percorso predefinito: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Configurazione Sistema'),
            if (databasePath.isNotEmpty)
              Text(
                'Percorso DB: ${_shortenPath(databasePath)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.yellow,
                ),
              ),
          ],
        ),
        backgroundColor: Colors.blueGrey[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : _loadCurrentConfig,
            tooltip: 'Ricarica configurazione',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: isLoading ? null : _apriDatabaseCatalogoAttivo,
            tooltip: 'Riapri database per ricerca',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildConfigView(context),
    );
  }

  String _shortenPath(String path) {
    if (path.length > 50) {
      final segments = path.split(Platform.pathSeparator);
      if (segments.length > 3) {
        return '...${Platform.pathSeparator}${segments.sublist(segments.length - 3).join(Platform.pathSeparator)}';
      }
    }
    return path;
  }

  Widget _buildConfigView(BuildContext context) {
    final activeCatalogId = currentConfig['idCatalogoAttivo'] as int? ?? 1;
    final activeCatalog = catalogs[activeCatalogId];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      Text('CONFIGURAZIONE ATTUALE',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildConfigItem('Sistema Operativo',
                      currentConfig['sistemaOperativo']?.toString() ?? 'N/D'),
                  _buildConfigItem('Tipo Interfaccia',
                      currentConfig['tipoInterfaccia']?.toString() ?? 'N/D'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildConfigItem('Percorso PDF',
                            currentConfig['percorsoPdf']?.toString() ?? 'Non impostato'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _modificaPercorsoPdf(context),
                        tooltip: 'Modifica percorso PDF',
                      ),
                    ],
                  ),
                  _buildConfigItem('Catalogo Attivo',
                      'ID ${currentConfig['idCatalogoAttivo']} - ${activeCatalog?.name ?? "N/D"} ${activeCatalog?.exists == true ? "✅" : "❌"}'),
                  _buildConfigItem('Percorso Database', databasePath),
                  _buildConfigItem('Stato Database Ricerca',
                      app_main.dbCatalogoAttivo != null ? 'APERTO ✅' : 'CHIUSO ❌'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

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
                      Text('CATALOGHI DATABASE',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...catalogs.values.map((catalog) => _buildCatalogItem(catalog, context)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : () => _aggiungiCatalogo(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuovo Catalogo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isLoading ? null : _loadCurrentConfig,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Aggiorna'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => _createNuovoDb(context, 'JazzStandards.db'),
                icon: const Icon(Icons.library_music),
                label: const Text('Crea JazzStandards.db'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: isLoading ? null : () => _usaPercorsoPredefinito(context),
                icon: const Icon(Icons.folder_special),
                label: const Text('Percorso PDF Predefinito'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: isLoading ? null : _apriDatabaseCatalogoAttivo,
                icon: const Icon(Icons.search),
                label: const Text('Riapri Database Ricerca'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfigItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text('● $label: ',
              style: const TextStyle(fontWeight: FontWeight.w500)),
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

  Widget _buildCatalogItem(CatalogInfo catalog, BuildContext context) {
    final isAttivo = catalog.id == (currentConfig['idCatalogoAttivo'] as int? ?? 1);
    String recordText;
    Color statusColor = Colors.grey;

    if (!catalog.exists) {
      recordText = '(DA CREARE)';
      statusColor = Colors.orange;
    } else if (catalog.recordCount == -1) {
      recordText = '(ERRORE CONTEggio)';
      statusColor = Colors.red;
    } else {
      recordText = '(${catalog.recordCount} record)';
      statusColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      color: isAttivo ? Colors.blue[50] : null,
      child: ListTile(
        leading: Icon(
          isAttivo ? Icons.star : Icons.folder,
          color: isAttivo ? Colors.amber : statusColor,
        ),
        title: Text(
          '${catalog.id} - ${catalog.name}',
          style: TextStyle(
            fontWeight: isAttivo ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          recordText,
          style: TextStyle(color: statusColor),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isAttivo) ...[
              IconButton(
                icon: const Icon(Icons.star_border, size: 20),
                onPressed: () => _cambiaCatalogoAttivo(context, catalog.id),
                tooltip: 'Imposta come attivo',
              ),
              IconButton(
                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                onPressed: () => _rimuoviCatalogo(context, catalog),
                tooltip: 'Rimuovi catalogo',
              ),
            ],
            if (isAttivo)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }
}

class CatalogInfo {
  final String name;
  final int id;
  bool exists;
  int recordCount;

  CatalogInfo({
    required this.name,
    required this.id,
    this.exists = false,
    this.recordCount = 0,
  });
}