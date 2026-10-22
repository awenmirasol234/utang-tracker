import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/app/coordination.dart';
import 'package:utang_tracker/core/constants/app_constants.dart';
import 'package:utang_tracker/core/domain/debt_status.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';
import 'package:utang_tracker/core/widgets/app_search_bar.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/core/widgets/confirmation_dialog.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/core/widgets/status_badge.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt.dart';
import 'package:utang_tracker/features/payments/presentation/providers/payment_providers.dart';

class RecordPaymentPage extends ConsumerStatefulWidget {
  const RecordPaymentPage({super.key, this.initialDebtId});

  final String? initialDebtId;

  @override
  ConsumerState<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends ConsumerState<RecordPaymentPage> {
  bool _isDirty = false;
  final _debtFieldKey = GlobalKey();
  final _amountFocusNode = FocusNode();
  String? _debtId;
  Debt? _selectedDebt;
  final _amountController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  final _notesController = TextEditingController();
  bool _notesExpanded = false;
  bool _saving = false;
  bool _confirmed = false;
  String? _debtError;
  String? _amountError;
  String? _error;
  bool _resolvingInitial = false;

  @override
  void initState() {
    super.initState();
    _debtId = widget.initialDebtId;
    if (widget.initialDebtId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveInitialDebt(widget.initialDebtId!);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _confirmBack() async {
    if (_saving) return;
    if (await confirmDiscardChanges(context) && mounted) context.pop();
  }

  Future<void> _resolveInitialDebt(String debtId) async {
    setState(() => _resolvingInitial = true);
    try {
      final detail = await ref.read(debtRepositoryProvider).getById(debtId);
      if (!mounted || detail == null) return;
      final debt = detail.debt;
      if (debt.status == DebtStatus.paid) {
        setState(() {
          _debtId = null;
          _selectedDebt = null;
          _resolvingInitial = false;
        });
        return;
      }
      _applyDebtSelection(debt);
    } finally {
      if (mounted) setState(() => _resolvingInitial = false);
    }
  }

  void _applyDebtSelection(Debt debt) {
    setState(() {
      _debtId = debt.id;
      _selectedDebt = debt;
      _amountController.text = debt.balance.pesos.toStringAsFixed(2);
      _debtError = null;
      _amountError = null;
      _error = null;
    });
    _markDirty();
  }

  Future<void> _pickDebt() async {
    final selected = await showAppModalBottomSheet<Debt>(
      context: context,
      builder: (context) => const _DebtPickerSheet(),
    );
    if (selected == null || !mounted) return;
    _applyDebtSelection(selected);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
      _markDirty();
    }
  }

  Future<void> _save() async {
    Money? amount;
    String? debtError;
    if (_debtId == null) {
      debtError = 'Select debt';
    }
    setState(() {
      _error = null;
      _debtError = debtError;

      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        _amountError = 'Amount is required.';
        return;
      }
      try {
        final parsed = Money.fromPesoString(amountText);
        if (!parsed.isPositive) {
          _amountError = 'Amount must be greater than 0.';
          return;
        }
        amount = parsed;
        _amountError = null;
      } catch (_) {
        _amountError = 'Enter a valid amount.';
      }
    });
    if (_debtError != null || amount == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_debtError != null) {
          final ctx = _debtFieldKey.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(
              ctx,
              alignment: 0.2,
              duration: const Duration(milliseconds: 300),
            );
          }
        } else {
          _amountFocusNode.requestFocus();
        }
      });
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(recordPaymentUseCaseProvider)(
        debtId: _debtId!,
        amount: amount!,
        paymentDate: _paymentDate,
        paymentMethod: AppConstants.defaultPaymentMethod,
        notes: _notesController.text,
      );
      invalidateBusinessData(
        ref,
        customerId: _selectedDebt?.customerId,
        debtId: _debtId,
      );
      if (!mounted) return;
      _isDirty = false;
      AppSnackBar.success(context, 'Payment recorded');
      context.pop();
    } on AppException catch (appException) {
      if (!mounted) return;
      setState(() => _error = appException.message);
    } catch (caughtError) {
      if (!mounted) return;
      setState(() => _error = caughtError.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? get _debtFieldLabel {
    final debt = _selectedDebt;
    if (debt == null) return null;
    final name = debt.customerName ?? 'Customer';
    return '$name - ${debt.balance.format()}';
  }

  String get _saveLabel {
    if (!_confirmed) return 'Save';
    try {
      final amt = Money.fromPesoString(_amountController.text);
      if (amt.isPositive) return 'Save ${amt.format()}';
      return 'Save';
    } catch (_) {
      return 'Save';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingInitial && _selectedDebt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record payment')),
        body: const LoadingIndicator(),
      );
    }

    final selected = _selectedDebt;
    String notesTooltip;
    IconData notesIcon;
    if (_notesExpanded) {
      notesTooltip = 'Hide note';
      notesIcon = Icons.close;
    } else {
      notesTooltip = 'Add note';
      notesIcon = Icons.add;
    }
    VoidCallback? saveHandler;
    if (_confirmed) {
      saveHandler = _save;
    }

    return PopScope(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmBack();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Record payment')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            AppTextField.buildLabel(context, 'Debt *'),
            const SizedBox(height: AppSpacing.sm),
            _DebtField(
              key: _debtFieldKey,
              label: _debtFieldLabel,
              onTap: _pickDebt,
              errorText: _debtError,
            ),
            if (selected != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Remaining balance: ${selected.balance.format()}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              label: 'Amount *',
              hint: '100.00',
              errorText: _amountError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],

              onChanged: (_) => setState(() {
                _markDirty();
                _amountError = null;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField.buildLabel(context, 'Payment date *'),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  context.smartDate(_paymentDate),
                  style: AppTextField.inputStyle(context),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppTextField.buildLabel(context, 'Notes'),
                IconButton(
                  tooltip: notesTooltip,
                  onPressed: () => setState(() => _notesExpanded = !_notesExpanded),
                  icon: Icon(
                    notesIcon,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_notesExpanded) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _notesController,
                hint: 'Optional',
                minLines: 4,
                maxLines: 6,
                onChanged: (_) => _markDirty(),
              ),
            ],
            if (selected != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Balance after payment',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const Spacer(),
                  Builder(
                    builder: (context) {
                      try {
                        final amt = Money.fromPesoString(
                          _amountController.text,
                        );
                        final after = selected.balance - amt;
                        Money displayedBalance;
                        if (after.isNegative) {
                          displayedBalance = Money.zero();
                        } else {
                          displayedBalance = after;
                        }
                        return MoneyText(
                          displayedBalance,
                        );
                      } catch (_) {
                        return MoneyText(selected.balance);
                      }
                    },
                  ),
                ],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              key: const Key('confirm-payment-row'),
              children: [
                Checkbox(
                  value: _confirmed,
                  onChanged: (value) => setState(() => _confirmed = value ?? false),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _confirmed = !_confirmed),
                    child: Text(
                      'I confirm the payment details are correct',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _saveLabel,
              onPressed: saveHandler,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtField extends StatelessWidget {
  const _DebtField({
    super.key,
    required this.label,
    required this.onTap,
    this.errorText,
  });

  final String? label;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasLabel = label != null && label!.isNotEmpty;
    VoidCallback? tapHandler = onTap;
    String displayLabel;
    Color displayColor;
    if (hasLabel) {
      displayLabel = label!;
      displayColor = AppColors.textPrimary;
    } else {
      displayLabel = 'Select debt';
      displayColor = AppColors.textMuted;
    }
    return InkWell(
      onTap: tapHandler,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: errorText,
          suffixIcon: const Icon(
            Icons.receipt_long_outlined,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
        child: Text(
          displayLabel,
          style: AppTextField.inputStyle(
            context,
            color: displayColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _DebtPickerSheet extends ConsumerStatefulWidget {
  const _DebtPickerSheet();

  @override
  ConsumerState<_DebtPickerSheet> createState() => _DebtPickerSheetState();
}

class _DebtPickerSheetState extends ConsumerState<_DebtPickerSheet> {
  String _query = '';
  List<Debt>? _debts;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(debtRepositoryProvider);
      final unpaid = await repo.getAll(status: DebtStatus.unpaid);
      final partial = await repo.getAll(status: DebtStatus.partial);
      final open = [...unpaid, ...partial]
        ..sort((first, second) => second.transactionDate.compareTo(first.transactionDate));

      final trimmed = query.trim().toLowerCase();
      List<Debt> filtered;
      if (trimmed.isEmpty) {
        filtered = open;
      } else {
        filtered = open
            .where(
              (debt) => (debt.customerName ?? '').toLowerCase().contains(trimmed),
            )
            .toList();
      }

      if (!mounted) return;
      setState(() {
        _debts = filtered;
        _loading = false;
      });
    } catch (caughtError) {
      if (!mounted) return;
      setState(() {
        _error = caughtError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final debts = _debts;

    return AppModalBottomSheet(
      title: 'Select debt',
      headerBottom: AppSearchBar(
        hintText: 'Search by customer',
        onChanged: (value) {
          _query = value;
          _load(value);
        },
      ),
      child: _buildBody(debts),
    );
  }

  Widget _buildBody(List<Debt>? debts) {
    if (_loading && debts == null) {
      return const LoadingIndicator();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            _error.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
          ),
        ),
      );
    }
    if (debts == null || debts.isEmpty) {
      final searching = _query.trim().isNotEmpty;
      String emptyMessage;
      if (searching) {
        emptyMessage = 'No debts match your search.';
      } else {
        emptyMessage = 'No debts yet';
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      itemCount: debts.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final debt = debts[index];
        return ListTile(
          title: Text(debt.customerName ?? 'Customer'),
          subtitle: Text(context.smartTimestamp(debt.transactionDate)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MoneyText(debt.balance),
              const SizedBox(height: 4),
              StatusBadge(status: debt.status),
            ],
          ),
          onTap: () => Navigator.of(context).pop(debt),
        );
      },
    );
  }
}
