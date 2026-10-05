import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/models/pos_app_update.dart';

void main() {
  test('same installed release is equal across server version formats', () {
    for (final version in ['3.6', '3.6.0', '3.6.0+2028', '3.6.0.2028']) {
      final update =
          PosAppUpdate(
            status: 'required',
            currentVersion: '',
            latestVersion: version,
          ).resolvedAgainstInstalled(
            installedVersion: '3.6.0',
            installedBuild: 2028,
          );
      expect(update.isNone, isTrue, reason: version);
    }
  });

  test('newer embedded builds still offer an update', () {
    for (final version in ['3.6.0+2029', '3.6.0.2029']) {
      expect(
        compareAppVersions('3.6.0', version, currentBuild: 2028),
        lessThan(0),
      );
    }
    expect(
      compareAppVersions(
        '3.6.0',
        '3.4.0',
        currentBuild: 4028,
        candidateBuild: 9999,
      ),
      greaterThan(0),
    );
  });

  test('compareAppVersions uses semver then build', () {
    expect(compareAppVersions('3.1.9', '3.1.10'), lessThan(0));
    expect(
      compareAppVersions(
        '3.1.9',
        '3.1.9',
        currentBuild: 2002,
        candidateBuild: 2003,
      ),
      lessThan(0),
    );
    expect(
      compareAppVersions(
        '3.1.9',
        '3.1.9',
        currentBuild: 2002,
        candidateBuild: 2002,
      ),
      0,
    );
  });

  test('required flag for an already-installed version becomes none', () {
    final update = PosAppUpdate(
      status: 'required',
      currentVersion: '3.1.9',
      latestVersion: '3.1.9',
      latestBuild: 2002,
    ).resolvedAgainstInstalled(installedVersion: '3.1.9', installedBuild: 2002);
    expect(update.isNone, isTrue);
  });

  test('min_version below installed is required', () {
    final update = PosAppUpdate(
      status: 'optional',
      currentVersion: '1.0.0',
      latestVersion: '3.1.9',
      minVersion: '3.1.0',
    ).resolvedAgainstInstalled(installedVersion: '1.0.0', installedBuild: 1);
    expect(update.isRequired, isTrue);
  });
}
