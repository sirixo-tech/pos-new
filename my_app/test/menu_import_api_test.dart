import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/models/pos_models.dart';
import 'package:my_app/services/pos_api.dart';

void main() {
  final session = PosSession(
    serverUrl: 'https://example.test',
    token: 'test-token',
    restaurantId: 7,
    branchId: 3,
  );

  test('requests an admin token and keeps the POS session unchanged', () async {
    final api = PosApi(
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/auth/scoped-token') {
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(jsonDecode(request.body)['token_ability'], 'admin');
          return http.Response('{"data":{"token":"admin-test-token"}}', 200);
        }
        expect(request.url.path, '/api/v1/admin/menu-import/capabilities');
        expect(request.headers['Authorization'], 'Bearer admin-test-token');
        expect(request.headers['X-Restaurant-Id'], '7');
        expect(request.headers['X-Branch-Id'], '3');
        return http.Response('{"data":{"capabilities":{}}}', 200);
      }),
    );
    final admin = await api.createMenuImportSession(session);
    await api.menuImportGet(admin);
    expect(session.token, 'test-token');
    expect(admin.restaurantId, session.restaurantId);
    expect(admin.branchId, session.branchId);
  });

  test('admin token denial surfaces the backend permission error', () async {
    final api = PosApi(
      client: MockClient(
        (request) async =>
            http.Response('{"message":"Admin permission required"}', 403),
      ),
    );
    await expectLater(
      api.createMenuImportSession(session),
      throwsA(
        isA<PosApiException>().having((e) => e.statusCode, 'status', 403),
      ),
    );
  });

  test(
    'capabilities and status use admin API and tenant authentication',
    () async {
      final paths = <String>[];
      final api = PosApi(
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.headers['Authorization'], 'Bearer test-token');
          expect(request.headers['X-Restaurant-Id'], '7');
          expect(request.headers['X-Branch-Id'], '3');
          return http.Response('{"data":{"id":42}}', 200);
        }),
      );
      expect((await api.menuImportGet(session))['id'], 42);
      await api.menuImportGet(session, 42);
      expect(paths, [
        '/api/v1/admin/menu-import/capabilities',
        '/api/v1/admin/menu-import/42',
      ]);
    },
  );

  test(
    'draft preserves variant and deletion fields before confirmation',
    () async {
      final requests = <http.Request>[];
      final api = PosApi(
        client: MockClient((request) async {
          requests.add(request);
          return http.Response('{"data":{"import_id":42}}', 200);
        }),
      );
      final rows = [
        {'item_name': 'Soup', 'variant_name': 'Large', '_delete': true},
      ];
      await api.menuImportAction(session, 42, 'draft', rows: rows);
      await api.menuImportAction(session, 42, 'confirm');
      expect(requests.first.method, 'PUT');
      expect(jsonDecode(requests.first.body)['rows'], rows);
      expect(requests.last.url.path, '/api/v1/admin/menu-import/42/confirm');
      expect(requests.last.method, 'POST');
    },
  );

  test('menu file upload supplies multipart file type and AI flag', () async {
    final api = PosApi(
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/menu-import');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data; boundary='),
        );
        expect(request.body, contains('name="ai_assist"'));
        expect(request.body, contains('name="file"; filename="menu.pdf"'));
        expect(request.body, contains('content-type: application/pdf'));
        return http.Response('{"data":{"import_id":42}}', 200);
      }),
    );
    final result = await api.menuImportUpload(
      session,
      file: XFile.fromData(
        Uint8List.fromList([37, 80, 68, 70]),
        name: 'menu.pdf',
        path: 'menu.pdf',
      ),
    );
    expect(result['import_id'], 42);
  });

  test('error report supports CSV and surfaces server failures', () async {
    var fail = false;
    final api = PosApi(
      client: MockClient((request) async {
        expect(request.headers['Accept'], 'text/csv, application/json');
        return fail
            ? http.Response('{"message":"Forbidden"}', 403)
            : http.Response('row,error\n1,Invalid price', 200);
      }),
    );
    expect(await api.menuImportErrors(session, 42), contains('Invalid price'));
    fail = true;
    await expectLater(
      api.menuImportErrors(session, 42),
      throwsA(isA<PosApiException>()),
    );
  });
}
