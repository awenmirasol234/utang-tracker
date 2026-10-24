import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';

/// Call after any business write (from UI code) so watching providers rebuild.
void notifyBusinessDataChanged(WidgetRef ref) {
  ref.read(dataVersionProvider.notifier).bump();
}

/// Same as [notifyBusinessDataChanged] but callable from provider code.
void notifyBusinessDataChangedFromRef(Ref ref) {
  ref.read(dataVersionProvider.notifier).bump();
}
