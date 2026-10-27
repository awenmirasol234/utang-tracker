import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:utang_tracker/features/backup/data/services/google_drive_client.dart';

void main() {
  test('cancelled sign-in keeps its own message', () {
    final error = mapGoogleSignInException(
      const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
    );

    expect(error.message, 'Google sign-in was cancelled.');
  });

  test('other sign-in failures share one message', () {
    final error = mapGoogleSignInException(
      const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError),
    );

    expect(
      error.message,
      'Google sign-in failed. Check your Google account and try again.',
    );
  });
}
