// lib/screens/main_screen.dart - VERSIONE CON INTERFACCIA ORIGINALE
import 'package:flutter/material.dart';
import 'system_config_screen.dart';
import 'search_screen.dart';
import 'gestione_variazioni_screen.dart'; // AGGIUNGI QUESTA RIGA

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/SfondoLibriRBeAebCubista.jpg"),
            fit: BoxFit.cover,
          ),
        ),
/////////// Bottoni rettangolari
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
// BOTTONE 1 - CSW VIEWER
              Container(
                width: 280, // Larghezza fissa
                height: 40,  // Altezza fissa
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToCSWViewer(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700], // Colore di sfondo
                    foregroundColor: Colors.white,     // Colore testo/icona
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0), // Bordi stondati
                    ),
                    elevation: 6, // Ombra
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.visibility, size: 32), // Icona
                      const SizedBox(width: 16),
                      Text(
                        "CSW Viewer",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Colore testo esplicito
                        ),
                      ),
                    ],
                  ),
                ),
              ),

// BOTTONE 2 - QUERY DB
              Container(
                width: 280,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToQueryDB(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.search, size: 32),
                      const SizedBox(width: 16),
                      Text(
                        "Query DB",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

// BOTTONE 3 - CONFIGURAZIONE
              Container(
                width: 280,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToSystemConfig(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.settings, size: 32),
                      const SizedBox(width: 16),
                      Text(
                        "Configurazione",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

// BOTTONE 4 - GESTIONE VARIAZIONI
              Container(
                width: 280,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToGestioneVariazioni(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.tune, size: 32),
                      const SizedBox(width: 16),
                      Text(
                        "Gestione Variazioni",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

// BOTTONE 5 - ACCESSO RAPIDO
              Container(
                width: 280,
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToAccessoRapido(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.rocket_launch, size: 32),
                      const SizedBox(width: 16),
                      Text(
                        "Accesso rapido",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
//////////


      ),
    );
  }

  Widget _buildTransparentButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 36,
          color: Colors.white,
        ),
        style: IconButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 0,
          hoverColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }

  void _navigateToCSWViewer(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("CSW Viewer - Da implementare")),
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