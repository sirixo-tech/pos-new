import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_app/providers/pos_controller.dart';
import 'package:my_app/screens/login_screen.dart';
import 'package:my_app/services/pos_api.dart';
import 'package:my_app/utils/phone_e164.dart';
import 'package:my_app/utils/platform_info.dart';
import 'package:provider/provider.dart';

void main() {
  test('auth options hide signup methods the server turned off', () {
    final both = AuthOptions.fromJson({
      'login_method': 'both',
      'registration_enabled': true,
      'phone_default_country': 'in',
    });
    expect(both.phoneSignUp, isTrue);
    expect(both.emailSignUp, isTrue);
    expect(both.phoneDefaultCountry, 'IN');

    final phone = AuthOptions.fromJson({
      'login_method': 'phone',
      'registration_enabled': false,
      'phone_default_country': 'AE',
    });
    expect(phone.phoneSignIn, isTrue);
    expect(phone.emailSignUp, isFalse);
    expect(phone.phoneSignUp, isTrue);
    expect(phone.registrationEnabled, isFalse);

    final email = AuthOptions.fromJson({
      'login_method': 'email',
      'registration_enabled': true,
      'phone_default_country': 'IN',
    });
    expect(email.phoneSignIn, isFalse);
    expect(email.emailSignUp, isTrue);
    expect(email.phoneSignUp, isFalse);
  });

  test('blank native Firebase app ids fall back to the web app id', () {
    final config = FirebasePublicConfig.fromJson({
      'apiKey': 'key',
      'projectId': 'demo',
      'appId': '1:123:web:abc',
      'messagingSenderId': '123',
      'nativeAppIds': {
        'pos': {'android': '1:123:android:pos', 'ios': ''},
      },
    });
    expect(config.appIdFor('android'), '1:123:android:pos');
    expect(config.appIdFor('ios'), '1:123:web:abc');
    expect(config.appIdFor('web'), '1:123:web:abc');
  });

  test('phone numbers are sent as E.164', () {
    expect(toE164('IN', '98765 43210'), '+919876543210');
    expect(toE164('IN', '+919876543210'), '+919876543210');
    expect(toE164('IN', '09876543210'), '+919876543210');
    expect(toE164('IN', '123'), isNull);
  });

  testWidgets('login screen matches the email and phone welcome layout', (
    tester,
  ) async {
    final api = PosApi(
      client: MockClient((request) async {
        return http.Response(
          '{"data":{"login_method":"both","registration_enabled":true,"phone_default_country":"IN"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final pos = PosController(api: api);
    addTearDown(pos.dispose);
    pos.serverUrl = 'https://app.selfx.in';

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: pos,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to your restaurant dashboard.'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Email address'), findsWidgets);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Keep me signed in on this device'), findsOneWidget);
    expect(find.text('Create my restaurant  →'), findsOneWidget);
    expect(find.text('MAKE YOUR BUSINESS STANDOUT'), findsOneWidget);
    expect(find.text('Secure, encrypted connection'), findsOneWidget);
    expect(find.textContaining('LinearGradient'), findsNothing);

    await tester.tap(find.text('Mobile number'));
    await tester.pumpAndSettle();
    expect(find.text('Send code  →'), findsOneWidget);

    await tester.tap(find.text('Create my restaurant  →'));
    await tester.pumpAndSettle();
    expect(find.text('Create your restaurant'), findsOneWidget);
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Restaurant name'), findsOneWidget);
  });

  testWidgets('firebase SMS refusal is shown in full on a phone', (tester) async {
    const message =
        'This server sends SMS codes with Firebase, which this app version does not support. Update the app or use email instead.';
    Map<String, dynamic>? sentBody;
    final api = PosApi(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/phone/send')) {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"message":"$message","errors":{"phone":["$message"]}}',
            422,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{"data":{"login_method":"both","registration_enabled":true,"phone_default_country":"IN"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final pos = PosController(api: api);
    addTearDown(pos.dispose);
    pos.serverUrl = 'https://app.selfx.in';

    tester.view.physicalSize = const Size(360, 748);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: pos,
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mobile number'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '9392353177');
    await tester.tap(find.text('Send code  →'));
    await tester.pumpAndSettle();

    expect(find.text(message), findsOneWidget);
    expect(sentBody?['supports_firebase'], posCanUseFirebasePhoneAuth);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Use email instead'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address'), findsOneWidget);
    expect(find.text(message), findsNothing);
  });
}
