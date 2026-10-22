import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:utang_tracker/app/coordination.dart';
import 'package:utang_tracker/core/error/app_exception.dart';
import 'package:utang_tracker/core/providers/core_providers.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/widgets/app_button.dart';
import 'package:utang_tracker/core/widgets/app_snackbar.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/core/widgets/confirmation_dialog.dart';
import 'package:utang_tracker/core/widgets/error_view.dart';
import 'package:utang_tracker/core/widgets/loading_indicator.dart';
import 'package:utang_tracker/features/customers/domain/entities/customer.dart';
import 'package:utang_tracker/features/customers/presentation/providers/customer_providers.dart';

class CustomerFormPage extends ConsumerStatefulWidget {
  const CustomerFormPage({super.key, this.customerId});

  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  ConsumerState<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends ConsumerState<CustomerFormPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _notesExpanded = false;
  bool _isDirty = false;
  String? _nameError;
  bool _saving = false;
  bool _loaded = false;
  Customer? _existing;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  Future<void> _confirmBack() async {
    if (await confirmDiscardChanges(context) && mounted) context.pop();
  }

  void _populate(Customer customer) {
    _existing = customer;
    _nameController.text = customer.name;
    _phoneController.text = customer.phone ?? '';
    _notesController.text = customer.notes ?? '';
    _notesExpanded = _notesController.text.trim().isNotEmpty;
    _isDirty = false;
    _loaded = true;
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _nameFocusNode.requestFocus();
      });
      return;
    }
    setState(() {
      _nameError = null;
      _saving = true;
    });

    Customer? created;
    try {
      final repo = ref.read(customerRepositoryProvider);
      if (widget.isEditing && _existing != null) {
        await repo.update(
          Customer(
            id: _existing!.id,
            name: name,
            phone: _phoneController.text,
            notes: _notesController.text,
            createdAt: _existing!.createdAt,
            updatedAt: _existing!.updatedAt,
          ),
        );
        invalidateBusinessData(ref, customerId: _existing!.id);
      } else {
        created = await repo.create(
          name: name,
          phone: _phoneController.text,
          notes: _notesController.text,
        );
        invalidateBusinessData(ref, customerId: created.id);
      }

      if (!mounted) return;
      _isDirty = false;
      String successMessage;
      if (widget.isEditing) {
        successMessage = 'Customer updated';
      } else {
        successMessage = 'Customer added';
      }
      AppSnackBar.success(
        context,
        successMessage,
      );
      if (created == null) {
        context.pop();
      } else {
        context.pop(created);
      }
    } on ConflictException catch (conflictException) {
      if (!mounted) return;
      setState(() => _nameError = conflictException.message);
    } on AppException catch (appException) {
      if (!mounted) return;
      AppSnackBar.error(context, appException.message);
    } catch (caughtError) {
      if (!mounted) return;
      AppSnackBar.error(context, caughtError.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing && !_loaded) {
      final async = ref.watch(customerDetailProvider(widget.customerId!));
      return async.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Edit customer')),
          body: const LoadingIndicator(),
        ),
        error: (error, stackTrace) => Scaffold(
          appBar: AppBar(title: const Text('Edit customer')),
          body: ErrorView(message: error.toString()),
        ),
        data: (data) {
          if (data == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Edit customer')),
              body: const Center(child: Text('Customer not found')),
            );
          }
          if (!_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _populate(data.customer));
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
    String saveLabel;
    if (widget.isEditing) {
      title = 'Edit customer';
      saveLabel = 'Save changes';
    } else {
      title = 'Add customer';
      saveLabel = 'Add customer';
    }

    if (_notesExpanded) {
      notesTooltip = 'Hide note';
      notesIcon = Icons.close;
    } else {
      notesTooltip = 'Add note';
      notesIcon = Icons.add;
    }

    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (widget.isEditing)
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showConfirmationDialog(
                    context: context,
                    title: 'Delete customer?',
                    message:
                        'Hide this customer from lists? Customers with unpaid debts cannot be deleted.',
                    confirmLabel: 'Delete',
                    isDestructive: true,
                  );
                  if (!confirmed || !mounted) return;
                  try {
                    await ref
                        .read(customerRepositoryProvider)
                        .delete(widget.customerId!);
                    invalidateBusinessData(ref);
                    if (!mounted) return;
                    AppSnackBar.success(context, 'Customer deleted');
                    context.pop();
                  } on AppException catch (appException) {
                    if (!mounted) return;
                    AppSnackBar.error(context, appException.message);
                  }
                },
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [
            AppTextField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              label: 'Name *',
              hint: 'Maria Santos',
              errorText: _nameError,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                _markDirty();
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _phoneController,
              label: 'Phone',
              hint: '0917 123 4567',
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _markDirty(),
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
                textInputAction: TextInputAction.done,
                onChanged: (_) => _markDirty(),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: saveLabel,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
