// lib/main.dart - VERSIONE AVANZATA COMPLETA (da jamset_new)
import 'package:flutter/material.dart';
import 'package:jamset_final/screens/main_screen.dart'; // MODIFICATO: jamset_final
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

// --- IMPORT PER DATABASE ---
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

// RIMOSSI IMPORT PROBLEMATICI:
// import 'package:file_picker/file_picker.dart'; // MANTENIAMO INIBITO
// import 'package:jamset_new/platform/opener_platform_interface.dart';
// import 'package:jamset_new/platform/android_opener.dart';
// import 'package:jamset_new/platform/windows_opener.dart';

// Chiave globale per accedere al Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, String> appSystemConfig = {};

// === VARIABILI GLOBALI ===
Database? dbVecchio;
Database? dbGlobale;
Database? dbCatalogoAttivo;
String gActiveCatalogDbName = '';
String gPercorsoPdf = '';
String gDatabasePath = '';
// =======================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Inizializzazione Piattaforma-Specifica di SQLite ---
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    if (Platform.isWindows) {
      const userSpecificViewerPath = r"C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe";
      const defaultViewerPath = r"C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe";
      if (File(userSpecificViewerPath).existsSync()) {
        appSystemConfig['pdfViewerPath'] = userSpecificViewerPath;
      } else {
        appSystemConfig['pdfViewerPath'] = defaultViewerPath;
      }
    }

    // RIMOSSO BLOCCO OPENER PLATFORM CHE CAUSAVA ERRORI

    gDatabasePath = await getDatabasesPath();
    final dbDir = gDatabasePath;
    if (kDebugMode) print("--- PERCORSO DATABASE: $dbDir ---");

    // 1. Apertura VecchioDb.db
    final dbPathVecchio = join(dbDir, "VecchioDb.db");
    if (!await File(dbPathVecchio).exists()) {
      await Directory(dirname(dbPathVecchio)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/VecchioDb.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathVecchio).writeAsBytes(bytes, flush: true);
    }
    dbVecchio = await openDatabase(dbPathVecchio);
    await _setupDatabase(dbVecchio!, "VecchioDb");
    if (kDebugMode) print("Database VecchioDb.db aperto e configurato.");

    // 2. Apertura DBGlobale_seed.db
    final dbPathGlobale = join(dbDir, "DBGlobale_seed.db");
    if (!await File(dbPathGlobale).exists()) {
      await Directory(dirname(dbPathGlobale)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/DBGlobale_seed.db");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathGlobale).writeAsBytes(bytes, flush: true);
    }
    dbGlobale = await openDatabase(dbPathGlobale);
    if (kDebugMode) print("Database DBGlobale_seed.db aperto.");

    // --- LETTURA CONFIGURAZIONI GLOBALI ---
    if (dbGlobale == null) throw Exception("DB Globale non aperto.");

    final configData = await dbGlobale!.query('DatiSistremaApp', columns: ['PercorsoPdf'], limit: 1);
    if (configData.isNotEmpty) {
      gPercorsoPdf = configData.first['PercorsoPdf'] as String;
      if (kDebugMode) print("Percorso PDF globale: $gPercorsoPdf");
    }

    final catalogResults = await dbGlobale!.rawQuery("select nome_file_db from elenco_cataloghi, datiSistremaApp where id=id_catalogo_attivo");
    if (catalogResults.isEmpty || catalogResults.first['nome_file_db'] == null) {
      throw Exception("Nessun catalogo attivo trovato.");
    }
    gActiveCatalogDbName = catalogResults.first['nome_file_db'] as String;
    if (kDebugMode) print("Catalogo attivo: $gActiveCatalogDbName");

    // 3. APERTURA DINAMICA DEL CATALOGO ATTIVO
    final dbPathCatalogo = join(dbDir, gActiveCatalogDbName);
    if (!await File(dbPathCatalogo).exists()) {
      await Directory(dirname(dbPathCatalogo)).create(recursive: true);
      ByteData data = await rootBundle.load("assets/databases/$gActiveCatalogDbName");
      List<int> bytes = data.buffer.asUint8List();
      await File(dbPathCatalogo).writeAsBytes(bytes, flush: true);
    }
    dbCatalogoAttivo = await openDatabase(dbPathCatalogo);
    await _setupDatabase(dbCatalogoAttivo!, gActiveCatalogDbName);
    if (kDebugMode) print("Database catalogo '$gActiveCatalogDbName' aperto e configurato.");

    // --- DEBUG DATABASE ---
    print("=== DEBUG DATABASE ===");
    print("1. STATO DATABASE:");
    print("   - dbVecchio: ${dbVecchio != null ? 'OK' : 'NULL'}");
    print("   - dbGlobale: ${dbGlobale != null ? 'OK' : 'NULL'}");
    print("   - dbCatalogoAttivo: ${dbCatalogoAttivo != null ? 'OK' : 'NULL'}");

    if (dbCatalogoAttivo != null) {
      try {
        final tables = await dbCatalogoAttivo!.rawQuery("SELECT name FROM sqlite_master WHERE type='table'");
        print("2. TABELLE NEL CATALOGO '$gActiveCatalogDbName':");
        for (var table in tables) {
          print("   - ${table['name']}");
        }

        final spartitiTable = await dbCatalogoAttivo!.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='spartiti'");
        print("3. TABELLA 'spartiti': ${spartitiTable.isNotEmpty ? 'ESISTE' : 'NON ESISTE'}");

        if (spartitiTable.isNotEmpty) {
          final countResult = await dbCatalogoAttivo!.rawQuery("SELECT COUNT(*) as count FROM spartiti");
          final recordCount = countResult.first['count'] as int;
          print("4. RECORD IN 'spartiti': $recordCount");

          if (recordCount > 0) {
            final sampleRecords = await dbCatalogoAttivo!.rawQuery("SELECT * FROM spartiti LIMIT 3");
            print("5. RECORD DI ESEMPIO:");
            for (int i = 0; i < sampleRecords.length; i++) {
              print("   [${i + 1}] Titolo: '${sampleRecords[i]['titolo']}', Autore: '${sampleRecords[i]['autore']}'");
            }
          }
        }
      } catch (e) {
        print("ERRORE DEBUG DATABASE: $e");
      }
    }
    print("=== FINE DEBUG ===");

    runApp(const MyApp());

  } catch (e) {
    if (kDebugMode) print("ERRORE CRITICO: $e");
    runApp(ErrorApp(error: e.toString()));
  }
}

