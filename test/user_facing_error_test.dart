import 'package:flutter_test/flutter_test.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/utils/user_facing_error.dart';

void main() {
  test('preserves application error messages', () {
    expect(
      userFacingError(const ValidationException('Name is required.')),
      'Name is required.',
    );
  });

  test('hides unexpected exception details', () {
    expect(
      userFacingError(StateError('database details')),
      'Something went wrong. Please try again.',
    );
  });
}
