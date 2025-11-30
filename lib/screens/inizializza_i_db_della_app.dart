// lib/screens/inizializza_i_db_della_app.dart - THE GUARDIAN, ADAPTED & FIXED

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Import main.dart from the parent 'lib' directory
import '../main.dart';

// --- DATABASE FILENAMES ---
const String _dbGlobaleName = 'DBGlobale_seed.db';
const String _vecchioDbName = 'VecchioDb.db';
const String _primoVuotoName = 'PrimoVuoto.db';


/// ===================================================================
/// MAIN GUARDIAN FUNCTION
/// Orchestrates the platform-aware creation, sanitization, and opening
/// of all application databases. Called by the FutureBuilder in MainScreen.
/// ===================================================================
Future<void> inizializzaIDbDellaApp() async {
  try {
    // --- STEP 1: PREPARE DB ENGINES ---
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    
    final supportDir = await getApplicationSupportDirectory();
    gDatabasePath = supportDir.path;
    final sep = Platform.pathSeparator;
    debugPrint("--- GUARDIAN: Initializing in: ${gDatabasePath} ---");

    // --- STEP 2: "SMART" HANDLING OF VECCHIODB.DB ---
    final vecchioDbPath = '$gDatabasePath$sep$_vecchioDbName';
    if (!await databaseExists(vecchioDbPath)) {
      await _creaVecchioDbConPopolamentoMirato(vecchioDbPath);
    }
    
    // --- STEP 3: FTS TABLE VERIFICATION & CREATION ---
    dbVecchio = await openDatabase(vecchioDbPath);
    await _setupDatabaseFTS(dbVecchio!, "VecchioDb");

    // --- STEP 4: HANDLE OTHER DATABASES ---
    await _creaPrimoVuotoSeNonEsiste(supportDir.path, sep);
    
    // --- STEP 5: SANITIZE DBGLOBALE_SEED.DB ---
    final dbGlobalePath = '$gDatabasePath$sep$_dbGlobaleName';
    await _copiaSeNonEsiste(dbGlobalePath, _dbGlobaleName);
    dbGlobale = await openDatabase(dbGlobalePath);
    await _sanificaDatiSistema(dbGlobale!, gDatabasePath);
    
    // --- STEP 6: OPEN ACTIVE CATALOG ---
    final datiSistema = (await dbGlobale!.query('DatiSistremaApp', limit: 1)).first;
    gPercorsoPdf = datiSistema['PercorsoPdf'] as String? ?? '';
    int idCatalogoAttivo = datiSistema['id_catalogo_attivo'] as int? ?? 1;

    var catalogoInfoResult = await dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [idCatalogoAttivo], limit: 1);
    if (catalogoInfoResult.isEmpty) {
        idCatalogoAttivo = 1;
        final fallbackResult = await dbGlobale!.query('elenco_cataloghi', where: 'id = ?', whereArgs: [1], limit: 1);
        if (fallbackResult.isEmpty) throw Exception('FATAL ERROR: Default catalog with ID 1 not found.');
        catalogoInfoResult = fallbackResult;
    }
    
    gActiveCatalogDbName = catalogoInfoResult.first['nome_file_db'] as String;
    final catalogoPath = '$gDatabasePath$sep$gActiveCatalogDbName';
    await _copiaSeNonEsiste(catalogoPath, gActiveCatalogDbName);

    // --- STEP 7: FINAL OPEN AND GLOBAL ASSIGNMENT ---
    dbCatalogoAttivo = await openDatabase(catalogoPath);
    await _setupDatabaseFTS(dbCatalogoAttivo!, gActiveCatalogDbName);
    
    debugPrint("***** GLOBAL INITIALIZATION COMPLETE *****");

  } catch (e, s) {
    debugPrint("### GUARDIAN INITIALIZATION ERROR: $e ###");
    debugPrint("### STACK TRACE: $s ###");
    rethrow;
  }
}

