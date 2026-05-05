import 'package:flutter/material.dart';
import '../../../domain/models/product_model.dart';

class ProductVariantSelector extends StatefulWidget {
  final Product product;
  final String? initialColor;
  final String? initialSize;
  final ValueChanged<String?>? onColorChanged;
  final ValueChanged<String?>? onSizeChanged;
  final VoidCallback? onImageScrollRequest;

  const ProductVariantSelector({
    super.key,
    required this.product,
    this.initialColor,
    this.initialSize,
    this.onColorChanged,
    this.onSizeChanged,
    this.onImageScrollRequest,
  });

  @override
  State<ProductVariantSelector> createState() => _ProductVariantSelectorState();
}

class _ProductVariantSelectorState extends State<ProductVariantSelector> {
  String? _selectedColor;
  String? _selectedSize;

  List<String> get _colors {
    final raw = widget.product.options['colors'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    final values = <String>{};
    for (final v in widget.product.variants) {
      final c = v.color?.trim();
      if (c != null && c.isNotEmpty) values.add(c);
    }
    return values.toList();
  }

  List<String> get _sizes {
    final raw = widget.product.options['sizes'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    final values = <String>{};
    for (final v in widget.product.variants) {
      final s = v.size?.trim();
      if (s != null && s.isNotEmpty) values.add(s);
    }
    return values.toList();
  }
  bool get _hasColors => _colors.isNotEmpty;
  bool get _hasSizes => _sizes.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _selectedSize = widget.initialSize;
  }

  void _onColorSelected(String color) {
    final willSelect = _selectedColor != color;
    setState(() {
      _selectedColor = willSelect ? color : null;
    });
    if (willSelect) {
      widget.onImageScrollRequest?.call();
    }
    widget.onColorChanged?.call(_selectedColor);
  }

  void _onSizeSelected(String size) {
    final willSelect = _selectedSize != size;
    setState(() {
      _selectedSize = willSelect ? size : null;
    });
    widget.onSizeChanged?.call(_selectedSize);
  }

  ProductVariant? get selectedVariant {
    if (!_hasColors && !_hasSizes) return null;
    try {
      return widget.product.variants.firstWhere(
        (v) {
          final colorMatch = !_hasColors || v.color == _selectedColor;
          final sizeMatch = !_hasSizes || v.size == _selectedSize;
          return colorMatch && sizeMatch;
        },
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryDark = const Color(0xFF1A5F7A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasColors) ...[
          _buildSection(
            title: 'اختر اللون',
            isColor: true,
            options: _colors,
            selectedValue: _selectedColor,
            primaryDark: primaryDark,
          ),
          const SizedBox(height: 16),
        ],
        if (_hasSizes) ...[
          _buildSection(
            title: 'اختر المقاس',
            isColor: false,
            options: _sizes,
            selectedValue: _selectedSize,
            primaryDark: primaryDark,
          ),
          const SizedBox(height: 16),
        ],
        if (selectedVariant?.stock != null && selectedVariant!.stock! <= 3)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(
                  'تبقى ${selectedVariant!.stock} قطع فقط!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required bool isColor,
    required List<String> options,
    required String? selectedValue,
    required Color primaryDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: primaryDark,
              ),
            ),
            const SizedBox(width: 8),
            if (isColor && _selectedColor != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedColor!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (selectedValue == null)
              Text(
                ' * (مطلوب)',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        if (isColor)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'اضغط على اللون لاستعراض صورته والاختيار',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        const SizedBox(height: 12),
        if (isColor)
          Wrap(
            spacing: 12,
            runSpacing: 14,
            children: options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = selectedValue == option;
              final color = _resolveColor(option, index);
              return GestureDetector(
                onTap: () => _onColorSelected(option),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? primaryDark : Colors.grey.shade300,
                          width: isSelected ? 2 : 1.2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: primaryDark.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 64,
                      child: Text(
                        option,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? primaryDark : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final isSelected = selectedValue == option;
              return GestureDetector(
                onTap: () => _onSizeSelected(option),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryDark : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? primaryDark : Colors.grey.shade300,
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey.shade800,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Color _resolveColor(String optionStr, int index) {
    for (final img in widget.product.gallery) {
      if (img.colorName.toLowerCase() == optionStr.toLowerCase()) {
        try {
          return Color(img.colorValue);
        } catch (_) {}
      }
    }
    final fallbackColors = [
      Colors.red, Colors.blue, Colors.green, Colors.yellow,
      Colors.purple, Colors.orange, Colors.teal, Colors.pink,
    ];
    return fallbackColors[index % fallbackColors.length];
  }
}

class VariantSelectionDialog extends StatefulWidget {
  final Product product;
  final String? initialColor;
  final String? initialSize;
  final int initialQuantity;
  final ValueChanged<VariantSelectionResult>? onConfirm;

  const VariantSelectionDialog({
    super.key,
    required this.product,
    this.initialColor,
    this.initialSize,
    this.initialQuantity = 1,
    this.onConfirm,
  });

  @override
  State<VariantSelectionDialog> createState() => _VariantSelectionDialogState();
}

class _VariantSelectionDialogState extends State<VariantSelectionDialog> {
  String? _selectedColor;
  String? _selectedSize;
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _selectedSize = widget.initialSize;
    _quantity = widget.initialQuantity;
  }

  ProductVariant? get _selectedVariant {
    final hasColors = _hasColorOptions;
    final hasSizes = _hasSizeOptions;
    if (!hasColors && !hasSizes) return null;
    try {
      return widget.product.variants.firstWhere((v) {
        final colorMatch = !hasColors || v.color == _selectedColor;
        final sizeMatch = !hasSizes || v.size == _selectedSize;
        return colorMatch && sizeMatch;
      });
    } catch (_) {
      return null;
    }
  }

  bool get _canConfirm {
    final hasColors = _hasColorOptions;
    final hasSizes = _hasSizeOptions;
    final colorSelected = !hasColors || _selectedColor != null;
    final sizeSelected = !hasSizes || _selectedSize != null;
    return colorSelected && sizeSelected;
  }

  bool get _hasColorOptions {
    final colors = widget.product.options['colors'];
    if (colors is List && colors.isNotEmpty) return true;
    return widget.product.variants.any(
      (variant) => variant.color != null && variant.color!.trim().isNotEmpty,
    );
  }

  bool get _hasSizeOptions {
    final sizes = widget.product.options['sizes'];
    if (sizes is List && sizes.isNotEmpty) return true;
    if (widget.product.hasSizeOptions) return true;
    return widget.product.variants.any((variant) {
      if (variant.size != null && variant.size!.trim().isNotEmpty) return true;
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ProductVariantSelector(
                product: widget.product,
                initialColor: _selectedColor,
                initialSize: _selectedSize,
                onColorChanged: (color) => setState(() => _selectedColor = color),
                onSizeChanged: (size) => setState(() => _selectedSize = size),
              ),
              const SizedBox(height: 16),
              _buildQuantitySection(),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canConfirm
                      ? () {
                          final result = VariantSelectionResult(
                            color: _selectedColor,
                            size: _selectedSize,
                            quantity: _quantity,
                            variant: _selectedVariant,
                          );
                          widget.onConfirm?.call(result);
                          Navigator.of(context).pop(result);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5F7A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'تأكيد الاختيار',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySection() {
    final unitLabel = widget.product.pricingUnitLabel;
    final stock = _selectedVariant?.stock;
    final hasStockLimit = stock != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الكمية',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity = _quantity - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_quantity $unitLabel',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: !hasStockLimit || (stock > 0 && _quantity < stock)
                    ? () => setState(() => _quantity = _quantity + 1)
                    : null,
              ),
            ],
          ),
        ),
        if (hasStockLimit)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hasStockLimit && stock > 0
                  ? 'المخزون المتاح: $stock $unitLabel'
                  : 'غير متوفر حالياً',
              style: TextStyle(
                fontSize: 12,
                color: stock > 0 ? Colors.grey.shade600 : Colors.red,
              ),
            ),
          ),
      ],
    );
  }
}

class VariantSelectionResult {
  final String? color;
  final String? size;
  final int quantity;
  final ProductVariant? variant;

  const VariantSelectionResult({
    this.color,
    this.size,
    required this.quantity,
    this.variant,
  });
}
