import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:utang_tracker/core/domain/money.dart';
import 'package:utang_tracker/core/theme/app_colors.dart';
import 'package:utang_tracker/core/theme/app_spacing.dart';
import 'package:utang_tracker/core/widgets/app_modal_bottom_sheet.dart';
import 'package:utang_tracker/core/widgets/app_text_field.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item.dart';
import 'package:utang_tracker/features/debts/domain/entities/debt_item_unit.dart';

class DebtItemSheetResult {
  const DebtItemSheetResult.saved(this.input) : deleted = false;

  const DebtItemSheetResult.deleted() : input = null, deleted = true;

  final DebtItemInput? input;
  final bool deleted;
}

Future<DebtItemSheetResult?> showDebtItemSheet(
  BuildContext context, {
  DebtItemInput? existing,
}) {
  return showAppModalBottomSheet<DebtItemSheetResult>(
    context: context,
    builder: (context) => DebtItemSheet(existing: existing),
  );
}

class DebtItemSheet extends StatefulWidget {
  const DebtItemSheet({super.key, this.existing});

  final DebtItemInput? existing;

  @override
  State<DebtItemSheet> createState() => _DebtItemSheetState();
}

class _DebtItemSheetState extends State<DebtItemSheet> {
  late final TextEditingController _productController;
  late final TextEditingController _quantityController;
  late final TextEditingController _priceController;
  late String _unit;
  String? _productError;
  String? _quantityError;
  String? _priceError;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _productController = TextEditingController(
      text: existing?.productName ?? '',
    );
    String quantityText;
    String priceText;
    if (existing != null) {
      quantityText = _formatQuantity(existing.quantity);
      priceText = existing.price.pesos.toStringAsFixed(2);
    } else {
      quantityText = '1';
      priceText = '';
    }
    _quantityController = TextEditingController(
      text: quantityText,
    );
    _priceController = TextEditingController(
      text: priceText,
    );
    _unit = existing?.unit ?? DebtItemUnits.piece;
  }

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String _formatQuantity(double quantity) {
    if (quantity % 1 == 0) return quantity.toInt().toString();
    return quantity.toString();
  }

  Future<void> _pickUnit() async {
    final selected = await showAppModalBottomSheet<String>(
      context: context,
      builder: (context) => _UnitPickerSheet(selectedUnit: _unit),
    );
    if (selected == null) return;
    setState(() => _unit = selected);
  }

  void _save() {
    final productName = _productController.text.trim();
    final quantityText = _quantityController.text.trim();
    final priceText = _priceController.text.trim();
    final qty = double.tryParse(quantityText);

    String? pErr;
    String? qErr;
    String? prErr;
    Money? price;

    if (productName.isEmpty) {
      pErr = 'Product is required.';
    }
    if (quantityText.isEmpty) {
      qErr = 'Quantity is required.';
    } else if (qty == null) {
      qErr = 'Enter a valid quantity.';
    } else if (qty <= 0) {
      qErr = 'Quantity must be greater than 0.';
    }

    if (priceText.isEmpty) {
      prErr = 'Price is required.';
    } else {
      try {
        price = Money.fromPesoString(priceText);
        if (!price.isPositive) {
          prErr = 'Price must be greater than 0.';
        }
      } catch (_) {
        prErr = 'Enter a valid price.';
      }
    }

    if (pErr != null || qErr != null || prErr != null) {
      setState(() {
        _productError = pErr;
        _quantityError = qErr;
        _priceError = prErr;
      });
      return;
    }

    final input = DebtItemInput(
      productName: productName,
      quantity: qty!,
      unit: _unit,
      price: price!,
    );
    Navigator.of(context).pop(DebtItemSheetResult.saved(input));
  }

  @override
  Widget build(BuildContext context) {
    String title;
    String saveLabel;
    if (_isEditing) {
      title = 'Edit item';
      saveLabel = 'Update';
    } else {
      title = 'Add item';
      saveLabel = 'Save';
    }

    return AppModalBottomSheet(
      title: title,
      footer: Row(
        children: [
          if (_isEditing)
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(const DebtItemSheetResult.deleted()),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: _save,
            child: Text(saveLabel),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _productController,
              label: 'Product *',
              hint: 'Bugas',
              errorText: _productError,
              onChanged: (_) {
                if (_productError != null) {
                  setState(() => _productError = null);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _quantityController,
                    label: 'Quantity *',
                    hint: '2',
                    errorText: _quantityError,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                    ],
                    onChanged: (_) {
                      if (_quantityError != null) {
                        setState(() => _quantityError = null);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: _UnitField(unit: _unit, onTap: _pickUnit)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _priceController,
              label: 'Price *',
              hint: '50.00',
              errorText: _priceError,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              onChanged: (_) {
                if (_priceError != null) {
                  setState(() => _priceError = null);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitField extends StatelessWidget {
  const _UnitField({required this.unit, required this.onTap});

  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField.buildLabel(context, 'Unit *'),
        const SizedBox(height: AppSpacing.sm),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DebtItemUnits.displayName(unit),
                    style: AppTextField.inputStyle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UnitPickerSheet extends StatelessWidget {
  const _UnitPickerSheet({required this.selectedUnit});

  final String selectedUnit;

  @override
  Widget build(BuildContext context) {
    final selectedIsCustom = !DebtItemUnits.isCommon(selectedUnit);

    return AppModalBottomSheet(
      title: 'Select unit',
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        itemCount: DebtItemUnits.common.length + 1,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          indent: AppSpacing.lg,
          endIndent: AppSpacing.lg,
          color: AppColors.outline,
        ),
        itemBuilder: (context, index) {
          if (index == DebtItemUnits.common.length) {
            Widget customSubtitle;
            Widget customTrailing;
            String initialValue;
            if (selectedIsCustom) {
              customSubtitle = Text(
                DebtItemUnits.displayName(selectedUnit),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              );
              customTrailing = const Icon(
                Icons.check,
                color: AppColors.primaryDark,
              );
              initialValue = selectedUnit;
            } else {
              customSubtitle = Text(
                'Use another selling unit',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              );
              customTrailing = const Icon(Icons.chevron_right);
              initialValue = '';
            }

            return ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(
                'Custom unit',
                style: AppTextField.inputStyle(
                  context,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: customSubtitle,
              trailing: customTrailing,
              onTap: () async {
                final custom = await showDialog<String>(
                  context: context,
                  builder: (context) => _CustomUnitDialog(
                    initialValue: initialValue,
                  ),
                );
                if (custom == null || !context.mounted) return;
                Navigator.of(context).pop(custom);
              },
            );
          }

          final option = DebtItemUnits.common[index];
          final selected = option.value == selectedUnit;
          Widget? trailing;
          if (selected) {
            trailing = const Icon(Icons.check, color: AppColors.primaryDark);
          }
          return ListTile(
            title: Text(
              option.label,
              style: AppTextField.inputStyle(
                context,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: trailing,
            onTap: () => Navigator.of(context).pop(option.value),
          );
        },
      ),
    );
  }
}

class _CustomUnitDialog extends StatefulWidget {
  const _CustomUnitDialog({required this.initialValue});

  final String initialValue;

  @override
  State<_CustomUnitDialog> createState() => _CustomUnitDialogState();
}

class _CustomUnitDialogState extends State<_CustomUnitDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = DebtItemUnits.normalize(_controller.text);
    if (value.isEmpty) {
      setState(() => _error = 'Enter a unit name.');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Custom unit'),
      content: AppTextField(
        controller: _controller,
        label: 'Unit name *',
        hint: 'sack',
        errorText: _error,
        autofocus: true,
        textInputAction: TextInputAction.done,
        inputFormatters: [LengthLimitingTextInputFormatter(24)],
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Use unit')),
      ],
    );
  }
}
