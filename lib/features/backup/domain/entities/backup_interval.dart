enum BackupInterval {
  everySixHours('Every 6 hours', Duration(hours: 6)),
  daily('Daily', Duration(hours: 24)),
  weekly('Weekly', Duration(days: 7)),
  manual('Manual only', null);

  const BackupInterval(this.label, this.window);

  final String label;

  /// Time that must pass after the last backup before an automatic backup
  /// may run. Null means this option never backs up automatically.
  final Duration? window;
}
