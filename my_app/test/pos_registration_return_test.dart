import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/utils/pos_registration_return.dart';

void main() {
  test('mobile registration supplies the app return address', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final url = posRegistrationUrl(
        'https://app.selfx.in',
        platform: platform,
      );
      expect(url.path, '/register');
      expect(
        url.queryParameters['return_to'],
        'selfxpos://registration-complete',
      );
    }
  });

  test('web registration returns to the original deployment', () {
    final url = posRegistrationUrl(
      'https://app.selfx.in',
      webLocation: Uri.parse('https://pos.example.com/shop/?mode=pos#/'),
    );
    expect(
      url.queryParameters['return_to'],
      'https://pos.example.com/shop/?mode=pos',
    );
  });

  test('desktop registration does not advertise an unregistered scheme', () {
    final url = posRegistrationUrl(
      'https://app.selfx.in',
      platform: TargetPlatform.windows,
    );
    expect(url.queryParameters.containsKey('return_to'), isFalse);
  });

  test('only the registration callback is recognized', () {
    expect(
      isPosRegistrationReturn(Uri.parse('selfxpos://registration-complete')),
      isTrue,
    );
    for (final link in [
      'https://registration-complete',
      'selfxpos://another-route',
      'selfxpos://registration-complete/unexpected',
      'selfxpos://user@registration-complete',
    ]) {
      expect(isPosRegistrationReturn(Uri.parse(link)), isFalse);
    }
  });
}
