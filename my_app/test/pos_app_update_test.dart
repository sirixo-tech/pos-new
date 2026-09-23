import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/models/pos_app_update.dart';

void main() {
  test('compareAppVersions uses semver then build', () {
    expect(compareAppVersions('3.1.9', '3.1.10'), lessThan(0));
    expect(compareAppVersions('3.1.9', '3.1.9', currentBuild: 2002, candidateBuild: 2003), lessThan(0));
    expect(compareAppVersions('3.1.9', '3.1.9', currentBuild: 2002, candidateBuild: 2002), 0);
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
