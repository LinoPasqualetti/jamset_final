// lib/screens/gestisci_elenco_cataloghi.dart
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:jamset_final/main.dart' as app_main;
import 'package:jamset_final/screens/varia_catalogo_screen.dart';

class GestisciElencoCataloghi extends StatefulWidget {
  const GestisciElencoCataloghi({super.key});

  @override
  State<GestisciElencoCataloghi> createState() => _GestisciElencoCataloghiState();
}

class _GestisciElencoCataloghiState extends State<GestisciElencoCataloghi> {
  List<Map<String, dynamic>> _cataloghi = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCataloghi();
  }

  // LOGICA PER CARICARE CATALOGHI DA DB GLOBALE
  Future<void> _loadCataloghi() async {
    try {
      if (app_main.dbGlobale == null) {
        throw Exception('Il database globale non è stato inizializzato.');
      }

      final data = await app_main.dbGlobale!.query(
          'elenco_cataloghi',
          orderBy: 'nome_catalogo'
      );

      if (mounted) {
        setState(() {
          _cataloghi = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // NAVIGAZIONE VERSO SCHERMATA VARIAZIONE CATALOGO
  Future<void> _navigateToVariaScreen([Map<String, dynamic>? catalogo]) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => VariaCatalogoScreen(
          catalogoData: catalogo,
          totalCataloghi: _cataloghi.length,
        ),
      ),
    );

    // Ricarica lista se ci sono state modifiche
    if (result == true) {
      await _loadCataloghi();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Elenco Cataloghi'),
        actions: [
          // PULSANTE AGGIUNGI NUOVO CATALOGO
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToVariaScreen(),
            tooltip: 'Nuovo Catalogo',
          ),
          // PULSANTE RICARICA
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCataloghi,
            tooltip: 'Ricarica',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Errore di caricamento',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              SelectableText(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCataloghi,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cataloghi.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nessun catalogo trovato',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Premi il pulsante + per aggiungere il primo catalogo',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToVariaScreen(),
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi Catalogo'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _cataloghi.length,
      itemBuilder: (context, index) {
        final catalogo = _cataloghi[index];
        return _buildCatalogoCard(catalogo);
      },
    );
  }

  Widget _buildCatalogoCard(Map<String, dynamic> catalogo) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: _getColorFromId(catalogo['id']),
          child: Text(
            catalogo['id'].toString(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          catalogo['nome_catalogo']?.toString() ?? 'Senza nome',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'File: ${catalogo['nome_file_db']?.toString() ?? 'N/A'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Brani: ${catalogo['conteggio_brani']?.toString() ?? '0'}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              'Ult. agg: ${_formatDate(catalogo['data_ultimo_aggiornamento'])}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () => _navigateToVariaScreen(catalogo),
          tooltip: 'Modifica Catalogo',
        ),
        onTap: () => _navigateToVariaScreen(catalogo),
      ),
    );
  }

  // METODI DI SUPPORTO
  Color _getColorFromId(dynamic id) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
    ];
    final index = (id as int? ?? 0) % colors.length;
    return colors[index];
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Mai';
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date.toString();
    }
  }
}