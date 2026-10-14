import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:my_app/models/pos_app_update.dart';
import 'package:my_app/services/pos_update_installer.dart';
import 'package:my_app/widgets/pos_update_install_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const update = PosAppUpdate(
    status: 'optional',
    currentVersion: '4.9.0',
    latestVersion: '4.10.0',
    downloadUrl: 'https://example.com/selfx.apk',
  );

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('Android updater opens Play without requesting an APK', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    String? launchedUrl;
    messenger.setMockMethodCallHandler(channel, (call) async {
      launchedUrl = (call.arguments as Map)['url'] as String;
      return true;
    });
    var downloadRequests = 0;
    final client = MockClient((request) async {
      downloadRequests++;
      throw StateError('Android must not download an APK');
    });
    final result = await PosUpdateInstaller(client: client).install(update);
    expect(result.phase, PosUpdateInstallPhase.done);
    expect(downloadRequests, 0);
    expect(launchedUrl,
        'https://play.google.com/store/apps/details?id=in.selfx.pos');
    client.close();
  });

  test('Android updates do not require a backend installer URL', () {
    const noUrl = PosAppUpdate(
      status: 'required',
      currentVersion: '4.9.0',
      latestVersion: '4.10.0',
    );
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(canOpenPosAppUpdate(noUrl), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(canOpenPosAppUpdate(noUrl), isFalse);
    expect(canOpenPosAppUpdate(update), isTrue);
  });
}