// --- LOGICA DI SETUP DEL DATABASE CON FTS SEMPLIFICATO ---
Future<void> _setupDatabase(Database db, String dbName) async {
  await db.transaction((txn) async {
    // 1. Normalizzazione dei percorsi (solo su piattaforme non-Windows)
    if (!Platform.isWindows) {
      if (kDebugMode) print("[$dbName] Normalizzazione percorsi per piattaforma non-Windows...");
      await txn.rawUpdate("UPDATE spartiti SET percResto = REPLACE(percResto, '\\', '/')");
    }

    // 2. Configurazione FTS SEMPLIFICATA (solo su Windows per ora)
    if (Platform.isWindows) {
      try {
        final ftsTable = await txn.query('sqlite_master',
            where: 'type = ? AND name = ?',
            whereArgs: ['table', 'spartiti_fts']);

        if (ftsTable.isEmpty) {
          if (kDebugMode) print("[$dbName] Creazione indice FTS...");

          await txn.execute('''
            CREATE VIRTUAL TABLE spartiti_fts USING fts5 (
              titolo, autore, volume, ArchivioProvenienza, strumento,
              content = 'spartiti', content_rowid = 'IdBra'
            );
          ''');

          await txn.execute('''
            INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza, strumento)
            SELECT IdBra, titolo, autore, volume, ArchivioProvenienza, strumento FROM spartiti;
          ''');

          await txn.execute('''
            CREATE TRIGGER spartiti_ai AFTER INSERT ON spartiti BEGIN
              INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza, strumento)
              VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza, new.strumento);
            END;
          ''');

          await txn.execute('''
            CREATE TRIGGER spartiti_ad AFTER DELETE ON spartiti BEGIN
              INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza, strumento) 
              VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza, old.strumento);
            END;
          ''');

          await txn.execute('''
            CREATE TRIGGER spartiti_au AFTER UPDATE ON spartiti BEGIN
              INSERT INTO spartiti_fts(spartiti_fts, rowid, titolo, autore, volume, ArchivioProvenienza, strumento) 
              VALUES('delete', old.IdBra, old.titolo, old.autore, old.volume, old.ArchivioProvenienza, old.strumento);
              INSERT INTO spartiti_fts(rowid, titolo, autore, volume, ArchivioProvenienza, strumento)
              VALUES (new.IdBra, new.titolo, new.autore, new.volume, new.ArchivioProvenienza, new.strumento);
            END;
          ''');

          if (kDebugMode) print("[$dbName] FTS configurato con successo.");
        } else {
          if (kDebugMode) print("[$dbName] FTS già configurato.");
        }
      } catch (e) {
        if (kDebugMode) print("[$dbName] Errore FTS: $e");
      }
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'JamSet Final - Gestione Spartiti Musicali',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blueGrey,
            primary: Colors.blueAccent,
            secondary: Colors.amber
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          backgroundColor: const Color(0xFFFFF0F0),
          body: Center(
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  const Text('Errore Critico all\'Avvio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  SelectableText(error, textAlign: TextAlign.center),
                ])),
          )),
    );
  }
}