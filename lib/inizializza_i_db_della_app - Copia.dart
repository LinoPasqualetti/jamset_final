import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'main.dart'; // Per le variabili globali

const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';

/// ===================================================================
/// FUNZIONE "GUARDIANO" PRINCIPALE
/// Orchesta tutta la logica di creazione, sanificazione e apertura
/// dei database dell'applicazione usando la callback onCreate per robustezza.
/// ===================================================================
Future<void> inizializzaIDbDellaApp() async {
  try {
    // --- FASE 1: PREPARAZIONE DEI "MOTORI" ---
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final supportDir = await getApplicationSupportDirectory();
    gDatabasePath = supportDir.path;
    debugPrint("--- GUARDIANO: Inizio inizializzazione in: \${gDatabasePath} ---");

    // --- FASE 2: GESTIONE VECCHIO DB CON ONCREATE (FIX ASINCRONO) ---
    final vecchioDbPath = p.join(gDatabasePath, _vecchioDbName);
    
    dbVecchio = await openDatabase(
      vecchioDbPath,
      version: 1,
      onCreate: (db, version) async {
        debugPrint("INFO: VecchioDb.db non trovato. Avvio procedura onCreate...");
        await _creaDbDaMaster(db, _vecchioDbName);
      },
    );

    // Ora che il DB è aperto (e creato se necessario), eseguiamo il setup
    await _setupDatabase(dbVecchio!, "VecchioDb");
    debugPrint("Database VecchioDb.db aperto e configurato.");

    // --- FASE 3: GESTIONE E SANIFICAZIONE DI DBGLOBALE_SEED.DB ---
    final dbGlobalePath = p.join(gDatabasePath, _dbGlobaleName);
    await _copiaSeNonEsiste(dbGlobalePath, _dbGlobaleName);
    dbGlobale = await openDatabase(dbGlobalePath);
    await _sanificaDatiSistema(dbGlobale!, gDatabasePath);
    
    // --- FASE 4: APERTURA DEL CATALOGO ATTIVO ---
    final datiSistema = (await dbGlobale!.query('DatiSistremaApp', limit: 1)).first;
    gPercorsoPdf = datiSistema['PercorsoPdf'] as String? ?? '';
    int idCatalogoAttivo = datiSistema['id_catalogo_attivo'] as int? ?? 1;

    var catalogoInfoResult = await dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo], limit: 1);
    if (catalogoInfoResult.isEmpty) {
      idCatalogoAttivo = 1;
      final fallbackResult = await dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [1], limit: 1);
      if (fallbackResult.isEmpty) throw Exception('ERRORE FATALE: Catalogo default con ID 1 non trovato.');
      catalogoInfoResult = fallbackResult;
    }
    
    gActiveCatalogDbName = catalogoInfoResult.first['nome_file_db'] as String;
    final catalogoPath = p.join(gDatabasePath, gActiveCatalogDbName);
    await _copiaSeNonEsiste(catalogoPath, gActiveCatalogDbName);

    dbCatalogoAttivo = await openDatabase(catalogoPath);
    await _setupDatabase(dbCatalogoAttivo!, gActiveCatalogDbName);

    debugPrint("***** INIZIALIZZAZIONE GLOBALE COMPLETATA *****");

  } catch (e, s) {
    debugPrint("### ERRORE INIZIALIZZAZIONE (Guardiano): \$e ###");
    debugPrint("### STACK TRACE: \$s ###");
    rethrow;
  }
}

/// **FASE 2.1: LOGICA ONCREATE PER VECCHIODB**
Future<void> _creaDbDaMaster(Database newDb, String masterDbName) async {
  final ByteData data = await rootBundle.load('assets/databases/\$masterDbName');
  final tempAssetDbPath = p.join((await getTemporaryDirectory()).path, "asset_seed_temp.db");
  await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  
  Database? seedDb;
  try {
    seedDb = await openReadOnlyDatabase(tempAssetDbPath);
    const sourceTableName = 'spartiti';
    final dataToInsert = await seedDb.query(sourceTableName);
    debugPrint("INFO: Letti \${dataToInsert.length} record da '\$sourceTableName' nel DB master.");

    await newDb.transaction((txn) async {
      final batch = txn.batch();
      batch.execute('CREATE TABLE \$gSpartitiTableName (id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT, IdBra INTEGER UNIQUE, titolo TEXT, autore TEXT, strumento TEXT, volume TEXT, PercRadice TEXT, PercResto TEXT, PrimoLInk TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT, IdAutore TEXT)');
      for (final row in dataToInsert) {
        batch.insert(gSpartitiTableName, row, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
      debugPrint("INFO: Inserimento in blocco completato per VecchioDb.");
    });
  } finally {
    await seedDb?.close();
    await deleteDatabase(tempAssetDbPath);
  }
}

/// Helper per la normalizzazione dei percorsi e il setup delle tabelle FTS
Future<void> _setupDatabase(Database db, String dbName) async {
  try {
    if (!Platform.isWindows) {
      debugPrint("[\$dbName] Normalizzazione percorsi...");
      await db.rawUpdate("UPDATE \$gSpartitiTableName SET percResto = REPLACE(percResto, '\\\\', '/')");
    }

    final ftsTableExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'");
    if (ftsTableExists.isEmpty) {
      debugPrint("[\$dbName] WARN: Tabella FTS non trovata! La creo e la popolo ora.");
      await db.execute('CREATE VIRTUAL TABLE spartiti_fts USING fts5(titolo, autore, strumento, content="\$gSpartitiTableName", content_rowid="IdBra")');
      await db.execute('INSERT INTO spartiti_fts(spartiti_fts) VALUES(\'rebuild\')');
    }
  } catch (e) {
     debugPrint("[\$dbName] ERRORE durante setup FTS: \$e");
  }
}

/// Helper per la sanificazione dei dati di sistema in DBGlobale
Future<void> _sanificaDatiSistema(Database globalDb, String supportDirPath) async {
  String os = Platform.operatingSystem;
  String percorsoPdfDefault = Platform.isAndroid ? "/storage/emulated/0/JamsetPDF/" : "C:\\\\JamsetPDF\\\\";
  
  var datiSistema = await globalDb.query('DatiSistremaApp', limit: 1);
  if (datiSistema.isEmpty) {
    await globalDb.insert('DatiSistremaApp', {
      'SistemaOperativo': os,
      'TipoInterfaccia': kIsWeb ? 'Web' : 'Nativa',
      'PercorsoPdf': percorsoPdfDefault,
      'Percorsodatabase': supportDirPath,
      'id_catalogo_attivo': 1,
    });
  } else {
    final current = datiSistema.first;
    Map<String, Object?> updates = {};
    if (current['PercorsoPdf'] != percorsoPdfDefault) updates['PercorsoPdf'] = percorsoPdfDefault;
    if (current['SistemaOperativo'] != os) updates['SistemaOperativo'] = os;
    if (current['Percorsodatabase'] != supportDirPath) updates['Percorsodatabase'] = supportDirPath;
    if (updates.isNotEmpty) await globalDb.update('DatiSistremaApp', updates);
  }
}

/// Helper per copiare un DB dagli assets se non esiste
Future<void> _copiaSeNonEsiste(String dbPath, String assetName) async {
  if (!await databaseExists(dbPath)) {
    debugPrint("INFO: \$assetName non trovato. Copio dagli assets...");
    final ByteData data = await rootBundle.load('assets/databases/\$assetName');
    await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  }
}
