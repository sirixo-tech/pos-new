import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/services/pos_api.dart';
import 'package:my_app/utils/menu_import_retry.dart';

void main() {
  test('temporary read failures retry with bounded delays', () {
    expect(
      menuImportRetryDelay(TimeoutException('slow'), 1),
      const Duration(seconds: 3),
    );
    expect(
      menuImportRetryDelay(http.ClientException('offline'), 2),
      const Duration(seconds: 6),
    );
    expect(
      menuImportRetryDelay(PosApiException('Busy', statusCode: 503), 99),
      const Duration(seconds: 24),
    );
  });
  test(
    'rate limits respect server delay and permission failures do not loop',
    () {
      expect(
        menuImportRetryDelay(
          PosApiException(
            'Wait',
            statusCode: 429,
            retryAfter: const Duration(seconds: 90),
          ),
          1,
        ),
        const Duration(seconds: 90),
      );
      for (final code in [401, 403, 404, 422]) {
        expect(
          menuImportRetryDelay(PosApiException('Denied', statusCode: code), 1),
          isNull,
        );
      }
    },
  );
}
