import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/features/updater/presentation/providers/update_providers.dart';
import 'package:utang_tracker/features/updater/presentation/widgets/update_bottom_sheet.dart';

/// Polls for updates while the app is in the foreground.
///
/// The cadence follows the persisted last-check timestamp: the app checks once
/// the previous check is older than [AppConstants.updateCheckInterval], and
/// keeps checking on that interval for as long as the app stays open. The
/// countdown survives backgrounding because it is derived from the stored
/// timestamp rather than from a running timer.
///
/// The first pass waits for [AppConstants.updateCheckStartupGrace] so the
/// update repository is never read while the app is still starting up.
///
/// Dismissing a version only suppresses the automatic prompt. A manual check
/// still offers the update.
class UpdateAutoChecker extends ConsumerStatefulWidget {
  const UpdateAutoChecker({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateAutoChecker> createState() => _UpdateAutoCheckerState();
}

class _UpdateAutoCheckerState extends ConsumerState<UpdateAutoChecker>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _paused = false;
  bool _passing = false;
  bool _checking = false;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arm(AppConstants.updateCheckStartupGrace);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // The startup 'resumed' is ignored: initState already scheduled the
      // first pass. A later resume re-evaluates whether a check is due.
      if (_paused) {
        _paused = false;
        _pass();
      }
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _paused = true;
      _timer?.cancel();
      _timer = null;
    }
  }

  void _arm(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, () => unawaited(_pass()));
  }

  /// Runs a check if one is due, then schedules the next pass.
  Future<void> _pass() async {
    if (!mounted || _passing) return;
    _passing = true;
    try {
      _timer?.cancel();

      final lastCheck = await ref
          .read(updateRepositoryProvider)
          .loadLastCheckTime();
      if (!mounted) return;

      final now = DateTime.now();
      // A missing timestamp means the app has never checked, so check now.
      final dueAt = lastCheck?.add(AppConstants.updateCheckInterval) ?? now;

      if (!dueAt.isAfter(now)) {
        await _checkAndPrompt();
        if (!mounted) return;
        // Arm the full interval rather than re-reading the timestamp: a failed
        // fetch does not store a new timestamp, so re-reading it would retry
        // immediately.
        _arm(AppConstants.updateCheckInterval);
        return;
      }
      _arm(dueAt.difference(now));
    } finally {
      _passing = false;
    }
  }

  Future<void> _checkAndPrompt() async {
    if (!mounted || _checking || _sheetOpen) return;
    _checking = true;
    try {
      await ref
          .read(updateNotifierProvider.notifier)
          .checkForUpdates(silent: true);
      if (!mounted) return;
      final state = ref.read(updateNotifierProvider);
      if (state is! UpdateAvailable && state is! UpdateDownloaded) return;

      _sheetOpen = true;
      try {
        await showUpdateBottomSheet(context);
      } finally {
        _sheetOpen = false;
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
