# Database Rules

The application uses Drift with SQLite. The current schema version is `6`.

## Storage Conventions

- IDs are UUID v4 values stored as SQLite `TEXT`.
- Money is stored as integer centavos (`INTEGER`), where 100 centavos equals one peso. Floating-point values are not used for money.
- Quantities are stored as SQLite `REAL` values so fractional quantities are supported.
- Drift `DateTime` values are stored as SQLite `INTEGER` values. Application repositories normalize persisted dates and timestamps to UTC.
- Debt transaction and payment timestamps combine the user-selected local calendar day with the local clock time at save before UTC normalization. Due dates remain date-only selections and do not receive the save time.
- A row is active when `deleted_at IS NULL`.
- Unless noted otherwise, validation and derived-value rules are enforced by the repositories rather than by SQLite `CHECK` or `UNIQUE` constraints.

## Tables

### `customers`

| Column | SQLite type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | `TEXT` | No | Primary key; UUID v4 |
| `name` | `TEXT` | No | Trimmed, non-empty customer name |
| `phone` | `TEXT` | Yes | Trimmed; an empty value is stored as `NULL` |
| `notes` | `TEXT` | Yes | Trimmed; an empty value is stored as `NULL` |
| `created_at` | `INTEGER` | No | Drift `DateTime`, UTC |
| `updated_at` | `INTEGER` | No | Drift `DateTime`, UTC |
| `deleted_at` | `INTEGER` | Yes | Drift `DateTime`, UTC; `NULL` means active |

### `debts`

| Column | SQLite type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | `TEXT` | No | Primary key; UUID v4 |
| `customer_id` | `TEXT` | No | Foreign key to `customers.id` |
| `total_amount` | `INTEGER` | No | Total debt amount in centavos |
| `paid_amount` | `INTEGER` | No | Amount paid in centavos |
| `balance` | `INTEGER` | No | Remaining amount in centavos |
| `status` | `TEXT` | No | `UNPAID`, `PARTIAL`, or `PAID` |
| `transaction_date` | `INTEGER` | No | Drift `DateTime`, UTC |
| `due_date` | `INTEGER` | Yes | Drift `DateTime`, UTC |
| `notes` | `TEXT` | Yes | Trimmed; an empty value is stored as `NULL` |
| `created_at` | `INTEGER` | No | Drift `DateTime`, UTC |
| `updated_at` | `INTEGER` | No | Drift `DateTime`, UTC |
| `deleted_at` | `INTEGER` | Yes | Drift `DateTime`, UTC; `NULL` means active |

### `debt_items`

| Column | SQLite type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | `TEXT` | No | Primary key; UUID v4 |
| `debt_id` | `TEXT` | No | Foreign key to `debts.id` |
| `product_name` | `TEXT` | No | Trimmed, non-empty product name |
| `quantity` | `REAL` | No | Must be greater than zero |
| `unit` | `TEXT` | No | Defaults to `piece`; maximum 24 characters |
| `price` | `INTEGER` | No | Final custom line amount in centavos; must be greater than zero |
| `deleted_at` | `INTEGER` | Yes | Drift `DateTime`, UTC; `NULL` means active |

Common unit values are:

- `piece`
- `pack`
- `box`
- `bottle`
- `kg`
- `g`
- `liter`
- `ml`
- `can`
- `sachet`
- `bag`
- `dozen`
- `tray`
- `bundle`

Common units are normalized case-insensitively to the values above. A trimmed, non-empty custom unit is also allowed. Items that predate unit support migrate to `piece`.

### `payments`

| Column | SQLite type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | `TEXT` | No | Primary key; UUID v4 |
| `debt_id` | `TEXT` | No | Foreign key to `debts.id` |
| `amount` | `INTEGER` | No | Payment amount in centavos |
| `payment_date` | `INTEGER` | No | Drift `DateTime`, UTC |
| `payment_method` | `TEXT` | No | Trimmed, non-empty value |
| `notes` | `TEXT` | Yes | Trimmed; an empty value is stored as `NULL` |
| `created_at` | `INTEGER` | No | Drift `DateTime`, UTC |
| `deleted_at` | `INTEGER` | Yes | Drift `DateTime`, UTC; `NULL` means active |

### `audit_logs`

