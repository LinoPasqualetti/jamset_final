import 'package:flutter/widgets.dart';

abstract class OpenerPlatformInterface {
  static late OpenerPlatformInterface instance;

  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  });
}