/// **STEP 2.1: CREATE & POPULATE VECCHIODB**
Future<void> _creaVecchioDbConPopolamentoMirato(String destDbPath) async {
  debugPrint("INFO: VecchioDb.db not found. Creating from master...");
  
  final tempDir = await getTemporaryDirectory();
  final sep = Platform.pathSeparator;
  final tempAssetDbPath = '${tempDir.path}${sep}asset_seed.db';

  final ByteData data = await rootBundle.load('assets/databases/$_vecchioDbName');
  await File(tempAssetDbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  
  Database? seedDb;
  Database? newDb;
  try {
    seedDb = await openReadOnlyDatabase(tempAssetDbPath);
    newDb = await openDatabase(destDbPath);

    final sourceTableName = Platform.isAndroid ? 'spartiti_andr' : 'spartiti';
    final dataToInsert = await seedDb.query(sourceTableName);

    await newDb.transaction((txn) async {
      await txn.execute('CREATE TABLE $gSpartitiTableName (id_univoco_globale INTEGER PRIMARY KEY AUTOINCREMENT, IdBra INTEGER UNIQUE, titolo TEXT, autore TEXT, strumento TEXT, volume TEXT, PercRadice TEXT, PercResto TEXT, PrimoLInk TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT, IdAutore TEXT)');
      final batch = txn.batch();
      for (final row in dataToInsert) {
        batch.insert(gSpartitiTableName, row, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });

  } finally {
    await seedDb?.close();
    await newDb?.close();
    await deleteDatabase(tempAssetDbPath);
  }
}

/// **STEP 3.1: SETUP FTS TABLES**
Future<void> _setupDatabaseFTS(Database db, String dbName) async {
  try {
    if (!Platform.isWindows) {
      await db.rawUpdate("UPDATE $gSpartitiTableName SET percResto = REPLACE(percResto, '\\', '/')");
    }
    final ftsTableExists = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti_fts'");
    if (ftsTableExists.isEmpty) {
      debugPrint("[$dbName] WARN: FTS table not found! Creating and populating.");
      await db.execute('CREATE VIRTUAL TABLE spartiti_fts USING fts5(titolo, autore, strumento, content="$gSpartitiTableName", content_rowid="IdBra")');
      await db.execute('INSERT INTO spartiti_fts(spartiti_fts) VALUES(\'rebuild\')');
    }
  } catch (e) {
     debugPrint("[$dbName] ERROR during FTS setup: $e");
  }
}

/// **STEP 4.1: CREATE EMPTY DB**
Future<void> _creaPrimoVuotoSeNonEsiste(String supportDirPath, String sep) async {
  final primoVuotoPath = '$supportDirPath$sep$_primoVuotoName';
  if (!await databaseExists(primoVuotoPath)) {
    const createStatement = 'CREATE TABLE $gSpartitiTableName ( id_univoco_globale INTEGER UNIQUE, IdBra TEXT,titolo TEXT, autore TEXT,strumento TEXT, volume TEXT,PercRadice TEXT, PercResto TEXT, PrimoLInk  TEXT, TipoMulti TEXT, TipoDocu TEXT, ArchivioProvenienza TEXT, NumPag INTEGER, NumOrig INTEGER, IdVolume TEXT,IdAutore TEXT, PRIMARY KEY (id_univoco_globale AUTOINCREMENT))';
    Database dbVuoto = await openDatabase(primoVuotoPath, version: 1, onCreate: (db, version) => db.execute(createStatement));
    await dbVuoto.close();
  }
}

/// **STEP 5.1: SANITIZE SYSTEM DATA**
Future<void> _sanificaDatiSistema(Database globalDb, String supportDirPath) async {
    String os = Platform.operatingSystem;
    String percorsoPdfDefault = Platform.isAndroid ? "/storage/emulated/0/JamsetPDF/" : "C:\\JamsetPDF\\";
    
    var datiSistema = await globalDb.query('DatiSistremaApp', limit: 1);
    if (datiSistema.isEmpty) {
      await globalDb.insert('DatiSistremaApp', {
        'SistemaOperativo': os, 'TipoInterfaccia': kIsWeb ? 'Web' : 'Nativa',
        'PercorsoPdf': percorsoPdfDefault, 'Percorsodatabase': supportDirPath,
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

/// **HELPER FUNCTION**
Future<void> _copiaSeNonEsiste(String dbPath, String assetName) async {
  if (!await databaseExists(dbPath)) {
    debugPrint("INFO: $assetName not found. Copying from assets...");
    // FIX: rootBundle paths always use '/'
    final ByteData data = await rootBundle.load('assets/databases/$assetName');
    await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
  }
}
