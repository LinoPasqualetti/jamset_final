// lib/screens/main_screen.dart - REFACTORED FOR ASYNC INITIALIZATION
import 'package:flutter/material.dart';
import 'package:jamset_final/screens/inizializza_i_db_della_app.dart'; // FIX: IMPORT MANCANTE
import 'system_config_screen.dart';
import 'search_screen.dart';
import 'gestione_variazioni_screen.dart';
import 'package:jamset_final/screens/csv_viewer_screen.dart';

// FASE 3: Costruire l'Interfaccia in Base al Risultato (con FutureBuilder)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    // Avvio del "Guardiano": chiamiamo la funzione di inizializzazione
    // e salviamo la "promessa" nel nostro stato.
    _initializationFuture = inizializzaIDbDellaApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          // Caso 1: Mentre il Guardiano Lavora
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Inizializzazione database in corso..."),
                ],
              ),
            );
          }

          // Caso 2: Se il Guardiano Fallisce
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 20),
                    const Text(
                      'Errore Critico durante l\'inizializzazione',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Caso 3: Se il Guardiano ha Successo
          // Solo ora costruiamo l'interfaccia completa.
          return _buildMainContent(context);
        },
      ),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/SfondoLibriRBeAebCubista.jpg"),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // BOTTONE 1 - CSV VIEWER
              _buildButton(
                context,
                icon: Icons.table_chart,
                label: "CSV Viewer",
                color: Colors.blue[700]!,
                onPressed: () => _navigateToCsvViewer(context),
              ),
              // BOTTONE 2 - QUERY DB
              _buildButton(
                context,
                icon: Icons.search,
                label: "Query DB",
                color: Colors.green[700]!,
                onPressed: () => _navigateToQueryDB(context),
              ),
              // BOTTONE 3 - CONFIGURAZIONE
              _buildButton(
                context,
                icon: Icons.settings,
                label: "Configurazione",
                color: Colors.orange[700]!,
                onPressed: () => _navigateToSystemConfig(context),
              ),
              // BOTTONE 4 - GESTIONE VARIAZIONI
              _buildButton(
                context,
                icon: Icons.tune,
                label: "Gestione Variazioni",
                color: Colors.purple[700]!,
                onPressed: () => _navigateToGestioneVariazioni(context),
              ),
              // BOTTONE 5 - ACCESSO RAPIDO
              _buildButton(
                context,
                icon: Icons.rocket_launch,
                label: "Accesso rapido",
                color: Colors.red[700]!,
                onPressed: () => _navigateToAccessoRapido(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 280,
      height: 80,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 6,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Icon(icon, size: 32),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCsvViewer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CsvViewerScreen(), // Rimuovi const
      ),
    );
  }

  void _navigateToQueryDB(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SearchScreen()),
    );
  }

  void _navigateToSystemConfig(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SystemConfigScreen()),
    );
  }

  void _navigateToAccessoRapido(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Accesso Rapido - Da implementare")),
    );
  }

  void _navigateToGestioneVariazioni(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GestioneVariazioniScreen()),
    );
  }
}
