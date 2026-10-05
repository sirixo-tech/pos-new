import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<String?> saveMenuExport(
  Uint8List bytes,
  String filename,
  String mime,
) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    await OpenFilex.open(file.path);
    return file.path;
  }
  final location = await getSaveLocation(suggestedName: filename);
  if (location == null) return null;
  await XFile.fromData(
    bytes,
    mimeType: mime,
    name: filename,
  ).saveTo(location.path);
  return location.path;
}
