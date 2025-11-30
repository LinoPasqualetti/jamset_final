// lib/screens/csv_viewer_screen.dart - VERSIONE CORRETTA
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:file_selector/file_selector.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen>
    with AutomaticKeepAliveClientMixin<CsvViewerScreen> {

  // CONTROLLERS & DATA
  final TextEditingController _searchController = TextEditingController();
  List<List<dynamic>> _csvData = [];
  List<List<dynamic>> _filteredCsvData = [];
  List<String> _csvHeaders = [];
  Map<String, int> _columnIndexMap = {};

  // STATE
  String _fileName = 'Nessun file selezionato';
  bool _isLoading = false;
  String? _error;
  bool _isOpeningPdf = false;

  // CONFIGURAZIONE PDF
  final String _pdfBasePath = "C:\\JamsetPDF";
  final String _webPdfBaseUrl = "http://192.168.1.100/JamsetPDF";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  Future<void> _requestStoragePermission() async {
    if (!Platform.isAndroid) return;
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accesso ai file negato. La ricerca PDF non funzionerà.')),
        );
      }
    }
  }

  // --- FILE SELECTION ---
  Future<void> _pickCsvFile() async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'File CSV',
      extensions: ['csv'],
    );

    final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);

    if (file != null) {
      await _loadCsv(file.path);
    }
  }

  // --- CSV LOADING & PARSING ---
  Future<void> _loadCsv(String filePath) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final file = File(filePath);
      if (!await file.exists()) throw Exception('File non trovato');

      String fileContent;
      try {
        fileContent = await file.readAsString(encoding: utf8);
      } catch (_) {
        fileContent = await file.readAsString(encoding: latin1);
      }

      // Delimiter fisso ; come nel tuo CSV
      String delimiter = ';';

      final allRows = CsvToListConverter(fieldDelimiter: delimiter).convert(fileContent);

      if (allRows.isEmpty) throw Exception('Il file CSV è vuoto o malformato.');

      setState(() {
        _csvHeaders = allRows[0].map((h) => h.toString()).toList();
        _columnIndexMap = _createColumnIndexMap(_csvHeaders);
        _csvData = allRows.length > 1 ? allRows.sublist(1) : [];
        _filteredCsvData = List.from(_csvData);
        _fileName = p.basename(filePath);
        _isLoading = false;
        _searchController.clear();
      });

    } catch (e) {
      setState(() {
        _error = 'Errore caricamento CSV: $e';
        _isLoading = false;
      });
    }
  }

  // --- MAPPATURA ESATTA BASATA SULLE INTESTAZIONI REALI ---
  Map<String, int> _createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};

    // DEBUG: Stampa le intestazioni per verifica
    print('INTESTAZIONI TROVATE: $headers');

    for (int i = 0; i < headers.length; i++) {
      String header = headers[i].toString().trim().toLowerCase();

      // MAPPA ESATTA CON I NOMI DELLE COLONNE REALI (case insensitive)
      if (header == 'titolo') {
        map['titolo'] = i;
      } else if (header == 'autore') {
        map['autore'] = i;
      } else if (header == 'strumento') {
        map['strumento'] = i;
      } else if (header == 'volume') {
        map['volume'] = i; // Contiene il nome file
      } else if (header == 'numpag') {
        map['numPag'] = i;
      } else if (header == 'percradice') {
        map['percRadice'] = i;
      } else if (header == 'percresto') {
        map['percResto'] = i; // Es. "\BiabDBRicerca\ItalianeLeggera\"
      } else if (header == 'archivioprovenienza') {
        map['archivioProvenienza'] = i;
      } else if (header == 'tipomulti') {
        map['tipomulti'] = i;
      }
    }

    // DEBUG: Stampa la mappatura risultante
    print('MAPPATURA CREATA: $map');

    return map;
  }

  String _getCellValue(List<dynamic> row, String columnKey, {String defaultValue = ''}) {
    if (_columnIndexMap.containsKey(columnKey)) {
      int? colIndex = _columnIndexMap[columnKey];
      if (colIndex != null && colIndex < row.length && row[colIndex] != null) {
        String value = row[colIndex].toString();
        // Pulisci i valori dagli apici
        return value.replaceAll("'", "").trim();
      }
    }
    return defaultValue;
  }

  // --- FILTERING ---
  void _filterData(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCsvData = List.from(_csvData);
      } else {
        final queryLower = query.toLowerCase();
        _filteredCsvData = _csvData.where((row) {
          return row.any((cell) => cell.toString().toLowerCase().contains(queryLower));
        }).toList();
      }
    });
  }

  // --- LOGICA APERTURA PDF ---
  Future<void> _handleOpenPdfAction({
    required String volume, // Nome file: "A CANZUNCELLA - Alunni del Sole.MGX"
    required String numPag,
    required String percRadice, // "C:\JamsetPDF"
    required String percResto,  // "\BiabDBRicerca\ItalianeLeggera\"
  }) async {
    if (_isOpeningPdf) return;

    setState(() {
      _isOpeningPdf = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Pulisci i percorsi
      String cleanPercResto = percResto.replaceAll(r'\', '/').replaceAll('//', '/');
      if (cleanPercResto.startsWith('/')) {
        cleanPercResto = cleanPercResto.substring(1);
      }

      await _verificaEApriPdf(
        subPathDaDati: cleanPercResto,
        fileNameDaDati: volume, // Usa direttamente il campo "volume" come nome file
        pageNumber: int.tryParse(numPag) ?? 1,
      );
    } catch (e) {
      _showErrorSnackBar('Errore apertura PDF: $e');
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          _isOpeningPdf = false;
        });
      }
    }
  }

  Future<void> _verificaEApriPdf({
    required String subPathDaDati,
    required String fileNameDaDati,
    required int pageNumber,
  }) async {
    String percorsoFinale = "N/A";
    bool fileEsiste = false;

    try {
      if (kIsWeb) {
        String percorsoRelativo = p.join(subPathDaDati, fileNameDaDati).replaceAll(r'\', '/');
        percorsoFinale = "$_webPdfBaseUrl/$percorsoRelativo";

        final response = await http.head(Uri.parse(percorsoFinale));
        fileEsiste = (response.statusCode == 200);

        if (fileEsiste) {
          _apriPdfWeb(percorsoFinale, pageNumber);
        }
      } else {
        final fullPath = p.join(_pdfBasePath, subPathDaDati, fileNameDaDati);
        percorsoFinale = fullPath;

        final file = File(fullPath);
        fileEsiste = await file.exists();

        if (fileEsiste) {
          await _apriPdfNativo(fullPath, pageNumber);
        }
      }

      if (!fileEsiste) {
        _showErrorSnackBar('File non trovato: $percorsoFinale');
      }
    } catch (e) {
      _showErrorSnackBar('Impossibile aprire il PDF: $e');
    }
  }

  void _apriPdfWeb(String url, int pageNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Disponibile (Web)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Il PDF può essere aperto al seguente URL:'),
            const SizedBox(height: 10),
            SelectableText(url, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Text('Pagina: $pageNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Future<void> _apriPdfNativo(String filePath, int pageNumber) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PDF Trovato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File: ${p.basename(filePath)}'),
            Text('Percorso: ${p.dirname(filePath)}'),
            Text('Pagina: $pageNumber'),
            const SizedBox(height: 10),
            const Text('✅ File trovato con successo!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Carica file CSV',
            onPressed: _pickCsvFile,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox(
              width: 300,
              height: 400,
              child: Image.asset(
                'assets/images/SherlockInBibliotecaAllaPicasso.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.image_not_supported, size: 100),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Cerca nella tabella...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterData('');
                        })
                        : null,
                  ),
                  onChanged: _filterData,
                ),
              ),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
          if (_isOpeningPdf)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Ricerca PDF in corso...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickCsvFile,
        label: const Text('Nuovo CSV'),
        icon: const Icon(Icons.file_upload),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text('Errore: $_error', style: const TextStyle(color: Colors.red)));
    }
    if (_csvData.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.upload_file),
          label: const Text('Carica CSV'),
          onPressed: _pickCsvFile,
        ),
      );
    }

    return _buildCsvListLikeJamsetGemini();
  }

  // --- BUILD LISTA CON MAPPATURA CORRETTA ---
  Widget _buildCsvListLikeJamsetGemini() {
    return Container(
      color: Colors.grey[200],
      child: ListView.builder(
        itemCount: _filteredCsvData.length,
        itemBuilder: (context, index) {
          final row = _filteredCsvData[index];

          // ESTRAZIONE CORRETTA CON I NOMI ESATTI DELLE COLONNE
          final titolo = _getCellValue(row, 'titolo');
          final autore = _getCellValue(row, 'autore');
          final strumento = _getCellValue(row, 'strumento');
          final volume = _getCellValue(row, 'volume'); // NOME FILE: "A CANZUNCELLA - Alunni del Sole.MGX"
          final numPag = _getCellValue(row, 'numPag');
          final provenienza = _getCellValue(row, 'archivioProvenienza');
          final tipoMulti = _getCellValue(row, 'tipomulti');
          final percResto = _getCellValue(row, 'percResto'); // "\BiabDBRicerca\ItalianeLeggera\"
          final percRadice = _getCellValue(row, 'percRadice'); // "C:\JamsetPDF"

          // DEBUG: Stampa i valori estratti
          if (index < 3) { // Stampa solo prime 3 righe per debug
            print('Riga $index - Titolo: $titolo, Volume: $volume, PercResto: $percResto');
          }

          // BANDIERA TITOLO
          bool showTitleHeader = false;
          if (index == 0) {
            showTitleHeader = true;
          } else {
            final previousRow = _filteredCsvData[index - 1];
            final String currentTitleClean = titolo.trim().toLowerCase();
            final String previousTitleClean = _getCellValue(previousRow, 'titolo').trim().toLowerCase();
            if (currentTitleClean != previousTitleClean) {
              showTitleHeader = true;
            }
          }

          final listTile = ListTile(
            dense: true,
            tileColor: Colors.white,
            title: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: <TextSpan>[
                  // AUTORE (se presente)
                  if (autore.isNotEmpty && autore != 'N/D')
                    TextSpan(
                      text: '$autore - ',
                      style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold),
                    ),
                  // STRUMENTO
                  if (strumento.isNotEmpty && strumento != 'N/D')
                    TextSpan(
                      text: '$strumento ',
                      style: const TextStyle(color: Colors.green),
                    ),
                  // PAGINA
                  if (numPag.isNotEmpty && numPag != 'N/D' && numPag != '0')
                    TextSpan(
                      text: 'Pag: $numPag ',
                      style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic),
                    ),
                  // TIPO MULTI
                  if (tipoMulti.isNotEmpty && tipoMulti != 'N/D')
                    TextSpan(
                      text: '[$tipoMulti] ',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  // PROVENIENZA
                  if (provenienza.isNotEmpty && provenienza != 'N/D')
                    TextSpan(
                      text: '($provenienza)',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                ],
              ),
            ),
            subtitle: volume.isNotEmpty && volume != 'N/D'
                ? Text(
              'File: ${p.basename(volume)}',
              style: const TextStyle(fontSize: 12, color: Colors.blue),
              overflow: TextOverflow.ellipsis,
            )
                : null,
            trailing: IconButton(
              icon: _isOpeningPdf
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'Apri PDF',
              onPressed: _isOpeningPdf
                  ? null
                  : () {
                _handleOpenPdfAction(
                  volume: volume,
                  numPag: numPag,
                  percRadice: percRadice,
                  percResto: percResto,
                );
              },
            ),
          );

          if (showTitleHeader) {
            return Card(
              margin: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
              elevation: 4.0,
              clipBehavior: Clip.antiAlias,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8.0),
                  topRight: Radius.circular(8.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.blueGrey,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(
                      titolo.trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.grey),
                  listTile,
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[300]!, width: 1.0),
                    left: BorderSide(color: Colors.grey[400]!, width: 1.0),
                    right: BorderSide(color: Colors.grey[400]!, width: 1.0),
                    bottom: BorderSide(color: Colors.grey[400]!, width: 1.0),
                  ),
                ),
                child: listTile,
              ),
            );
          }
        },
      ),
    );
  }
}