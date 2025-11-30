// lib/main.dart - CLEANED AND CORRECTED
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'screens/main_screen.dart'; // Import for the home screen

// Chiave globale per accedere al Navigator
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// === VARIABILI GLOBALI ===
// Queste variabili saranno popolate dalla funzione "Guardiano"
Map<String, String> appSystemConfig = {};
Database? dbGlobale;
Database? dbCatalogoAttivo;
Database? dbVecchio;
String gActiveCatalogDbName = '';
String gPercorsoPdf = '';
String gDatabasePath = '';
const String gSpartitiTableName = 'spartiti';
// =======================

void main() {
  // La funzione main ora è pulita. Avvia solo l'app.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
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
            secondary: Colors.amber),
      ),
      home: const MainScreen(), // MainScreen ora contiene la logica di inizializzazione
    );
  }
}
