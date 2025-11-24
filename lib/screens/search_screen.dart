// lib/screens/search_screen.dart - VERSIONE AVANZATA COMPLETA
import 'package:flutter/material.dart';
import 'package:jamset_final/main.dart' as app_main; // MODIFICATO: jamset_final
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show File, Platform, Process;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _strumentoController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _provenienzaController = TextEditingController();
  final TextEditingController _tipoMultiController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _strumentoController.addListener(_onFiltersChanged);
    _volumeController.addListener(_onFiltersChanged);
    _provenienzaController.addListener(_onFiltersChanged);
    _tipoMultiController.addListener(_onFiltersChanged);
  }

  void _onFiltersChanged() {
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _searchError = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final db = app_main.dbCatalogoAttivo;
      if (db == null) throw Exception('Database non disponibile');

      List<String> whereConditions = [];
      List<dynamic> whereArgs = [];

      // Ricerca principale
      whereConditions.add('(titolo LIKE ? OR autore LIKE ? OR strumento LIKE ? OR volume LIKE ? OR ArchivioProvenienza LIKE ?)');
      String searchTerm = '%$query%';
      whereArgs.addAll([searchTerm, searchTerm, searchTerm, searchTerm, searchTerm]);

      // Filtri digitabili
      if (_strumentoController.text.isNotEmpty) {
        whereConditions.add('strumento LIKE ?');
        whereArgs.add('%${_strumentoController.text}%');
      }

      if (_volumeController.text.isNotEmpty) {
        whereConditions.add('volume LIKE ?');
        whereArgs.add('%${_volumeController.text}%');
      }

      if (_provenienzaController.text.isNotEmpty) {
        whereConditions.add('ArchivioProvenienza LIKE ?');
        whereArgs.add('%${_provenienzaController.text}%');
      }

      // Filtro TipoMulti
      if (_tipoMultiController.text.isNotEmpty) {
        whereConditions.add('TipoMulti LIKE ?');
        whereArgs.add('%${_tipoMultiController.text}%');
      }

      String whereClause = whereConditions.isNotEmpty ? 'WHERE ${whereConditions.join(' AND ')}' : '';

      List<Map<String, dynamic>> results = await db.rawQuery('''
        SELECT * FROM spartiti 
        $whereClause 
        ORDER BY titolo ASC, strumento ASC 
        LIMIT 200
      ''', whereArgs);

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });

    } catch (e) {
      setState(() {
        _isSearching = false;
        _searchError = 'Errore ricerca: $e';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
      _searchError = '';
    });
  }

  void _resetFilters() {
    _strumentoController.clear();
    _volumeController.clear();
    _provenienzaController.clear();
    _tipoMultiController.clear();
    if (_searchController.text.isNotEmpty) {
      _performSearch(_searchController.text);
    }
  }

  String _buildPdfPath(Map<String, dynamic> spartito) {
    final basePath = app_main.gPercorsoPdf;
    final pdfRelativePath = spartito['PercResto']?.toString() ?? '';
    final volume = spartito['volume']?.toString() ?? '';

    // Se manca qualche componente, restituisci vuoto
    if (basePath.isEmpty || pdfRelativePath.isEmpty || volume.isEmpty) {
      return '';
    }

    // Normalizza il percorso base
    String normalizedBase = basePath.replaceAll('/', '\\');
    if (!normalizedBase.endsWith('\\')) {
      normalizedBase += '\\';
    }

    // Normalizza il percorso relativo
    String normalizedRelative = pdfRelativePath.replaceAll('/', '\\');
    if (normalizedRelative.startsWith('\\')) {
      normalizedRelative = normalizedRelative.substring(1);
    }
    if (!normalizedRelative.endsWith('\\')) {
      normalizedRelative += '\\';
    }

    // Costruisci il percorso completo: base + relativo + volume
    String fullPath = '$normalizedBase$normalizedRelative$volume';

    // Rimuovi doppi separatori
    fullPath = fullPath.replaceAll('\\\\', '\\');

    return fullPath;
  }

  Future<void> _openPdf(Map<String, dynamic> spartito) async {
    try {
      final pdfRelativePath = spartito['PercResto']?.toString() ?? '';
      if (pdfRelativePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Percorso PDF non specificato')),
        );
        return;
      }

      final fullPath = _buildPdfPath(spartito);
      final file = File(fullPath);
      final exists = await file.exists();

      if (!exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File non trovato: $fullPath'),
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // Apri il PDF alla pagina specifica se indicata
      final numPag = spartito['NumPag']?.toString();
      await _launchPdf(fullPath, numPag);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore apertura PDF: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _launchPdf(String filePath, String? pageNumber) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File non trovato: $filePath');
      }

      // Se non c'è numero pagina, apri normalmente
      if (pageNumber == null || pageNumber.isEmpty) {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ PDF aperto'),
              backgroundColor: Colors.green,
            ),
          );
          return;
        }
      }

      // STRATEGIA 1: Adobe Acrobat Reader (più comune)
      if (Platform.isWindows) {
        final acrobatPaths = [
          r'C:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe',
          r'C:\Program Files\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe',
          r'C:\Program Files (x86)\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe',
          r'C:\Program Files\Adobe\Acrobat 9.0\Acrobat\Acrobat.exe',
        ];

        for (final path in acrobatPaths) {
          try {
            final acrobatFile = File(path);
            if (await acrobatFile.exists()) {
              await Process.run(path, ['/A', 'page=$pageNumber', filePath]);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ PDF aperto con Adobe Reader alla pagina $pageNumber'),
                  backgroundColor: Colors.green,
                ),
              );
              return;
            }
          } catch (e) {
            print('Adobe Reader non disponibile: $e');
          }
        }
      }

      // STRATEGIA 2: Usa il percorso dal config globale (se disponibile)
      if (Platform.isWindows && app_main.appSystemConfig['pdfViewerPath'] != null) {
        try {
          final viewerPath = app_main.appSystemConfig['pdfViewerPath']!;
          final viewerFile = File(viewerPath);
          if (await viewerFile.exists()) {
            await Process.run(viewerPath, ['/A', 'page=$pageNumber', filePath]);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ PDF aperto con visualizzatore configurato alla pagina $pageNumber'),
                backgroundColor: Colors.green,
              ),
            );
            return;
          }
        } catch (e) {
          print('Visualizzatore configurato non disponibile: $e');
        }
      }

      // STRATEGIA 3: Prova con il visualizzatore predefinito di sistema
      final uri = Uri.file(filePath);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📄 PDF aperto con visualizzatore predefinito'),
                if (pageNumber != null && pageNumber.isNotEmpty)
                  Text(
                    '📍 Vai manualmente alla pagina: $pageNumber',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // STRATEGIA 4: Fallback per Windows
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', '"$filePath"']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📄 PDF aperto'),
                if (pageNumber != null && pageNumber.isNotEmpty)
                  Text(
                    '📍 Vai manualmente alla pagina: $pageNumber',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Impossibile aprire il file');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Errore apertura PDF: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ricerca Spartiti'),
        backgroundColor: Colors.blueGrey[700],
        actions: [
          if (_searchResults.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: Column(
        children: [
          // BARRA RICERCA
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Cerca spartiti...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (value) {
                if (value.length >= 2) {
                  _performSearch(value);
                } else if (value.isEmpty) {
                  _clearSearch();
                }
              },
            ),
          ),

          // FILTRI
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.filter_list),
                      const SizedBox(width: 8),
                      const Text('Filtri:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const Spacer(),
                      TextButton(onPressed: _resetFilters, child: const Text('Reset')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _strumentoController,
                          decoration: const InputDecoration(
                            labelText: 'Strumento',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _volumeController,
                          decoration: const InputDecoration(
                            labelText: 'Volume',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _provenienzaController,
                          decoration: const InputDecoration(
                            labelText: 'Provenienza',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      // FILTRO TIPOMULTI
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _tipoMultiController,
                          decoration: const InputDecoration(
                            labelText: 'TipoMulti',
                            hintText: 'es. B, PDF',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ERRORI
          if (_searchError.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[50],
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_searchError)),
                ],
              ),
            ),

          // INFO
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.blueGrey[50],
            child: Row(
              children: [
                const Text('Risultati:'),
                const SizedBox(width: 8),
                Text(_searchResults.length.toString()),
                const Spacer(),
                const Text('Ordinato per: Titolo → Strumento'),
              ],
            ),
          ),

          // RISULTATI
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) return const Center(child: CircularProgressIndicator());

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Inizia a digitare per cercare spartiti'),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Nessun risultato per "${_searchController.text}"'),
          ],
        ),
      );
    }

    // Raggruppa per titolo
    Map<String, List<Map<String, dynamic>>> groups = {};
    for (var spartito in _searchResults) {
      String titolo = spartito['titolo']?.toString() ?? 'Senza titolo';
      if (!groups.containsKey(titolo)) groups[titolo] = [];
      groups[titolo]!.add(spartito);
    }

    List<String> sortedTitles = groups.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedTitles.length,
      itemBuilder: (context, index) {
        String titolo = sortedTitles[index];
        List<Map<String, dynamic>> items = groups[titolo]!;
        items.sort((a, b) {
          String aStr = a['strumento']?.toString() ?? '';
          String bStr = b['strumento']?.toString() ?? '';
          return aStr.compareTo(bStr);
        });

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.library_music, color: Colors.blue),
            title: Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${items.length} versione${items.length > 1 ? 'i' : ''}'),
            children: items.map((spartito) => _buildItem(spartito)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildItem(Map<String, dynamic> spartito) {
    bool hasPdf = (app_main.gPercorsoPdf.isNotEmpty &&
        spartito['PercResto']?.toString().isNotEmpty == true &&
        spartito['volume']?.toString().isNotEmpty == true);

    String fullPath = hasPdf ? _buildPdfPath(spartito) : '';
    String numPag = spartito['NumPag']?.toString() ?? '';
    String tipoDoc = spartito['TipoDocumento']?.toString() ?? '';

    return ListTile(
      leading: Icon(_getIcon(spartito['strumento']?.toString() ?? ''), color: Colors.green),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PRIMA RIGA: Strumento + Numero pagina + Percorso (BOX SCROLLABILE)
          Row(
            children: [
              // Strumento (verde)
              Text(
                spartito['strumento']?.toString() ?? 'Senza strumento',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),

              // Numero pagina (box blu) - solo se presente
              if (numPag.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Text(
                    'Pag. $numPag',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // PERCORSO IN BOX SCROLLABILE E SELEZIONABILE
              Container(
                width: 250,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: hasPdf ? Colors.grey[300]! : Colors.orange[300]!),
                  borderRadius: BorderRadius.circular(4),
                  color: hasPdf ? Colors.grey[50] : Colors.orange[50],
                ),
                child: hasPdf && fullPath.isNotEmpty
                    ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SelectableText(
                      fullPath,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontFamily: 'Monospace',
                      ),
                    ),
                  ),
                )
                    : const Center(
                  child: Text(
                    'Percorso incompleto',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // SECONDA RIGA: Volume + Archivio + Autore + TipoDoc
          Wrap(
            spacing: 8,
            children: [
              if (spartito['volume']?.toString().isNotEmpty ?? false)
                Text(
                  'Vol: ${spartito['volume']}',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (spartito['ArchivioProvenienza']?.toString().isNotEmpty ?? false)
                Text(
                  'Arch: ${spartito['ArchivioProvenienza']}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (spartito['autore']?.toString().isNotEmpty ?? false)
                Text(
                  'Aut: ${spartito['autore']}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              if (tipoDoc.isNotEmpty)
                Text(
                  'Doc: $tipoDoc',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          hasPdf ? Icons.open_in_new : Icons.warning,
          color: hasPdf ? Colors.green : Colors.orange,
        ),
        onPressed: hasPdf ? () => _openPdf(spartito) : null,
        tooltip: hasPdf ? 'Apri PDF: $fullPath' : 'PDF non disponibile',
      ),
    );
  }

  String _shortenPath(String path) {
    if (path.length <= 60) return path;
    return '...${path.substring(path.length - 60)}';
  }

  IconData _getIcon(String strumento) {
    String lower = strumento.toLowerCase();
    if (lower.contains('piano')) return Icons.piano;
    if (lower.contains('chitar')) return Icons.audiotrack;
    if (lower.contains('violin')) return Icons.music_note;
    if (lower.contains('flauto')) return Icons.record_voice_over;
    if (lower.contains('tromba')) return Icons.volume_up;
    if (lower.contains('batteria')) return Icons.surround_sound;
    if (lower.contains('voce') || lower.contains('canto')) return Icons.mic;
    return Icons.library_music;
  }
}