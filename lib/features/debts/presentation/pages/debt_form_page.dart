import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/utils/date_time_display.dart';
import 'package:utang_tracker/core/utils/debt_math.dart';
import 'package:utang_tracker/core/utils/user_facing_error.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_card.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';
import 'package:utang_tracker/core/widgets/app_search_bar.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/core/widgets/confirmation_dialog.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/core/widgets/money_text.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/presentation/providers/customer_providers.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';
import 'package:utang_tracker/features/debts/domain/usecases/get_debt_detail.dart';
import 'package:utang_tracker/features/debts/presentation/providers/debt_providers.dart';
import 'package:utang_tracker/features/debts/presentation/widgets/debt_item_sheet.dart';

class DebtFormPage extends ConsumerStatefulWidget {
  const DebtFormPage({super.key, this.debtId, this.initialCustomerId});

  final String? debtId;
  final String? initialCustomerId;

  bool get isEditing => debtId != null;

  @override
  ConsumerState<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends ConsumerState<DebtFormPage> {
  bool _isDirty = false;
  final _customerFieldKey = GlobalKey();
  String? _customerId;
  String? _customerName;
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  final _notesController = TextEditingController();
  bool _notesExpanded = false;
  final List<DebtItemInput> _items = [];
  bool _saving = false;
  bool _loaded = false;
  String? _customerError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _customerId = widget.initialCustomerId;
    if (widget.initialCustomerId != null && !widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveCustomerName(widget.initialCustomerId!);
      });
    }
  }

  Future<void> _resolveCustomerName(String customerId) async {
    final customer = await ref
        .read(customerOperationsProvider)
        .getById(customerId);
    if (!mounted || customer == null) return;
    if (_customerId != customerId) return;
    setState(() => _customerName = customer.name);
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _confirmBack() async {
    if (_saving) return;
    if (await confirmDiscardChanges(context) && mounted) context.pop();
  }

  Future<void> _pickCustomer() async {
    final selected = await showAppModalBottomSheet<Customer>(
      context: context,
      builder: (context) =>
          _CustomerPickerSheet(selectedCustomerId: _customerId),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _customerId = selected.id;
      _customerName = selected.name;
      _customerError = null;
    });
    _markDirty();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Money get _total {
    return computeTotal(_items.map((debtItem) => debtItem.price));
  }

  Future<void> _pickDate({required bool due}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime initialRaw;
    DateTime firstDate;
    if (due) {
      initialRaw = _dueDate ?? _transactionDate;
      firstDate = today;
    } else {
      initialRaw = _transactionDate;
      firstDate = DateTime(2020);
    }
    var initial = initialRaw;
    if (due && initialRaw.isBefore(today)) {
      initial = today;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (due) {
        _dueDate = picked;
      } else {
        _transactionDate = picked;
      }
    });
    _markDirty();
  }

  Future<void> _showItemDialog({int? index}) async {
    DebtItemInput? existing;
    if (index != null) {
      existing = _items[index];
    }
    final result = await showDebtItemSheet(context, existing: existing);
    if (result == null) return;
    if (!mounted) return;
    final input = result.input;
    if (input != null) {
      setState(() {
        if (index != null) {
          _items[index] = input;
        } else {
          _items.add(input);
        }
        _error = null;
      });
      _markDirty();
    } else if (result.deleted) {
      if (index != null) {
        setState(() {
          _items.removeAt(index);
          _error = null;
        });
        _markDirty();
      }
    }
  }

  Future<void> _save() async {
    String? customerError;
    if (_customerId == null) {
      customerError = 'Select a customer.';
    }
    setState(() {
      _error = null;
      _customerError = customerError;
    });
    if (_customerError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToFirstError();
      });
      return;
    }
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }
    if (_dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dueDay = DateTime(_dueDate!.year, _dueDate!.month, _dueDate!.day);
      if (dueDay.isBefore(today)) {
        setState(() => _error = 'Due date cannot be in the past');
        return;
      }
    }
    final items = _items.toList();

    final customerLabel = _customerName ?? 'No customer';
    final dateLabel = context.smartDate(_transactionDate);
    String dueLabel;
    if (_dueDate == null) {
      dueLabel = 'No due date';
    } else {
      dueLabel = context.smartDate(_dueDate!);
    }
    final totalLabel = _total.format();
    final notesText = _notesController.text.trim();
    String confirmationTitle;
    String confirmationAction;
    if (widget.isEditing) {
      confirmationTitle = 'Confirm changes?';
      confirmationAction = 'Save';
    } else {
      confirmationTitle = 'Confirm debt?';
      confirmationAction = 'Confirm';
    }
    final confirmedItems = items;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.pagePadding,
          AppSpacing.xl,
          0,
        ),
        title: Text(confirmationTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSummaryRow(
                dialogContext,
                label: 'Customer',
                value: customerLabel,
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(dialogContext, label: 'Date', value: dateLabel),
              const SizedBox(height: AppSpacing.sm),
              _buildSummaryRow(dialogContext, label: 'Due', value: dueLabel),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Items',
                style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ...confirmedItems.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${entry.productName} \u00b7 ${DebtItemUnits.formatQuantity(entry.quantity)} ${DebtItemUnits.displayNameForQuantity(entry.unit, entry.quantity)}',
                          style: Theme.of(dialogContext).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        entry.price.format(),
                        style: Theme.of(dialogContext).textTheme.bodySmall
                            ?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: AppSpacing.lg),
              Row(
                children: [
                  Text(
                    'Total',
                    style: Theme.of(dialogContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    totalLabel,
                    style: Theme.of(dialogContext).textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (notesText.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Notes',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  notesText,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmationAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final operations = ref.read(debtOperationsProvider);
      if (widget.isEditing) {
        await operations.update(
          debtId: widget.debtId!,
          transactionDate: _transactionDate,
          dueDate: _dueDate,
          notes: _notesController.text,
          items: items,
        );
        ref.read(dataVersionProvider.notifier).bump();
      } else {
        await operations.create(
          customerId: _customerId!,
          transactionDate: _transactionDate,
          dueDate: _dueDate,
          notes: _notesController.text,
          items: items,
        );
        ref.read(dataVersionProvider.notifier).bump();
      }

      if (!mounted) return;
      _isDirty = false;
      String successMessage;
      if (widget.isEditing) {
        successMessage = 'Debt updated';
      } else {
        successMessage = 'Debt recorded';
      }
      AppSnackBar.success(context, successMessage);
      context.pop();
    } on AppException catch (appException) {
      if (!mounted) return;
      setState(() => _error = appException.message);
    } catch (caughtError) {
      if (!mounted) return;
      setState(() => _error = userFacingError(caughtError));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dueDateValue(BuildContext context) {
    final dueDate = _dueDate;
    if (dueDate == null) return 'Optional';
    return context.smartDate(dueDate);
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  void _loadEdit(DebtDetailData data) {
    _customerId = data.detail.debt.customerId;
    _customerName = data.detail.debt.customerName;
    _transactionDate = data.detail.debt.transactionDate.toLocal();
    _dueDate = data.detail.debt.dueDate?.toLocal();
    _notesController.text = data.detail.debt.notes ?? '';
    _notesExpanded = _notesController.text.trim().isNotEmpty;
    if (_customerName == null || _customerName!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_customerId != null) _resolveCustomerName(_customerId!);
      });
    }
    _items
      ..clear()
      ..addAll(
        data.detail.items.map(
          (item) => DebtItemInput(
            productName: item.productName,
            quantity: item.quantity,
            unit: item.unit,
            price: item.price,
          ),
        ),
      );
    _isDirty = false;
    _loaded = true;
  }

  void _scrollToFirstError() {
    if (_customerError != null) {
      final ctx = _customerFieldKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.2,
          duration: const Duration(milliseconds: 300),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_loaded) {
      final async = ref.watch(debtDetailProvider(widget.debtId!));
      return async.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit debt')),
          body: const LoadingIndicator(),
        ),
        error: (error, stackTrace) => Scaffold(
          appBar: AppBar(title: const Text('Edit debt')),
          body: ErrorView(message: userFacingError(error)),
        ),
        data: (data) {
          if (data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit debt')),
              body: const Center(child: Text('Debt not found')),
            );
          }
          if (!data.detail.debt.isEditable) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit debt')),
              body: const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'This debt already has payments and cannot be edited.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          if (!_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _loadEdit(data));
            });
          }
          return _buildForm();
        },
      );
    }

    return _buildForm();
  }

  Widget _buildForm() {
    String title;
    String notesTooltip;
    IconData notesIcon;
    if (widget.isEditing) {
      title = 'Edit debt';
    } else {
      title = 'New debt';
    }
    if (_notesExpanded) {
      notesTooltip = 'Hide note';
      notesIcon = Icons.close;
    } else {
      notesTooltip = 'Add note';
      notesIcon = Icons.add;
    }

    return PopScope(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        bottomNavigationBar: _buildBottomBar(),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            AppTextField.buildLabel(context, 'Customer *'),
            const SizedBox(height: AppSpacing.sm),
            _CustomerField(
              key: _customerFieldKey,
              name: _customerName,
              enabled: !widget.isEditing,
              onTap: _pickCustomer,
              errorText: _customerError,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Date',
                    required: true,
                    value: context.smartDate(_transactionDate),
                    onTap: () => _pickDate(due: false),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _DateField(
                    label: 'Due date',
                    value: _dueDateValue(context),
                    onTap: () => _pickDate(due: true),
                    onClear: _dueDate == null
                        ? null
                        : () {
                            setState(() => _dueDate = null);
                            _markDirty();
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppTextField.buildLabel(context, 'Items *'),
                TextButton.icon(
                  onPressed: () => _showItemDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Center(
                  child: Text(
                    'No items',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var index = 0; index < _items.length; index++) ...[
                      InkWell(
                        onTap: () => _showItemDialog(index: index),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.cardPadding,
                            vertical: AppSpacing.md,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _items[index].productName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      '${DebtItemUnits.formatQuantity(_items[index].quantity)} ${DebtItemUnits.displayNameForQuantity(_items[index].unit, _items[index].quantity)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  MoneyText(
                                    _items[index].price,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 20,
                                      color: AppColors.textMuted,
                                    ),
                                    onPressed: () =>
                                        _showItemDialog(index: index),
                                    padding: const EdgeInsets.all(
                                      AppSpacing.md,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    tooltip: 'Edit',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (index < _items.length - 1)
                        const Divider(
                          height: 1,
                          indent: AppSpacing.cardPadding,
                          endIndent: AppSpacing.cardPadding,
                        ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppTextField.buildLabel(context, 'Notes'),
                IconButton(
                  tooltip: notesTooltip,
                  onPressed: () =>
                      setState(() => _notesExpanded = !_notesExpanded),
                  icon: Icon(notesIcon, size: 20, color: AppColors.textMuted),
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                hint: 'Add any details (optional)',
                minLines: 4,
                maxLines: 6,
                onChanged: (_) => _markDirty(),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    String saveLabel;
    if (widget.isEditing) {
      saveLabel = 'Save changes';
    } else {
      saveLabel = 'Save';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.sm,
          AppSpacing.pagePadding,
          AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Row(
              children: [
                Text(
                  'Total',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                MoneyText(_total, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(label: saveLabel, onPressed: _save, isLoading: _saving),
          ],
        ),
      ),
    );
  }
}

class _CustomerField extends StatelessWidget {
  const _CustomerField({
    super.key,
    required this.name,
    required this.enabled,
    required this.onTap,
    this.errorText,
  });

  final String? name;
  final bool enabled;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.isNotEmpty;
    VoidCallback? tapHandler;
    IconData suffixIcon;
    String displayName;
    Color displayColor;
    if (enabled) {
      tapHandler = onTap;
      suffixIcon = Icons.person_search_outlined;
    } else {
      suffixIcon = Icons.lock_outline;
    }
    if (hasName) {
      displayName = name!;
      displayColor = AppColors.textPrimary;
    } else {
      displayName = 'Select customer';
      displayColor = AppColors.textMuted;
    }

    return InkWell(
      onTap: tapHandler,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: errorText,
          suffixIcon: Icon(suffixIcon, size: 20, color: AppColors.textMuted),
        ),
        child: Text(
          displayName,
          style: AppTextField.inputStyle(context, color: displayColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet({required this.selectedCustomerId});

  final String? selectedCustomerId;

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  String _query = '';
  List<Customer>? _customers;
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
      final trimmed = query.trim();
      final operations = ref.read(customerOperationsProvider);
      List<Customer> results;
      if (trimmed.isEmpty) {
        results = await operations.getAll();
      } else {
        results = await operations.search(trimmed);
      }
      if (!mounted) return;
      setState(() {
        _customers = results;
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
    final customers = _customers;

    return AppModalBottomSheet(
      title: 'Select customer',
      headerBottom: AppSearchBar(
        hintText: 'Search by customer name',
        onChanged: (value) {
          _query = value;
          _load(value);
        },
      ),
      footer: TextButton.icon(
        onPressed: () async {
          final router = GoRouter.of(context);
          final created = await router.push<Customer>('/customers/new');
          if (!context.mounted) return;
          if (created == null) return;
          Navigator.of(context).pop(created);
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add customer'),
      ),
      child: _buildBody(customers),
    );
  }

  Widget _buildBody(List<Customer>? customers) {
    if (_loading && customers == null) {
      return const LoadingIndicator();
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Text(
            userFacingError(_error!),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
          ),
        ),
      );
    }
    if (customers == null || customers.isEmpty) {
      final searching = _query.trim().isNotEmpty;
      String emptyMessage;
      if (searching) {
        emptyMessage = 'No customers match your search.';
      } else {
        emptyMessage = 'No customers yet. Add one to continue.';
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
      itemCount: customers.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        indent: AppSpacing.lg,
        endIndent: AppSpacing.lg,
        color: AppColors.outline,
      ),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final selected = customer.id == widget.selectedCustomerId;
        Widget? subtitle;
        if (customer.phone != null && customer.phone!.isNotEmpty) {
          subtitle = Text(customer.phone!);
        }
        Widget? trailing;
        if (selected) {
          trailing = const Icon(Icons.check, color: AppColors.primaryDark);
        }
        return ListTile(
          title: Text(customer.name),
          subtitle: subtitle,
          trailing: trailing,
          onTap: () => Navigator.of(context).pop(customer),
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.required = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool required;

  @override
  Widget build(BuildContext context) {
    String fieldLabel;
    if (required) {
      fieldLabel = '$label *';
    } else {
      fieldLabel = label;
    }
    Widget suffixIcon;
    if (onClear != null) {
      suffixIcon = IconButton(
        icon: const Icon(Icons.clear, size: 18),
        onPressed: onClear,
      );
    } else {
      suffixIcon = const Icon(Icons.calendar_today_outlined, size: 18);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField.buildLabel(context, fieldLabel),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: InputDecoration(suffixIcon: suffixIcon),
            child: Text(
              value,
              style: AppTextField.inputStyle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
