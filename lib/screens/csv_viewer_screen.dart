// lib/screens/csv_viewer_screen.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:jamset_final/main.dart' as app_main;

class CsvViewerScreen extends StatefulWidget {
  const CsvViewerScreen({super.key});

  @override
  State<CsvViewerScreen> createState() => _CsvViewerScreenState();
}

class _CsvViewerScreenState extends State<CsvViewerScreen>
    with AutomaticKeepAliveClientMixin<CsvViewerScreen> {

  // SPEECH TO TEXT
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  String _lastWords = '';

  // CONTROLLERS PER FILTRI
  final TextEditingController _cercaTitoloController = TextEditingController();
  final TextEditingController _cercaAutoreController = TextEditingController();
  final TextEditingController _cercaProvenienzaController = TextEditingController();
  final TextEditingController _cercaVolumeController = TextEditingController();
  final TextEditingController _cercaTipoMultiController = TextEditingController();
  final TextEditingController _cercaStrumentoController = TextEditingController();

  // DATI CSV
  List<List<dynamic>> _csvData = [];
  List<List<dynamic>> _filteredCsvData = [];
  Map<String, int> _columnIndexMap = {};
  List<String> _csvHeaders = [];

  // FILTRI
  String _queryTitolo = '';
  String _queryAutore = '';
  String _queryProvenienza = '';
  String _queryVolume = '';
  String _queryTipoMulti = '';
  String _queryStrumento = '';
  String _Laricerca = '';

  // STATO APPLICAZIONE
  String _fileName = 'Nessun file selezionato';
  bool _isLoading = false;
  String? _error;
  String _percorsoPdfForAppBar = 'Caricamento...';

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _requestStoragePermission();
    _loadGlobalConfig();
  }

  @override
  void dispose() {
    _cercaTitoloController.dispose();
    _cercaAutoreController.dispose();
    _cercaProvenienzaController.dispose();
    _cercaVolumeController.dispose();
    _cercaTipoMultiController.dispose();
    _cercaStrumentoController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  // --- INIZIALIZZAZIONE SPEECH TO TEXT ---
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _speechToText.listen(
      onResult: (result) => _onSpeechResult(result.recognizedWords),
      localeId: 'it_IT',
    );
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(String result) {
    setState(() {
      _lastWords = result;
      _cercaTitoloController.text = _lastWords;
    });
  }

  // --- CARICAMENTO CONFIGURAZIONE GLOBALE ---
  Future<void> _loadGlobalConfig() async {
    if (app_main.dbGlobale != null) {
      try {
        final configData = await app_main.dbGlobale!.query('DatiSistremaApp', columns: ['PercorsoPdf'], limit: 1);
        if (mounted && configData.isNotEmpty) {
          setState(() {
            _percorsoPdfForAppBar = configData.first['PercorsoPdf'] as String? ?? 'Non impostato';
          });
        }
      } catch (e) {
        if (mounted) setState(() => _percorsoPdfForAppBar = 'Errore');
      }
    } else {
      if (mounted) setState(() => _percorsoPdfForAppBar = 'DB non disp.');
    }
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

  // --- SELEZIONE CSV MIGLIORATA ---
  Future<void> _pickAndLoadCsv() async {
    try {
      final defaultPath = await _getDefaultDirectory();

      final csvPath = await showDialog<String>(
        context: context,
        builder: (context) => _FileSelectionDialog(
          currentPath: defaultPath,
          fileType: 'CSV',
          extensions: ['csv'],
        ),
      );

      if (csvPath != null && csvPath.isNotEmpty) {
        await _loadCsvWithDelimiterDetection(csvPath);
      }
    } catch (e) {
      print("ERRORE DURANTE IL CARICAMENTO DEL CSV: $e");
      _showError('Errore caricamento CSV: $e');
    }
  }

  // --- CARICAMENTO CSV CON RILEVAMENTO DELIMITATORE (come jamsetgemini) ---
  Future<void> _loadCsvWithDelimiterDetection(String filePath) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File non trovato: $filePath');
      }

      String fileContent;
      try {
        fileContent = await file.readAsString(encoding: utf8);
      } on FileSystemException {
        fileContent = await file.readAsString(encoding: latin1);
      }

      // RILEVAMENTO AUTOMATICO DEL DELIMITATORE
      String delimiter = ';';
      if (fileContent.isNotEmpty) {
        final firstLine = fileContent.split('\n')[0];
        final commaCount = ','.allMatches(firstLine).length;
        final semicolonCount = ';'.allMatches(firstLine).length;

        if (commaCount > semicolonCount) {
          delimiter = ',';
        }
      }

      // CONVERSIONE CSV
      final allRowsFromFile = CsvToListConverter(fieldDelimiter: delimiter).convert(fileContent);

      if (allRowsFromFile.isEmpty) {
        setState(() {
          _csvData = [];
          _filteredCsvData = [];
          _csvHeaders = [];
          _columnIndexMap = {};
          _fileName = p.basename(filePath);
          _isLoading = false;
        });
      } else {
        setState(() {
          _csvHeaders = allRowsFromFile[0].map((h) => h.toString()).toList();
          _columnIndexMap = _createColumnIndexMap(_csvHeaders);
          _csvData = allRowsFromFile.length > 1 ? allRowsFromFile.sublist(1) : [];
          _filteredCsvData = List.from(_csvData);
          _fileName = p.basename(filePath);
          // Reset filtri
          _queryTitolo = '';
          _queryAutore = '';
          _queryProvenienza = '';
          _queryVolume = '';
          _queryTipoMulti = '';
          _queryStrumento = '';
          _Laricerca = '';
          _cercaTitoloController.clear();
          _cercaAutoreController.clear();
          _cercaProvenienzaController.clear();
          _cercaVolumeController.clear();
          _cercaTipoMultiController.clear();
          _cercaStrumentoController.clear();
          _isLoading = false;
        });
      }

    } catch (e) {
      setState(() {
        _error = 'Errore elaborazione CSV: $e';
        _isLoading = false;
      });
    }
  }

  // --- MAPPA COLONNE (come jamsetgemini) ---
  Map<String, int> _createColumnIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      String headerFromFile = headers[i].toString().trim().toLowerCase();
      const keys = {
        'idbra': 'IdBra', 'tipomulti': 'TipoMulti', 'tipodocu': 'TipoDocu',
        'titolo': 'Titolo', 'autore': 'Autore', 'strumento': 'strumento',
        'archivioprovenienza': 'ArchivioProvenienza', 'volume': 'Volume',
        'numpag': 'NumPag', 'numorig': 'NumOrig', 'primolink': 'PrimoLink',
        'idvolume': 'IdVolume', 'percradice': 'PercRadice', 'percresto': 'PercResto'
      };
      if (keys.containsKey(headerFromFile)) {
        map[keys[headerFromFile]!] = i;
      }
    }
    return map;
  }

  String _getCellValue(List<dynamic> row, String columnKey, {String defaultValue = 'N/D'}) {
    if (_columnIndexMap.containsKey(columnKey)) {
      int? colIndex = _columnIndexMap[columnKey];
      if (colIndex != null && colIndex < row.length && row[colIndex] != null) {
        return row[colIndex].toString();
      }
    }
    return defaultValue;
  }

  // --- FILTRI (logica come jamsetgemini) ---
  void _filterData() {
    setState(() {
      if (_queryTitolo.isEmpty && _queryAutore.isEmpty && _queryProvenienza.isEmpty &&
          _queryVolume.isEmpty && _queryTipoMulti.isEmpty && _queryStrumento.isEmpty) {
        _filteredCsvData = List.from(_csvData);
        _Laricerca = '';
      } else {
        _filteredCsvData = _csvData.where((row) {
          final titolo = _getCellValue(row, 'Titolo', defaultValue: '').toLowerCase();
          final autore = _getCellValue(row, 'Autore', defaultValue: '').toLowerCase();
          final provenienza = _getCellValue(row, 'ArchivioProvenienza', defaultValue: '').toLowerCase();
          final volume = _getCellValue(row, 'Volume', defaultValue: '').toLowerCase();
          final tipoMulti = _getCellValue(row, 'TipoMulti', defaultValue: '').toLowerCase();
          final strumento = _getCellValue(row, 'strumento', defaultValue: '').toLowerCase();

          return (_queryTitolo.isEmpty || titolo.contains(_queryTitolo)) &&
              (_queryAutore.isEmpty || autore.contains(_queryAutore)) &&
              (_queryProvenienza.isEmpty || provenienza.contains(_queryProvenienza)) &&
              (_queryVolume.isEmpty || volume.contains(_queryVolume)) &&
              (_queryTipoMulti.isEmpty || tipoMulti.contains(_queryTipoMulti)) &&
              (_queryStrumento.isEmpty || strumento.contains(_queryStrumento));
        }).toList();

        // COSTRUZIONE STRINGA RICERCA (come jamsetgemini)
        _Laricerca = "Applicato filtro su:";
        if (_queryTitolo.isNotEmpty) {  _Laricerca += " Titolo $_queryTitolo -";}
        if (_queryAutore.isNotEmpty) { _Laricerca += " Autore $_queryAutore - ";}
        if (_queryProvenienza.isNotEmpty) { _Laricerca += " Provenienza $_queryProvenienza - ";}
        if (_queryVolume.isNotEmpty) { _Laricerca += " Volume $_queryVolume - " ;}
        if (_queryTipoMulti.isNotEmpty) { _Laricerca += " TipoMulti $_queryTipoMulti - ";}
        if (_queryStrumento.isNotEmpty) { _Laricerca += " Strumento $_queryStrumento - ";}
      }
    });
  }

  // --- DIALOG FILTRI AVANZATI (come jamsetgemini) ---
  Future<void> _showAdvancedFiltersDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filtri Avanzati'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(controller: _cercaAutoreController, decoration: const InputDecoration(labelText: 'Autore', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaProvenienzaController, decoration: const InputDecoration(labelText: 'Provenienza', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaVolumeController, decoration: const InputDecoration(labelText: 'Volume', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaTipoMultiController, decoration: const InputDecoration(labelText: 'TipoMulti', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _cercaStrumentoController, decoration: const InputDecoration(labelText: 'Strumento', isDense: true)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annulla'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Applica'),
              onPressed: () {
                setState(() {
                  _queryAutore = _cercaAutoreController.text.toLowerCase();
                  _queryProvenienza = _cercaProvenienzaController.text.toLowerCase();
                  _queryVolume = _cercaVolumeController.text.toLowerCase();
                  _queryTipoMulti = _cercaTipoMultiController.text.toLowerCase();
                  _queryStrumento = _cercaStrumentoController.text.toLowerCase();
                });
                _filterData();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- APERTURA PDF (adattata per jamset_final) ---
  Future<void> _openPdf(List<dynamic> row) async {
    try {
      final volume = _getCellValue(row, 'Volume');
      final numPag = _getCellValue(row, 'NumPag');
      final percResto = _getCellValue(row, 'PercResto');

      if (volume.isEmpty || percResto.isEmpty) {
        throw Exception('Campi Volume o PercResto mancanti nel CSV');
      }

      // COSTRUZIONE PERCORSO: PercorsoPdf + PercResto + Volume
      final percorsoPdf = await _getPercorsoPdfFromSystem();
    //  String fullPath = p.join(percorsoPdf, percResto, volume);
      String fullPath = percorsoPdf + percResto + volume;
      print('Tentativo apertura PDF: $fullPath');

      // TENTATIVO APERTURA PRINCIPALE
      final file = File(fullPath);
      if (await file.exists()) {
        final uri = Uri.file(fullPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }

      // FALLBACK
      await _tryAlternativePaths(fullPath, volume);

    } catch (e) {
      _showError('Impossibile aprire il PDF: $e');
    }
  }

  Future<String> _getPercorsoPdfFromSystem() async {
    try {
      if (app_main.dbGlobale != null) {
        final datiSistema = await app_main.dbGlobale!.query('DatiSistremaApp', columns: ['PercorsoPdf'], limit: 1);
        if (datiSistema.isNotEmpty && datiSistema.first['PercorsoPdf'] != null) {
          return datiSistema.first['PercorsoPdf']!.toString();
        }
      }
    } catch (e) {
      print('Errore recupero PercorsoPdf: $e');
    }
    return _getDefaultPdfPath();
  }

  Future<void> _tryAlternativePaths(String originalPath, String fileName) async {
    final downloadsDir = await getDownloadsDirectory();
    final downloadsPath = downloadsDir?.path ?? '';
    final percorsoPdf = await _getPercorsoPdfFromSystem();

    final alternatives = [
      originalPath,
      p.join(percorsoPdf, fileName),
      p.join(downloadsPath, fileName),
    ];

    for (final path in alternatives) {
      final file = File(path);
      if (await file.exists()) {
        final uri = Uri.file(path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }
    }

    _showError('PDF non trovato: $fileName');
  }

  // --- UI PRINCIPALE (come jamsetgemini) ---
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: SelectableText(
          'Spartiti Visualizzatore - Cartella: $_percorsoPdfForAppBar Filtri: $_Laricerca',
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cercaTitoloController,
                        decoration: const InputDecoration(labelText: 'Titolo', isDense: true),
                        onSubmitted: (_) {
                          setState(() { _queryTitolo = _cercaTitoloController.text.toLowerCase(); });
                          _filterData();
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(_speechToText.isListening ? Icons.mic_off : Icons.mic, color: Colors.black),
                      tooltip: 'Ricerca Vocale',
                      onPressed: !_speechEnabled ? null : (_speechToText.isNotListening ? _startListening : _stopListening),
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_list_alt, color: Colors.blue),
                      tooltip: 'Filtri Avanzati',
                      onPressed: _showAdvancedFiltersDialog,
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.search),
                    label: const Text('Filtra'),
                    onPressed: () {
                      setState(() {
                        _queryTitolo = _cercaTitoloController.text.toLowerCase();
                        _queryAutore = _cercaAutoreController.text.toLowerCase();
                        _queryProvenienza = _cercaProvenienzaController.text.toLowerCase();
                        _queryVolume = _cercaVolumeController.text.toLowerCase();
                        _queryTipoMulti = _cercaTipoMultiController.text.toLowerCase();
                        _queryStrumento = _cercaStrumentoController.text.toLowerCase();
                      });
                      _filterData();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndLoadCsv,
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
      return Center(child: Text('Errore: $_error'));
    }
    if (_csvData.isEmpty) {
      return _buildEmptyState();
    }
    return _buildCsvList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Carica un file CSV per iniziare'),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Carica CSV'),
            onPressed: _pickAndLoadCsv,
          ),
        ],
      ),
    );
  }

  // --- LISTA CSV CON BANDIERE E COLORI (come jamsetgemini) ---
  Widget _buildCsvList() {
    return Container(
      color: Colors.grey[200],
      child: ListView.builder(
        itemCount: _filteredCsvData.length,
        itemBuilder: (context, index) {
          final row = _filteredCsvData[index];

          final titolo = _getCellValue(row, 'Titolo');
          final strumento = _getCellValue(row, 'strumento');
          final volume = _getCellValue(row, 'Volume');
          final numPag = _getCellValue(row, 'NumPag');
          final provenienza = _getCellValue(row, 'ArchivioProvenienza');
          final tipoMulti = _getCellValue(row, 'TipoMulti');

          // LOGICA BANDIERA TITOLO (come jamsetgemini)
          bool showTitleHeader = false;
          if (index == 0) {
            showTitleHeader = true;
          } else {
            final previousRow = _filteredCsvData[index - 1];
            final String currentTitleClean = titolo.trim().toLowerCase();
            final String previousTitleClean = _getCellValue(previousRow, 'Titolo').trim().toLowerCase();
            if (currentTitleClean != previousTitleClean) {
              showTitleHeader = true;
            }
          }

          final strumentoListTile = ListTile(
            dense: true,
            tileColor: Colors.white,
            title: RichText(
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: <TextSpan>[
                  if (strumento.isNotEmpty)
                    TextSpan(
                      text: '$strumento ',
                      style: const TextStyle(color: Colors.green),
                    ),
                  if (numPag.isNotEmpty)
                    TextSpan(
                      text: 'Pag: $numPag del ',
                      style: const TextStyle(color: Colors.black, fontStyle: FontStyle.italic),
                    ),
                  if (volume.isNotEmpty)
                    TextSpan(
                      text: 'Vol: $volume ',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (provenienza.isNotEmpty)
                    TextSpan(
                      text: '($provenienza) ',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  if (tipoMulti.isNotEmpty)
                    TextSpan(
                      text: '$tipoMulti ',
                      style: const TextStyle(color: Colors.purple),
                    ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
              tooltip: 'Apri PDF',
              onPressed: () => _openPdf(row),
            ),
          );

          // BANDIERA TITOLO (come jamsetgemini)
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
                  strumentoListTile,
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
                child: strumentoListTile,
              ),
            );
          }
        },
      ),
    );
  }

  // --- METODI DI SUPPORTO ---
  Future<String> _getDefaultDirectory() async {
    if (Platform.isAndroid) {
      final downloadsDir = await getDownloadsDirectory();
      return downloadsDir?.path ?? '/storage/emulated/0/Download';
    } else if (Platform.isWindows) {
      return r'C:\';
    } else {
      final documentsDir = await getApplicationDocumentsDirectory();
      return documentsDir.path;
    }
  }

  String _getDefaultPdfPath() {
    if (Platform.isWindows) return r'C:\JamsetPDF';
    if (Platform.isAndroid) return '/storage/emulated/0/JamsetPDF';
    if (Platform.isLinux) return '/home/JamsetPDF';
    if (Platform.isMacOS) return '/Users/Shared/JamsetPDF';
    return '/JamsetPDF';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// --- DIALOG SELEZIONE FILE (mantenuto) ---
class _FileSelectionDialog extends StatefulWidget {
  final String currentPath;
  final String fileType;
  final List<String> extensions;

  const _FileSelectionDialog({
    required this.currentPath,
    required this.fileType,
    required this.extensions,
  });

  @override
  State<_FileSelectionDialog> createState() => __FileSelectionDialogState();
}

class __FileSelectionDialogState extends State<_FileSelectionDialog> {
  final TextEditingController _pathController = TextEditingController();
  List<FileSystemEntity> _files = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.currentPath;
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    try {
      final dir = Directory(_pathController.text);
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        setState(() {
          _files = entities.where((entity) {
            if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();
              return widget.extensions.any((e) => ext == '.$e');
            }
            return entity is Directory;
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _files = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _files = [];
        _isLoading = false;
      });
    }
  }

  void _navigateToDirectory(String path) {
    _pathController.text = path;
    _loadFiles();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Seleziona file ${widget.fileType}'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Percorso',
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (value) => _navigateToDirectory(value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadFiles,
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _files.isEmpty
                  ? const Center(child: Text('Nessun file trovato'))
                  : ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final entity = _files[index];
                  final isDir = entity is Directory;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                      title: Text(p.basename(entity.path)),
                      subtitle: isDir ? null : Text(
                          '${(entity as File).lengthSync() ~/ 1024} KB'
                      ),
                      onTap: () {
                        if (isDir) {
                          _navigateToDirectory(entity.path);
                        } else {
                          Navigator.of(context).pop(entity.path);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ],
    );
  }
}