// lib/screens/variazione_dati_generali_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:jamset_final/main.dart' as app_main;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class VariazioneDatiGeneraliScreen extends StatefulWidget {
  const VariazioneDatiGeneraliScreen({super.key});

  @override
  State<VariazioneDatiGeneraliScreen> createState() => _VariazioneDatiGeneraliScreenState();
}

class _VariazioneDatiGeneraliScreenState extends State<VariazioneDatiGeneraliScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  String? _error;

  final Map<String, TextEditingController> _controllers = {};
  List<Map<String, dynamic>> _elencoCataloghi = [];
  int? _selectedCatalogoId;
  String _dbPathForAppBar = 'Caricamento...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- 1. PERCORSO PDF DEFAULT MULTIPIATTAFORMA ---
  String _getDefaultPdfPath() {
    if (kIsWeb) return '/JamsetPDF';
    if (Platform.isWindows) return r'C:\JamsetPDF';
    if (Platform.isAndroid) return '/storage/emulated/0/JamsetPDF';
    if (Platform.isLinux) return '/home/JamsetPDF';
    if (Platform.isMacOS) return '/Users/Shared/JamsetPDF';
    return '/JamsetPDF';
  }

  Future<void> _loadData() async {
    try {
      if (app_main.dbGlobale == null) throw Exception('Database globale non inizializzato.');

      _dbPathForAppBar = app_main.dbGlobale!.path;

      final datiSistema = await app_main.dbGlobale!.query('DatiSistremaApp', limit: 1);
      if (datiSistema.isEmpty) throw Exception('Tabella DatiSistremaApp è vuota.');
      final dataRow = datiSistema.first;

      _elencoCataloghi = await app_main.dbGlobale!.query('elenco_cataloghi');

      // Inizializza controllers con valori esistenti o default
      dataRow.forEach((key, value) {
        _controllers[key] = TextEditingController(text: value?.toString() ?? '');
      });

      // Se PercorsoPDF è vuoto, imposta default
      if (_controllers['PercorsoPdf']?.text.isEmpty ?? true) {
        _controllers['PercorsoPdf']?.text = _getDefaultPdfPath();
      }

      _controllers['SistemaOperativo']?.text = Platform.operatingSystem;
      _controllers['TipoInterfaccia']?.text = (kIsWeb) ? 'Web' : 'Nativa';

      setState(() {
        _selectedCatalogoId = dataRow['id_catalogo_attivo'] as int?;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveData() async {
    if (_formKey.currentState!.validate() && app_main.dbGlobale != null) {
      try {
        // --- 3. VALIDAZIONE DATI CRITICI ---
        final validationResult = await _validateCriticalData();
        if (!validationResult.isValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(validationResult.message!), backgroundColor: Colors.orange),
          );
          return;
        }

        Map<String, dynamic> dataToSave = {};
        _controllers.forEach((key, controller) {
          if (key != 'SistemaOperativo' && key != 'TipoInterfaccia') {
            dataToSave[key] = controller.text;
          }
        });
        dataToSave['id_catalogo_attivo'] = _selectedCatalogoId;

        await app_main.dbGlobale!.update('DatiSistremaApp', dataToSave);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Dati salvati. Riavvia l\'app per rendere effettive le modifiche al catalogo.'),
                backgroundColor: Colors.green
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore nel salvataggio: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  // --- 2. SELEZIONE CARTELLE ALTERNATIVA A FILE_PICKER ---
  Future<void> _selectFolderManual(String controllerKey) async {
    final currentPath = _controllers[controllerKey]?.text ?? _getDefaultPdfPath();

    final newPath = await showDialog<String>(
      context: context,
      builder: (context) => FolderSelectionDialog(
        currentPath: currentPath,
        fieldName: controllerKey == 'PercorsoPdf' ? 'Percorso PDF' : 'Cartella',
      ),
    );

    if (newPath != null && newPath.isNotEmpty) {
      setState(() {
        _controllers[controllerKey]?.text = newPath;
      });
    }
  }

  // --- 3. VALIDAZIONE DATI CRITICI RAFFORZATA ---
  Future<ValidationResult> _validateCriticalData() async {
    // Validazione id_catalogo_attivo
    if (_selectedCatalogoId == null) {
      return ValidationResult(false, 'Seleziona un catalogo attivo');
    }

    // Validazione catalogo esistente
    final catalogoEsiste = _elencoCataloghi.any((cat) => cat['id'] == _selectedCatalogoId);
    if (!catalogoEsiste) {
      return ValidationResult(false, 'Il catalogo selezionato non esiste più');
    }

    // Validazione PercorsoPDF
    final percorsoPdf = _controllers['PercorsoPdf']?.text.trim() ?? '';
    if (percorsoPdf.isEmpty) {
      return ValidationResult(false, 'Il percorso PDF non può essere vuoto');
    }

    // Su piattaforme native, verifica accessibilità cartella
    if (!kIsWeb) {
      try {
        final dir = Directory(percorsoPdf);
        final exists = await dir.exists();
        if (!exists) {
          final createDir = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cartella non trovata'),
              content: Text('La cartella "$percorsoPdf" non esiste. Vuoi crearla?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Annulla'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Crea Cartella'),
                ),
              ],
            ),
          );

          if (createDir == true) {
            await dir.create(recursive: true);
          } else {
            return ValidationResult(false, 'Cartella PDF non accessibile');
          }
        }
      } catch (e) {
        return ValidationResult(false, 'Percorso PDF non valido: $e');
      }
    }

    return ValidationResult(true);
  }

  // --- ESPORTAZIONE/IMPORTAZIONE DATABASE (MANTENUTA) ---
  Future<void> _exportDatabase() async {
    if (app_main.dbGlobale == null) return;

    try {
      final sourceFile = File(app_main.dbGlobale!.path);
      final Directory? downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) throw Exception("Impossibile trovare la cartella Download.");

      final destinationPath = p.join(downloadsDir.path, 'DBGlobale_seed_EXPORTED.db');
      await sourceFile.copy(destinationPath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Database esportato in: $destinationPath'), duration: const Duration(seconds: 5)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore esportazione: $e')));
    }
  }

  Future<void> _importDatabase() async {
    // Implementare import con selezione file alternativa
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importa Database'),
        content: const Text('Per importare un database, sostituisci manualmente il file DBGlobale_seed.db nella cartella dell\'app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
          appBar: AppBar(title: const Text("Varia Dati Sistema")),
          body: const Center(child: CircularProgressIndicator())
      );
    }
    if (_error != null) {
      return Scaffold(
          appBar: AppBar(title: const Text("Errore")),
          body: Center(child: Text(_error!))
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Variazione Dati di Sistema'),
        backgroundColor: Colors.indigo,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SelectableText('Tabella: DatiSistremaApp', style: TextStyle(color: Colors.white, fontSize: 12)),
                SelectableText('Collocazione: $_dbPathForAppBar', style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // CAMPO CATALOGO ATTIVO (CRITICO)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: DropdownButtonFormField<int>(
                  value: _selectedCatalogoId,
                  items: _elencoCataloghi.map((catalogo) {
                    return DropdownMenuItem<int>(
                      value: catalogo['id'] as int,
                      child: Text('${catalogo['nome_catalogo']} (ID: ${catalogo['id']})'),
                    );
                  }).toList(),
                  onChanged: (newValue) => setState(() => _selectedCatalogoId = newValue),
                  decoration: const InputDecoration(
                    labelText: 'Catalogo Attivo *',
                    border: OutlineInputBorder(),
                    icon: Icon(Icons.warning, color: Colors.orange),
                  ),
                  validator: (value) => value == null ? 'Seleziona un catalogo attivo' : null,
                ),
              ),

              // CAMPO PERCORSO PDF (CRITICO)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: TextFormField(
                  controller: _controllers['PercorsoPdf'],
                  decoration: InputDecoration(
                    labelText: 'Percorso PDF *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () => _selectFolderManual('PercorsoPdf'),
                    ),
                    icon: const Icon(Icons.warning, color: Colors.orange),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Il percorso PDF è obbligatorio';
                    }
                    return null;
                  },
                ),
              ),

              // ALTRI CAMPI NON CRITICI
              ..._controllers.entries.map((entry) {
                final key = entry.key;
                final controller = entry.value;

                if (key == 'PercorsoPdf' || key == 'id_catalogo_attivo') {
                  return const SizedBox.shrink();
                }

                final bool isReadOnly = (key == 'SistemaOperativo' || key == 'TipoInterfaccia');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: controller,
                    readOnly: isReadOnly,
                    decoration: InputDecoration(
                      labelText: key,
                      border: const OutlineInputBorder(),
                      filled: isReadOnly,
                      fillColor: isReadOnly ? Colors.grey[200] : null,
                    ),
                  ),
                );
              }).toList(),

              // PULSANTI ESPORTA/IMPORTA
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _exportDatabase,
                    icon: const Icon(Icons.file_upload),
                    label: const Text('Esporta DB'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                  ElevatedButton.icon(
                    onPressed: _importDatabase,
                    icon: const Icon(Icons.file_download),
                    label: const Text('Importa DB'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveData,
        label: const Text('SALVA MODIFICHE CRITICHE'),
        icon: const Icon(Icons.save),
        backgroundColor: Colors.orange,
      ),
    );
  }
}

