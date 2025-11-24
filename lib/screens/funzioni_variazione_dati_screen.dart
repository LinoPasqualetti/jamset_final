// lib/screens/funzioni_variazione_dati_screen.dart - VERSIONE FINALE
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';

import 'package:jamset_new/main.dart';
import 'package:jamset_new/platform/opener_platform_interface.dart';

class FunzioniVariazioneDatiScreen extends StatefulWidget {
  const FunzioniVariazioneDatiScreen({super.key});

  @override
  State<FunzioniVariazioneDatiScreen> createState() =>
      _FunzioniVariazioneDatiScreenState();
}

class _FunzioniVariazioneDatiScreenState extends State<FunzioniVariazioneDatiScreen> with AutomaticKeepAliveClientMixin {
  bool _isLoading = true;
  bool _isQueryRunning = false;
  String? _error;
  List<Map<String, dynamic>> _queryResults = [];
  String _percorsoPdfGlobale = '';

  Duration? _dbQueryTime;

  late final TextEditingController _sqlController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    const String defaultQuery = """
SELECT 
  titolo, 
  autore, 
  volume, 
  strumento, 
  ArchivioProvenienza, 
  NumPag,
  PercResto,
  IdBra
FROM spartiti 
WHERE PercResto IS NOT NULL 
  AND volume IS NOT NULL
LIMIT 20
""";

    _sqlController = TextEditingController(text: defaultQuery);
    _loadPercorsoPdfGlobale();
  }

  @override
  void dispose() {
    _sqlController.dispose();
    super.dispose();
  }

  Future<void> _loadPercorsoPdfGlobale() async {
    try {
      if (dbGlobale == null) {
        throw Exception("Database globale non disponibile");
      }

      final configData = await dbGlobale!.query(
          'DatiSistremaApp',
          columns: ['PercorsoPdf'],
          limit: 1
      );

      if (configData.isNotEmpty) {
        setState(() {
          _percorsoPdfGlobale = configData.first['PercorsoPdf'] as String? ?? '';
        });
        print('Percorso PDF globale caricato: $_percorsoPdfGlobale');
      } else {
        throw Exception("Nessun percorso PDF configurato in DatiSistremaApp");
      }

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore nel caricamento percorso PDF: ${e.toString()}";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _executeQuery() async {
    if (dbCatalogoAttivo == null || _isQueryRunning) return;

    setState(() {
      _isQueryRunning = true;
      _error = null;
      _dbQueryTime = null;
    });

    try {
      final dbStopwatch = Stopwatch()..start();
      final results = await dbCatalogoAttivo!.rawQuery(_sqlController.text);
      dbStopwatch.stop();

      if (mounted) {
        setState(() {
          _queryResults = results;
          _isQueryRunning = false;
          _dbQueryTime = dbStopwatch.elapsed;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Errore esecuzione query: \n${e.toString()}";
          _queryResults = [];
          _isQueryRunning = false;
        });
      }
    }
  }

  Future<void> _openPdfFromRow(Map<String, dynamic> rowData) async {
    if (_percorsoPdfGlobale.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ERRORE: Percorso PDF non configurato. Vai in Impostazioni → Dati Globali.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final volume = rowData['volume']?.toString() ?? '';
      final numPag = rowData['NumPag']?.toString() ?? '1';
      final percResto = rowData['PercResto']?.toString() ?? '';

      // Costruisci il percorso completo
      String filePath = '$_percorsoPdfGlobale$percResto$volume';

      // Normalizza il percorso
      filePath = filePath.replaceAll(r'\', '/').replaceAll('//', '/');

      Navigator.of(context, rootNavigator: true).pop();

      await OpenerPlatformInterface.instance.openPdf(
        context: context,
        filePath: filePath,
        page: int.tryParse(numPag) ?? 1,
      );

    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore apertura PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

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
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              SelectableText(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPercorsoPdfGlobale,
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Query Database Spartiti'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Percorso PDF
            Card(
              color: _percorsoPdfGlobale.isNotEmpty ? Colors.green[50] : Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _percorsoPdfGlobale.isNotEmpty ? Icons.check_circle : Icons.warning,
                          color: _percorsoPdfGlobale.isNotEmpty ? Colors.green : Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _percorsoPdfGlobale.isNotEmpty
                              ? 'Percorso PDF configurato'
                              : 'Percorso PDF non configurato',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _percorsoPdfGlobale.isNotEmpty ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    if (_percorsoPdfGlobale.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Percorso: $_percorsoPdfGlobale',
                        style: const TextStyle(fontSize: 11),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Query Input
            TextField(
              controller: _sqlController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Comando SQL',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.all(12),
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            const SizedBox(height: 8),

            // Pulsanti compatti
            _buildQueryControls(),
            const Divider(height: 16),
            Expanded(
              child: _buildResultsSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Pulsante Esegui più compatto
            ElevatedButton(
              onPressed: _isQueryRunning ? null : _executeQuery,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Esegui Query'),
            ),
            const SizedBox(width: 12),
            // Indicatore risultati più compatto
            if (!_isQueryRunning && _queryResults.isNotEmpty)
              Text(
                'Trovati: ${_queryResults.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (_dbQueryTime != null)
          Text(
            'Tempo: ${_dbQueryTime!.inMilliseconds} ms',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _dbQueryTime!.inMilliseconds > 500 ? Colors.red : Colors.green,
            ),
          ),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isQueryRunning) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SelectableText(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
      ),
    );
    }
    if (_queryResults.isEmpty) {
      return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Nessun risultato',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
    }

    final columnKeys = _queryResults.first.keys.toList();
    return Column(
      children: [
        // Indicatore compatto
        Container(
          padding: const EdgeInsets.all(6.0),
          color: Colors.blueGrey[50],
          child: Row(
            children: [
              Icon(
                _percorsoPdfGlobale.isNotEmpty ? Icons.check_circle : Icons.warning,
                size: 14,
                color: _percorsoPdfGlobale.isNotEmpty ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _percorsoPdfGlobale.isNotEmpty
                      ? 'Clicca su una riga per aprire il PDF'
                      : 'Configura il percorso PDF in Impostazioni',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: DataTable2(
            columnSpacing: 8,
            horizontalMargin: 8,
            minWidth: 800,
            headingRowHeight: 32,
            dataRowHeight: 36,
            columns: columnKeys.map((key) {
              return DataColumn2(
                label: Text(
                    key,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)
                ),
                size: ColumnSize.S,
              );
            }).toList(),
            rows: _queryResults.map((row) {
              final hasPdfData = _percorsoPdfGlobale.isNotEmpty &&
                  row['PercResto'] != null &&
                  row['volume'] != null &&
                  row['NumPag'] != null;

              return DataRow2(
                onTap: hasPdfData ? () => _openPdfFromRow(row) : null,
                color: hasPdfData
                    ? null
                    : WidgetStateProperty.all(Colors.grey[100]),
                cells: row.values.map((cell) => DataCell(
                  SelectableText(
                    cell?.toString() ?? 'NULL',
                    style: TextStyle(
                      fontSize: 10,
                      color: hasPdfData ? Colors.black : Colors.grey,
                    ),
                    maxLines: 1,
                  ),
                )).toList(),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

