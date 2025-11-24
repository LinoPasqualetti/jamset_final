// Stub per piattaforme non supportate
import 'opener_platform_interface.dart';

class StubOpener implements OpenerPlatformInterface {
  @override
  Future<void> openPdf({
    required String filePath,
    required int page,
    BuildContext? context,
  }) async {
    throw UnsupportedError('Platform not supported');
  }
}