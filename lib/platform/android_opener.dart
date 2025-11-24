import 'package:flutter/material.dart';
import '../main.dart';
import 'opener_platform_interface.dart';
import '../screens/pdf_viewer_android_screen.dart';

class AndroidOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    final navigatorState = navigatorKey.currentState;
    if (navigatorState != null) {
      navigatorState.push(
        MaterialPageRoute(
          builder: (context) => PdfViewerAndroidScreen(
            filePath: filePath,
            initialPage: page,
          ),
        ),
      );
    }
  }
}