enum BackupInterval {
  daily('Daily'),
  weekly('Weekly'),
  manual('Manual only');

  const BackupInterval(this.label);

  final String label;
}
