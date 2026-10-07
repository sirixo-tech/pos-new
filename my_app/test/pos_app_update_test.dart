import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

import 'package:my_app/models/pos_app_update.dart';

void main() {
  test('universal feed labels do not reject a device-specific package', () {
    for (final label in ['all', 'ANY', ' universal ', 'multi-platform', '']) {
      expect(normalizeUpdatePlatform(label), isNull);
    }
    expect(normalizeUpdatePlatform(' Android '), 'android');
    expect(normalizeUpdatePlatform('APK'), 'android');
    expect(normalizeUpdatePlatform('win64'), 'windows');
    expect(normalizeUpdatePlatform('windows'), 'windows');
    expect(normalizeUpdatePlatform('android-arm64'), 'android-arm64');
  });

  test('nested packages select Android metadata without Windows checksum', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final container in ['platforms', 'packages']) {
      final update = PosAppUpdate.fromJson({
        'latest_version': '3.7.0',
        'platform': 'windows',
        container: {
          'android': {
            'download_url': 'https://example.com/app.apk',
            'sha256': 'a' * 64,
          },
          'windows': {
            'download_url': 'https://example.com/app.exe',
            'sha256': 'b' * 64,
          },
        },
      });
      expect(update.platform, 'android');
      expect(update.downloadUrl, 'https://example.com/app.apk');
      expect(update.sha256, 'a' * 64);
    }
  });
  test('API envelope platform does not override the update package', () {
    final merged = mergedPosAppUpdateJson({
      'platform': 'windows',
      'download_url': 'https://example.com/windows.exe',
      'latest_version': '3.6.13',
      'app_update': {
        'status': 'optional',
        'download_url': 'https://example.com/android.apk',
      },
    });
    final update = PosAppUpdate.fromJson(merged);
    expect(update.platform, isNull);
    expect(update.downloadUrl, 'https://example.com/android.apk');
    expect(update.latestVersion, '3.6.13');
  });

  test('release manifest selects the Android package', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final update = PosAppUpdate.fromJson({
      'latest_version': '3.6.15',
      'android': {'download_url': 'https://example.com/android.apk'},
      'windows': {'download_url': 'https://example.com/windows.exe'},
    });
    expect(update.platform, 'android');
    expect(update.downloadUrl, 'https://example.com/android.apk');
  });

  test('installed release clears stale update flags and older releases', () {
    for (final latest in ['3.6.13', '3.6.14']) {
      final update =
          PosAppUpdate(
            status: 'required',
            currentVersion: '3.6.0',
            latestVersion: latest,
            latestBuild: 4029,
          ).resolvedAgainstInstalled(
            installedVersion: '3.6.14',
            installedBuild: 4029,
          );
      expect(update.isNone, isTrue);
      expect(update.currentVersion, '3.6.14');
    }
  });
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
