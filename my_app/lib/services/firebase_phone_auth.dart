import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../utils/platform_info.dart';
import 'pos_api.dart';

/// Sends the SMS through Firebase Auth and returns an ID token for verify.
class PosFirebasePhoneAuth {
  int? forceResendingToken;
  String? _verificationId;
  ConfirmationResult? _webConfirmation;

  Future<void> sendCode({
    required FirebasePublicConfig config,
    required String phone,
    required bool resend,
  }) async {
    if (!posCanUseFirebasePhoneAuth) {
      throw PosApiException(
        'This app version cannot send Firebase SMS codes. Use email instead.',
      );
    }
    await _ensureApp(config);
    if (!resend) {
      forceResendingToken = null;
      _verificationId = null;
      _webConfirmation = null;
    }

    if (kIsWeb) {
      try {
        _webConfirmation = await FirebaseAuth.instance.signInWithPhoneNumber(
          phone,
        );
        _verificationId = _webConfirmation!.verificationId;
      } on FirebaseAuthException catch (error) {
        throw PosApiException(
          error.message ?? 'Could not send the verification code.',
        );
      }
      return;
    }

    final completer = Completer<void>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      forceResendingToken: resend ? forceResendingToken : null,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (_) {},
      verificationFailed: (error) {
        if (completer.isCompleted) return;
        completer.completeError(
          PosApiException(
            error.message ?? 'Could not send the verification code.',
          ),
        );
      },
      codeSent: (verificationId, token) {
        _verificationId = verificationId;
        forceResendingToken = token;
        if (!completer.isCompleted) completer.complete();
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId ??= verificationId;
      },
    );
    await completer.future;
  }

  Future<String> idTokenForCode(String smsCode) async {
    if (kIsWeb) {
      final confirmation = _webConfirmation;
      if (confirmation == null) {
        throw PosApiException('Request a new code.');
      }
      try {
        final signedIn = await confirmation.confirm(smsCode);
        return _tokenFrom(signedIn);
      } on FirebaseAuthException catch (error) {
        throw PosApiException(
          error.message ?? 'That code is incorrect. Try again.',
        );
      }
    }

    final verificationId = _verificationId;
    if (verificationId == null || verificationId.isEmpty) {
      throw PosApiException('Request a new code.');
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final signedIn = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      return _tokenFrom(signedIn);
    } on FirebaseAuthException catch (error) {
      throw PosApiException(
        error.message ?? 'That code is incorrect. Try again.',
      );
    }
  }

  Future<String> _tokenFrom(UserCredential signedIn) async {
    final token = await signedIn.user?.getIdToken();
    if (token == null || token.isEmpty) {
      throw PosApiException('Phone verification did not return a token.');
    }
    return token;
  }

  Future<FirebaseApp> _ensureApp(FirebasePublicConfig config) async {
    if (Firebase.apps.isNotEmpty) return Firebase.app();
    final appId = config.appIdFor(posPlatformLabel());
    if (config.apiKey.isEmpty || config.projectId.isEmpty || appId.isEmpty) {
      throw PosApiException(
        'Phone verification is not configured for this app.',
      );
    }
    return Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: config.apiKey,
        appId: appId,
        messagingSenderId: config.messagingSenderId,
        projectId: config.projectId,
        authDomain: config.authDomain,
      ),
    );
  }
}

final posFirebasePhoneAuth = PosFirebasePhoneAuth();
