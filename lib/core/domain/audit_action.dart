enum AuditAction {
  customerCreated('customer_created', 'Nag-add customer'),
  customerUpdated('customer_updated', 'Na-update customer'),
  customerDeleted('customer_deleted', 'Na-delete customer'),
  debtCreated('debt_created', 'Bag-ong utang'),
  debtUpdated('debt_updated', 'Na-update utang'),
  debtItemsAdded('debt_items_added', 'Nag-add items'),
  paymentRecorded('payment_recorded', 'Nagbayad'),
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
