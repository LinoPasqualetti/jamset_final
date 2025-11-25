// lib/screens/varia_catalogo_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:io'; // AGGIUNGI QUESTA IMPORT

import 'package:jamset_final/main.dart' as app_main;

class VariaCatalogoScreen extends StatefulWidget {
  final Map<String, dynamic>? catalogoData;
  final int totalCataloghi;

  const VariaCatalogoScreen({
    super.key,
    this.catalogoData,
    required this.totalCataloghi,
  });

  @override
  State<VariaCatalogoScreen> createState() => _VariaCatalogoScreenState();
}

class _VariaCatalogoScreenState extends State<VariaCatalogoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  bool _isNewRecord = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _isNewRecord = widget.catalogoData == null;

    _controllers = {
      'id': TextEditingController(),
      'nome_catalogo': TextEditingController(),
      'descrizione': TextEditingController(),
      'nome_file_db': TextEditingController(),
      'FilesPath': TextEditingController(),
      'AppPath': TextEditingController(),
      'data_creazione': TextEditingController(),
      'data_ultimo_aggiornamento': TextEditingController(),
      'conteggio_brani': TextEditingController(),
    };

    if (!_isNewRecord) {
      widget.catalogoData!.forEach((key, value) {
        _controllers[key]?.text = value?.toString() ?? '';
      });
    } else {
      _controllers['data_creazione']?.text = DateTime.now().toIso8601String();
      _controllers['conteggio_brani']?.text = '0';
    }
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate() || app_main.dbGlobale == null) return;

    setState(() => isLoading = true);

    try {
      final db = app_main.dbGlobale!;

      Map<String, dynamic> dataToSave = {};
      _controllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          dataToSave[key] = controller.text;
        }
      });

      dataToSave['data_ultimo_aggiornamento'] = DateTime.now().toIso8601String();

      if (_isNewRecord) {
        dataToSave.remove('id');

        // Assicurati che il nome file abbia estensione .db
        if (!dataToSave['nome_file_db'].endsWith('.db')) {
          dataToSave['nome_file_db'] = '${dataToSave['nome_file_db']}.db';
          _controllers['nome_file_db']?.text = dataToSave['nome_file_db'];
        }

        await db.insert('elenco_cataloghi', dataToSave, conflictAlgorithm: ConflictAlgorithm.replace);

        // Crea il database fisico
        await _creaDatabaseCatalogo(dataToSave['nome_file_db']);
      } else {
        await db.update('elenco_cataloghi', dataToSave, where: 'id = ?', whereArgs: [dataToSave['id']]);
      }

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Dati salvati con successo!'),
                backgroundColor: Colors.green
            )
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _creaDatabaseCatalogo(String nomeFileDb) async {
    try {
      final dbPath = app_main.gDatabasePath;
      final nuovoDb = File(p.join(dbPath, nomeFileDb)); // ORA File È DEFINITO

      if (await nuovoDb.exists()) {
        throw Exception('$nomeFileDb esiste già!');
      }

      final db = await openDatabase(p.join(dbPath, nomeFileDb));

      // Crea struttura complessa (VecchioDb.db)
      await _copiaStrutturaComplessa(db);
      await db.close();

      print("Database $nomeFileDb creato con struttura complessa");

    } catch (e) {
      print("Errore creazione database $nomeFileDb: $e");
      rethrow;
    }
  }

  Future<void> _copiaStrutturaComplessa(Database targetDb) async {
    // Crea tabella spartiti con struttura complessa (VecchioDb.db)
    await targetDb.execute('''
      CREATE TABLE spartiti (
        id_univoco_globale  INTEGER UNIQUE,
        IdBra               TEXT,
        titolo              TEXT,
        autore              TEXT,
        strumento           TEXT,
        volume              TEXT,
        PercRadice          TEXT,
        PercResto           TEXT,
        PrimoLInk           TEXT,
        TipoMulti           TEXT,
        TipoDocu            TEXT,
        ArchivioProvenienza TEXT,
        NumPag              INTEGER,
        NumOrig             INTEGER,
        IdVolume            TEXT,
        IdAutore            TEXT,
        PRIMARY KEY (id_univoco_globale AUTOINCREMENT)
      )
    ''');

    // Crea sistema FTS5 completo
    await targetDb.execute('''
      CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
        titolo,
        autore,
        volume,
        ArchivioProvenienza,
        content = 'spartiti',
        content_rowid = 'IdBra'
      )
    ''');

    // Tabelle di supporto FTS
    await targetDb.execute('''
      CREATE TABLE spartiti_fts_config (k PRIMARY KEY, v) WITHOUT ROWID
    ''');

    await targetDb.execute('''
      CREATE TABLE spartiti_fts_data (id INTEGER PRIMARY KEY, block BLOB)
    ''');

    await targetDb.execute('''
      CREATE TABLE spartiti_fts_docsize (id INTEGER PRIMARY KEY, sz BLOB)
    ''');

    await targetDb.execute('''
      CREATE TABLE spartiti_fts_idx (segid, term, pgno, PRIMARY KEY (segid, term)) WITHOUT ROWID
    ''');

    // Trigger FTS
    await targetDb.execute('''
      CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti BEGIN
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
      END
    ''');

    await targetDb.execute('''
      CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
        VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
      END
    ''');

    await targetDb.execute('''
      CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
        INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza) 
        VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza);
        INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza)
        VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza);
      END
    ''');
  }

  Future<void> _deleteData() async {
    if (_isNewRecord || widget.catalogoData == null || app_main.dbGlobale == null) return;

    final id = widget.catalogoData!['id'];
    if (id == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ERRORE: Il catalogo di default (ID 1) non può essere eliminato.'),
              backgroundColor: Colors.red
          )
      );
      return;
    }
    if (widget.totalCataloghi <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('ERRORE: Non puoi eliminare l\'ultimo catalogo rimasto.'),
              backgroundColor: Colors.red
          )
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma Eliminazione'),
        content: Text('Sei sicuro di voler eliminare il catalogo "${widget.catalogoData!['nome_catalogo']}"? L\'operazione è irreversibile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annulla')
          ),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Elimina', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      setState(() => isLoading = true);

      try {
        final db = app_main.dbGlobale!;
        await db.delete('elenco_cataloghi', where: 'id = ?', whereArgs: [id]);

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Catalogo eliminato.'),
                  backgroundColor: Colors.orange
              )
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Errore: $e'))
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  // --- FUNZIONE PER MOSTRARE INFO DB ---
  void _showDbInfo() {
    final dbName = _isNewRecord ? '(nuovo catalogo)' : _controllers['nome_file_db']?.text ?? 'N/D';
    final fullPath = p.join(app_main.gDatabasePath, dbName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Informazioni Database'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              const Text('Nome file database del catalogo:'),
              SelectableText(dbName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Percorso completo della cartella dei DB:'),
              SelectableText(app_main.gDatabasePath, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Copia Percorso'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: app_main.gDatabasePath));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Percorso cartella copiato!')));
            },
          ),
          TextButton(
            child: const Text('Chiudi'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewRecord ? 'Nuovo Catalogo' : 'Varia Catalogo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showDbInfo,
            tooltip: 'Info Database',
          ),
          if (!_isNewRecord)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: isLoading ? null : _deleteData,
              tooltip: 'Elimina Catalogo',
            )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._controllers.entries.map((entry) {
                final key = entry.key;
                final controller = entry.value;
                bool isReadOnly = ['id', 'data_creazione', 'data_ultimo_aggiornamento', 'conteggio_brani'].contains(key);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: controller,
                    readOnly: isReadOnly,
                    maxLines: key == 'descrizione' ? 3 : 1,
                    decoration: InputDecoration(
                      labelText: key,
                      border: const OutlineInputBorder(),
                      filled: isReadOnly,
                      fillColor: isReadOnly ? Colors.grey[200] : null,
                    ),
                    validator: (value) {
                      if (!isReadOnly && (value == null || value.isEmpty) &&
                          ['nome_catalogo', 'nome_file_db'].contains(key)) {
                        return 'Questo campo non può essere vuoto';
                      }
                      return null;
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isLoading ? null : _saveData,
        label: const Text('SALVA'),
        icon: const Icon(Icons.save),
      ),
    );
  }
}