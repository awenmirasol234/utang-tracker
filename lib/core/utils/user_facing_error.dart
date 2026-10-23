import 'package:utang_tracker/core/error/app_exception.dart';

String userFacingError(Object error) {
  if (error is AppException) return error.message;
  return 'Something went wrong. Please try again.';
}
