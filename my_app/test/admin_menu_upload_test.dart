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
  XFile image() => XFile.fromData(
    Uint8List.fromList([1, 2, 3]),
    name: 'menu.jpg',
    path: 'menu.jpg',
  );

  test('image uploads encode slot and modifier IDs as form arrays', () async {
    final api = PosApi(
      client: MockClient((request) async {
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(request.body, contains('name="time_slot_ids[0]"\r\n\r\n2'));
        expect(request.body, contains('name="time_slot_ids[1]"\r\n\r\n4'));
        expect(request.body, contains('name="modifier_ids[0]"\r\n\r\n9'));
        expect(request.body, isNot(contains('name="time_slot_ids"')));
        expect(request.body, isNot(contains('name="modifier_ids"')));
        expect(request.body, contains('name="image"; filename="menu.jpg"'));
        expect(request.headers['Authorization'], 'Bearer test-token');
        return http.Response('{"data":{"id":12}}', 200);
      }),
    );
    await api.createAdminMenuItem(
      session,
      body: {
        'name': 'Dosa',
        'price': 100,
        'time_slot_ids': [2, 4],
        'modifier_ids': [9],
      },
      imageFile: image(),
    );
  });

  for (final category in [false, true]) {
    test(
      'new ${category ? 'category' : 'item'} omits empty form arrays',
      () async {
        var count = 0;
        final api = PosApi(
          client: MockClient((request) async {
            count++;
            expect(request.method, 'POST');
            expect(request.body, isNot(contains('name="time_slot_ids')));
            expect(request.body, isNot(contains('name="modifier_ids')));
            return http.Response('{"data":{"id":12}}', 200);
          }),
        );
        final body = <String, dynamic>{
          'name': 'Dosa',
          'time_slot_ids': <int>[],
          if (!category) 'modifier_ids': <int>[],
        };
        if (category) {
          await api.createAdminMenuCategory(
            session,
            body: body,
            imageFile: image(),
          );
        } else {
          await api.createAdminMenuItem(
            session,
            body: body,
            imageFile: image(),
          );
        }
        expect(count, 1);
      },
    );

    test(
      'existing ${category ? 'category' : 'item'} clears arrays via JSON',
      () async {
        var count = 0;
        final body = <String, dynamic>{
          'name': 'Dosa',
          'time_slot_ids': <int>[],
          if (!category) 'modifier_ids': <int>[],
        };
        final api = PosApi(
          client: MockClient((request) async {
            count++;
            expect(request.method, 'PATCH');
            expect(
              request.url.path,
              '/api/v1/pos/admin/${category ? 'menu-categories' : 'menu-items'}/12',
            );
            if (count == 1) {
              expect(
                request.headers['content-type'],
                contains('application/json'),
              );
              expect(jsonDecode(request.body), body);
            } else {
              expect(
                request.headers['content-type'],
                contains('multipart/form-data'),
              );
              expect(request.body, isNot(contains('name="time_slot_ids')));
              expect(request.body, isNot(contains('name="modifier_ids')));
              expect(request.body, contains('name="image"'));
            }
            return http.Response('{"data":{"id":12}}', 200);
          }),
        );
        if (category) {
          await api.updateAdminMenuCategory(
            session,
            id: 12,
            body: body,
            imageFile: image(),
          );
        } else {
          await api.updateAdminMenuItem(
            session,
            id: 12,
            body: body,
            imageFile: image(),
          );
        }
        expect(count, 2);
      },
    );
  }

  test('failed JSON update stops the image upload', () async {
    var count = 0;
    final api = PosApi(
      client: MockClient((request) async {
        count++;
        return http.Response('{"message":"Permission denied"}', 403);
      }),
    );
    await expectLater(
      api.updateAdminMenuItem(
        session,
        id: 12,
        body: {'time_slot_ids': <int>[]},
        imageFile: image(),
      ),
      throwsA(isA<PosApiException>()),
    );
    expect(count, 1);
  });

  test(
    'saving without an image preserves JSON arrays in one request',
    () async {
      var count = 0;
      final api = PosApi(
        client: MockClient((request) async {
          count++;
          expect(jsonDecode(request.body)['time_slot_ids'], <int>[]);
          expect(jsonDecode(request.body)['modifier_ids'], [9]);
          return http.Response('{"data":{"id":12}}', 200);
        }),
      );
      await api.updateAdminMenuItem(
        session,
        id: 12,
        body: {
          'time_slot_ids': <int>[],
          'modifier_ids': [9],
        },
      );
      expect(count, 1);
    },
  );
}
