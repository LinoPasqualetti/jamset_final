// lib/services/pdf_opener.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:jamset_new/main.dart' as app_main;
import 'dart:io' show Platform;
import 'package:path/path.dart' as path;

class PdfOpener {
  static Future<void> openPdf(String pdfRelativePath, {int? pageNumber}) async {
    try {
      // Costruisci il percorso completo
      final fullPath = _buildFullPdfPath(pdfRelativePath);

      if (await File(fullPath).exists()) {
        await _launchPdf(fullPath, pageNumber);
      } else {
        throw Exception('File non trovato: $fullPath');
      }
    } catch (e) {
      throw Exception('Errore apertura PDF: $e');
    }
  }

  static String _buildFullPdfPath(String relativePath) {
    final basePath = app_main.gPercorsoPdf;

    // Normalizza i separatori di percorso
    String normalizedPath = relativePath.replaceAll('\\', '/');

    // Se il percorso inizia con /, rimuovilo
    if (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }

    // Combina percorso base e relativo
    return path.join(basePath, normalizedPath);
  }

  static Future<void> _launchPdf(String filePath, int? pageNumber) async {
    final uri = Uri.file(filePath);

    if (Platform.isWindows) {
      // Su Windows, usa il programma predefinito
      await _launchUrl(uri);
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Su mobile, usa url_launcher
      await _launchUrl(uri);
    } else {
      // Altre piattaforme
      await _launchUrl(uri);
    }
  }

  static Future<void> _launchUrl(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('Impossibile aprire il file: $uri');
    }
  }

  static Future<bool> checkPdfExists(String pdfRelativePath) async {
    try {
      final fullPath = _buildFullPdfPath(pdfRelativePath);
      return await File(fullPath).exists();
    } catch (e) {
      return false;
    }
  }
}

