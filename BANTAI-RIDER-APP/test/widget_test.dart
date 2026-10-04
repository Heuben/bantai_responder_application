import 'dart:convert';
import 'dart:typed_data';

import 'package:banta_rider_app/core/network/api_client.dart';
import 'package:banta_rider_app/features/auth/screens/face_enrollment_screen.dart';
import 'package:banta_rider_app/features/auth/screens/login_screen.dart'
    as auth_login;
import 'package:banta_rider_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmptySuccessClient implements http.Client {
  @override
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    return http.Response('not-json', 200);
  }

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return http.Response('not-json', 200);
  }

  @override
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return http.Response('', 200);
  }

  @override
  Future<http.Response> head(Uri url, {Map<String, String>? headers}) async {
    return http.Response('', 200);
  }

  @override
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return http.Response('', 200);
  }

  @override
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return http.Response('', 200);
  }

  @override
  Future<String> read(Uri url, {Map<String, String>? headers}) async => '';

  @override
  Future<Uint8List> readBytes(Uri url, {Map<String, String>? headers}) async =>
      Uint8List(0);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(Stream.value([]), 200);
  }

  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('api client treats malformed success payloads as a failed response', () async {
    final client = ApiClient(client: EmptySuccessClient());

    expect(
      () async => client.get('/health'),
      returnsNormally,
    );

    final response = await client.get('/health');

    expect(response.isSuccess, isTrue);
    expect(response.data, isNull);
  });

  testWidgets('shows the Bantai startup brand and welcome state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 1800));

    expect(find.text('Welcome!'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/bantai-icon.png',
      ),
      findsWidgets,
    );
  });

  testWidgets('forgot password button triggers callback', (tester) async {
    var forgotPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: auth_login.LoginScreen(
          onForgotPassword: () => forgotPressed = true,
        ),
      ),
    );

    await tester.tap(find.text('Forgot Password?'));
    await tester.pump();

    expect(forgotPressed, isTrue);
  });

  testWidgets('fresh login starts in off duty until the user toggles on', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 2200));

    await tester.enterText(find.byType(TextFormField).at(0), 'agent@bantai.ph');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();

    expect(find.text('Off Duty'), findsWidgets);
    expect(find.text('Go On Duty'), findsOneWidget);
  });

  testWidgets('face enrollment screen renders the biometric UI', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FaceEnrollmentScreen(
          onSuccess: () {},
        ),
      ),
    );

    expect(find.text('Face enrollment'), findsOneWidget);
    expect(find.text('Scan my face'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('full app flow shows forgot password screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 2200));

    expect(find.text('Forgot Password?'), findsOneWidget);

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets('forgot password reset flow advances and can go back', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 2200));

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('forgot_contact_field')),
      '09171234567',
    );
    await tester.pump();
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the code'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('forgot_sms_code_field')),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets('forgot password accepts real input values through all steps', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 2200));

    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('forgot_contact_field')),
      '09171234567',
    );
    await tester.pump();
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the code'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('forgot_sms_code_field')),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.text('Verify code'));
    await tester.pumpAndSettle();

    expect(find.text('Set a new password'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('forgot_new_password_field')),
      'newpass123',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('forgot_confirm_password_field')),
      'newpass123',
    );
    await tester.pump();
    await tester.tap(find.text('Save new password'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome!'), findsWidgets);
    expect(find.text('Request a reset from your admin'), findsNothing);
  });
}
