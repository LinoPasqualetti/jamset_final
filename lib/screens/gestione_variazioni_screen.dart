// lib/screens/gestione_variazioni_screen.dart
import 'package:flutter/material.dart';
import 'package:jamset_final/screens/gestione_dati_globali_screen.dart'; // NUOVA IMPORT
import 'package:jamset_final/screens/gestisci_elenco_cataloghi.dart';
// RIMUOVI questa riga: import 'package:jamset_final/screens/system_config_screen.dart';

class GestioneVariazioniScreen extends StatelessWidget {
  const GestioneVariazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Variazioni'),
      ),
      body: ListView(
        children: [
          // ... altri elementi del menu ...

          // SOSTITUISCI questa voce del menu:
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Gestione Dati Globali'),
            subtitle: const Text('Configurazione sistema e dati globali'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestioneDatiGlobaliScreen(), // NUOVA SCHERMATA
                ),
              );
            },
          ),
          // Aggiungi questo nel Column children[] di gestione_variazioni_screen.dart
          ListTile(
            leading: const Icon(Icons.list_alt, color: Colors.blue),
            title: const Text('Variazione Elenco Cataloghi'),
            subtitle: const Text('Gestisci l\'elenco dei cataloghi musicali'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GestisciElencoCataloghi(),
                ),
              );
            },
          ),

          // RIMUOVI o COMMENTA questa vecchia voce:
          /*
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurazione Sistema'),
            subtitle: const Text('Impostazioni di sistema globali'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SystemConfigScreen(), // VECCHIA SCHERMATA
                ),
              );
            },
          ),
          */
        ],
      ),
    );
  }
}