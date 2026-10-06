import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/l10n/app_localizations_en.dart';
import 'package:my_app/services/offline/connectivity_service.dart';
import 'package:my_app/widgets/day_end_reports_sheet.dart';

void main() {
  test('day-end reports omit staff and voids', () {
    final values = dayEndReportTypes(
      AppLocalizationsEn(),
    ).map((type) => type.value);
    expect(values, containsAll(['summary', 'item', 'category', 'tax']));
    expect(values, isNot(contains('staff')));
    expect(values, isNot(contains('voids')));
  });

  test('screen-off does not mark an online register offline', () async {
    var reachable = true;
    final service = ConnectivityService(
      serverUrl: 'https://example.test',
      probe: (_) async => reachable,
    );

    expect(await service.checkConnectivity(), isTrue);
    expect(service.isOnline, isTrue);

    service.noteAppBackgrounded(true);
    reachable = false;
    expect(await service.checkConnectivity(), isFalse);
    expect(service.isOnline, isTrue);

    service.noteAppBackgrounded(false);
    expect(await service.checkConnectivity(), isFalse);
    expect(service.isOnline, isTrue);
    expect(await service.checkConnectivity(), isFalse);
    expect(service.isOffline, isTrue);

    reachable = true;
    expect(await service.checkConnectivity(), isTrue);
    expect(service.isOnline, isTrue);
    service.dispose();
  });
}