// --- CLASSI DI SUPPORTO ---

class ValidationResult {
  final bool isValid;
  final String? message;

  ValidationResult(this.isValid, [this.message]);
}

class FolderSelectionDialog extends StatefulWidget {
  final String currentPath;
  final String fieldName;

  const FolderSelectionDialog({
    super.key,
    required this.currentPath,
    required this.fieldName,
  });

  @override
  State<FolderSelectionDialog> createState() => _FolderSelectionDialogState();
}

class _FolderSelectionDialogState extends State<FolderSelectionDialog> {
  final TextEditingController _pathController = TextEditingController();
  final List<String> _suggestedPaths = [];

  @override
  void initState() {
    super.initState();
    _pathController.text = widget.currentPath;
    _loadSuggestedPaths();
  }

  void _loadSuggestedPaths() {
    _suggestedPaths.addAll([
      r'C:\JamsetPDF',
      '/storage/emulated/0/JamsetPDF',
      '/home/JamsetPDF',
      '/Users/Shared/JamsetPDF',
      '/JamsetPDF',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Seleziona ${widget.fieldName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: 'Percorso cartella',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Percorsi suggeriti:'),
          ..._suggestedPaths.map((path) => ListTile(
            title: Text(path),
            onTap: () {
              _pathController.text = path;
            },
          )).toList(),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_pathController.text),
          child: const Text('Conferma'),
        ),
      ],
    );
  }
}