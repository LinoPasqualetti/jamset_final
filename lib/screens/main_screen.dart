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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // BOTTONI COMPLETAMENTE TRASPARENTI
              _buildTransparentButton(Icons.visibility, "CSW Viewer", () {
                _navigateToCSWViewer(context);
              }),
              const SizedBox(height: 25),

              _buildTransparentButton(Icons.search, "Query DB", () {
                _navigateToQueryDB(context);
              }),
              const SizedBox(height: 25),

              _buildTransparentButton(Icons.settings, "Configurazione", () {
                _navigateToSystemConfig(context);
              }),
              const SizedBox(height: 25),

              _buildTransparentButton(Icons.tune, "Gestione Variazioni", () {
                _navigateToGestioneVariazioni(context);
              }),
              const SizedBox(height: 25),

              _buildTransparentButton(Icons.rocket_launch, "Accesso rapido", () {
                _navigateToAccessoRapido(context);
              }),
            ],
          ),
        ),
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