| Column | SQLite type | Nullable | Notes |
| --- | --- | --- | --- |
| `id` | `TEXT` | No | Primary key; UUID v4 |
| `action` | `TEXT` | No | `customer_created`, `customer_updated`, `customer_deleted`, `debt_created`, `debt_updated`, `debt_items_added`, or `payment_recorded` |
| `entity_id` | `TEXT` | No | Id of the customer, debt, or payment the action belongs to |
| `summary` | `TEXT` | No | Human-readable Taglish description of the action |
| `created_at` | `INTEGER` | No | Drift `DateTime`, UTC |

Audit rows are immutable. They are never updated, soft-deleted, or purged.

## Relationships

- One customer can have many debts: `debts.customer_id` references `customers.id`.
- One debt can have many debt items: `debt_items.debt_id` references `debts.id`.
- One debt can have many payments: `payments.debt_id` references `debts.id`.
- The schema does not define cascading deletes. Related history is retained.

## Indexes

Fresh databases create these indexes:

- `idx_debts_customer_id` on `debts.customer_id`
- `idx_debts_status` on `debts.status`
- `idx_debts_transaction_date` on `debts.transaction_date`
- `idx_debt_items_debt_id` on `debt_items.debt_id`
- `idx_payments_debt_id` on `payments.debt_id`
- `idx_payments_payment_date` on `payments.payment_date`
- `idx_audit_logs_created_at` on `audit_logs.created_at`

## Business Rules

### Customers

- Customer names are required and unique among active customers, using a case-insensitive repository check. Soft-deleted names may be reused.
- A customer cannot be deleted while any active, unpaid debt (UNPAID or PARTIAL) exists for that customer.
- Customer deletion is a soft delete that sets `deleted_at` and `updated_at`.

### Debts and debt items

- A debt can be created only for an active customer and must contain at least one valid item.
- `debt_items.price` is the final custom line amount. Quantity does not multiply price.
- `total_amount = sum(active debt item prices)`.
- A new debt starts with `paid_amount = 0`, `balance = total_amount`, and `status = UNPAID`.
- Saving a debt preserves the selected transaction day and stamps it with the current local time.
- A debt is editable only while `paid_amount = 0`.
- Editing a debt is atomic: existing active items are soft-deleted, replacement items are inserted, and the debt totals and dates are updated in the same transaction.
- Items can be appended to a debt that has payments (`PARTIAL` status) without editing the record: existing items and payments are left untouched, `total_amount` grows by the added items, `paid_amount` is unchanged, and `balance` and `status` are recomputed in the same transaction.
- Appending items to a fully paid debt is rejected.

### Payments and debt status

- A payment amount must be greater than zero and cannot exceed the debt's current balance.
- Payments can be recorded only against an active debt that is not already `PAID`.
- Recording a payment preserves the selected payment day and stamps it with the current local time.
- Recording a payment is atomic: the payment is inserted and the debt's `paid_amount`, `balance`, `status`, and `updated_at` are updated in the same transaction.
- `balance = total_amount - paid_amount`.
- Status is derived from the paid amount:
  - `UNPAID` when `paid_amount <= 0`
  - `PARTIAL` when `0 < paid_amount < total_amount`
  - `PAID` when `paid_amount >= total_amount`

## Active-Record Query Behavior

- Customer lists, searches, lookups, and counts include only active customers.
- Debt lists and detail lookups include only active debts whose customer is active; debt items in a detail view must also be active.
- Active-debt counts and outstanding-balance totals include active debts with `UNPAID` or `PARTIAL` status.
- General payment lists include only active payments whose debt and customer are active. Debt-specific payment history filters active payments by debt ID.
- Collected-amount totals include active payments within the requested UTC date range.
- The current repositories expose soft deletion for customers and use soft deletion when replacing debt items. They do not expose debt or payment deletion operations.

## Audit Log

- Every customer, debt, and payment write appends one `audit_logs` row. Audit rows are written by the repository that performs the change, so the log cannot miss an action.
- Debt and payment changes are logged inside the same transaction as the change itself.
- Customer additions, updates, and deletions are logged right after the change succeeds.
- The audit log is append-only: rows are never updated, soft-deleted, or purged, and no retention limit is applied.
- The log lists the newest entries first.

## Migration History

- Version 2 added `deleted_at` to all four tables.
- Version 3 recreated the legacy `debt_items` table without its earlier unit column.
- Version 4 added the current `unit` column with a `piece` default.
- Version 5 replaced the legacy `unit_price` and `subtotal` columns with `price`, preserving each existing item's former subtotal as its final custom line amount.
- Version 6 added the `audit_logs` table.
