enum DebtStatus {
  unpaid('UNPAID'),
  partial('PARTIAL'),
  paid('PAID');

  const DebtStatus(this.value);

  final String value;

  static DebtStatus fromValue(String value) {
    return DebtStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => DebtStatus.unpaid,
    );
  }

  String get label => switch (this) {
    DebtStatus.unpaid => 'Unpaid',
    DebtStatus.partial => 'Partial',
    DebtStatus.paid => 'Paid',
  };
}
