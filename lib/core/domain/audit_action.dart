enum AuditAction {
  customerCreated('customer_created', 'Customer added'),
  customerUpdated('customer_updated', 'Customer updated'),
  customerDeleted('customer_deleted', 'Customer deleted'),
  debtCreated('debt_created', 'Debt created'),
  debtUpdated('debt_updated', 'Debt updated'),
  debtItemsAdded('debt_items_added', 'Items added'),
  paymentRecorded('payment_recorded', 'Payment recorded'),
  unknown('unknown', 'Unknown action');

  const AuditAction(this.value, this.label);

  final String value;
  final String label;

  static AuditAction fromValue(String value) {
    return AuditAction.values.firstWhere(
      (action) => action.value == value,
      orElse: () => AuditAction.unknown,
    );
  }
}
