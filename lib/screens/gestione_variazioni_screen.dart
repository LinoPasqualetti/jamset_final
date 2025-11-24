// lib/screens/gestione_variazioni_screen.dart - CON IMMAGINE FABBRICA
import 'package:flutter/material.dart';
import 'system_config_screen.dart';

class GestioneVariazioniScreen extends StatelessWidget {
  const GestioneVariazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Variazioni e Dati'),
        backgroundColor: Colors.teal[700],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/FabbricaPerImpostazioni.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureButton(context,
                  icon: Icons.settings,
                  title: "Configurazione Sistema",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SystemConfigScreen()),
                    );
                  }
              ),
              const SizedBox(height: 20),
              _buildFeatureButton(context,
                  icon: Icons.construction,
                  title: "Funzioni Avanzate",
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Funzioni avanzate - Da implementare")),
                    );
                  }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap
  }) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 36, color: Colors.teal[700]),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}