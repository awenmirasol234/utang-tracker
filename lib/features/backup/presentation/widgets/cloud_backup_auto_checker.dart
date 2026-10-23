import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/features/backup/presentation/providers/cloud_backup_providers.dart';

class CloudBackupAutoChecker extends ConsumerStatefulWidget {
  const CloudBackupAutoChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CloudBackupAutoChecker> createState() =>
      _CloudBackupAutoCheckerState();
}

class _CloudBackupAutoCheckerState extends ConsumerState<CloudBackupAutoChecker>
    with WidgetsBindingObserver {
  bool _paused = false;
  bool _checking = false;
  bool _sessionEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual<CloudBackupState>(cloudBackupNotifierProvider, (
      previous,
      next,
    ) {
      if (!next.status.isSignedIn) {
        _sessionEnabled = false;
        return;
      }
      final wasSignedIn = previous?.status.isSignedIn ?? false;
      if (wasSignedIn) return;
      _sessionEnabled = true;
      _check();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_paused) {
        _paused = false;
        _check();
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _paused = true;
    }
  }

  Future<void> _check() async {
    if (!mounted || !_sessionEnabled || _checking) return;
    _checking = true;
    try {
      await ref.read(cloudBackupNotifierProvider.notifier).backupIfDue();
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
