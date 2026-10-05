import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/menu_import_file_types.dart';

void main() {
  test('accepts CSV when capabilities return file extensions', () {
    expect(acceptsMenuImportFile('MENU.CSV',
      ['csv', 'xlsx', 'jpeg', 'jpg', 'png', 'webp', 'gif', 'pdf']), isTrue);
  });
  test('accepts MIME types, normalized extensions, and JPEG aliases', () {
    expect(acceptsMenuImportFile('menu.csv', ['text/csv']), isTrue);
    expect(acceptsMenuImportFile('menu.csv', [' .CSV ']), isTrue);
    expect(acceptsMenuImportFile('menu.jpg', ['jpeg']), isTrue);
    expect(acceptsMenuImportFile('menu.gif', ['image/gif']), isTrue);
  });
  test('rejects unlisted types and allows unspecified capabilities', () {
    expect(acceptsMenuImportFile('menu.exe', ['csv', 'application/pdf']), isFalse);
    expect(acceptsMenuImportFile('menu.csv', []), isTrue);
  });
}
