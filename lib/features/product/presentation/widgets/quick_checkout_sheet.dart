import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/app_notifier.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/delivery_zones_provider.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';

const _brandColor = Color(0xFF0A2647);

class QuickCheckoutSheet extends ConsumerStatefulWidget {
  final Product product;
  final int quantity;
  final String? selectedColor;
  final String? selectedSize;
  final String storePhone;
  final double unitPrice; // قد يكون سعر عرض أو السعر الأساسي

  /// في حال أردنا تمرير عدة اختيارات لنفس المنتج (ألوان/مقاسات متعددة)
  /// يتم تفعيل هذا عبر isMulti = true واستخدام قائمة الأسطر [lines].
  final bool isMulti;
  final List<QuickCheckoutLine>? lines;

  const QuickCheckoutSheet({
    super.key,
    required this.product,
    required this.quantity,
    required this.selectedColor,
    required this.selectedSize,
    required this.storePhone,
    required this.unitPrice,
    this.isMulti = false,
    this.lines,
  });

  @override
  ConsumerState<QuickCheckoutSheet> createState() => _QuickCheckoutSheetState();
}

class _QuickCheckoutSheetState extends ConsumerState<QuickCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  final _couponCtrl = TextEditingController();

  late int _sheetQuantity;

  bool get _isMulti => widget.isMulti && (widget.lines?.isNotEmpty ?? false);

  int get _totalQuantity {
    if (_isMulti) {
      return widget.lines!.fold<int>(0, (sum, line) => sum + line.quantity);
    }
    return _sheetQuantity;
  }

  double get _productsTotal {
    if (_isMulti) {
      return widget.lines!.fold<double>(
        0,
        (sum, line) => sum + (line.unitPrice * line.quantity),
      );
    }
    return widget.unitPrice * _sheetQuantity;
  }

  Coupon? _appliedCoupon;
  bool _isValidatingCoupon = false;
  bool _isSubmitting = false;

  DeliveryZone? _selectedZone;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProfileProvider);
    _nameCtrl = TextEditingController(text: user.name);
    _phoneCtrl = TextEditingController(text: user.phone);
    _addressCtrl = TextEditingController(text: user.address);
    _sheetQuantity = widget.quantity;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  double get _totalPrice {
    double base = _productsTotal;
    if (_appliedCoupon != null) {
      if (_appliedCoupon!.type == 'percent') {
        base -= base * (_appliedCoupon!.value / 100);
      } else {
        base -= _appliedCoupon!.value;
      }
    }
    if (base < 0) base = 0;

    final shipping = _selectedZone?.price ?? 0;
    return base + shipping;
  }

  Future<void> _applyCoupon() async {
    if (_couponCtrl.text.isEmpty) return;

    setState(() => _isValidatingCoupon = true);

    // استخدام الدالة العامة من cart_manager.dart
    final error = await validateCoupon(ref, _couponCtrl.text);

    if (!mounted) return;

    setState(() => _isValidatingCoupon = false);

    if (error == null) {
      // نجاح: نأخذ الكوبون من الـ Provider الذي تم تحديثه بواسطة validateCoupon
      setState(() => _appliedCoupon = ref.read(couponProvider.notifier).state);
      AppNotifier.showSuccess(context, "تم تطبيق الكوبون بنجاح");
    } else {
      AppNotifier.showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // لحساب ارتفاع الكيبورد
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final deliveryZonesAsync = ref.watch(deliveryZonesProvider);
    final bool requireDeliveryZone = deliveryZonesAsync.maybeWhen(
      data: (zones) => zones.isNotEmpty,
      orElse: () => false,
    );

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProductHeader(context),
                const SizedBox(height: 10),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        "إتمام الطلب خلال أقل من دقيقة",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 4),
                      Text(
                        "الدفع عند الاستلام – لن يتم سحب أي مبلغ الآن.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 24),

                // اختيار منطقة التوصيل (واجهة احترافية مع بحث)
                _buildDeliveryZonePicker(deliveryZonesAsync),

                const SizedBox(height: 8),
                _buildCouponRow(),

                const SizedBox(height: 14),

                const Text(
                  "بيانات التواصل",
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildField(_nameCtrl, "الاسم الكامل", Icons.person),
                const SizedBox(height: 10),
                _buildField(_phoneCtrl, "رقم الهاتف", Icons.phone, isNumber: true),

                const SizedBox(height: 18),

                // بطاقة تبرز الدفع عند الاستلام أعلى ملخص التكلفة
                _buildCodHighlightCard(),
                const SizedBox(height: 10),

                _buildSummaryCard(requireDeliveryZone),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _onSubmit(requireDeliveryZone),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.whatsapp),
                    label: _isSubmitting
                        ? const Text("جاري تجهيز الرسالة...")
                        : Text(
                            "إتمام الطلب عبر واتساب • ${_totalPrice.toStringAsFixed(1)} د.أ",
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.center,
                  child: Text(
                    "سيتم فتح واتساب برسالة جاهزة، وتأكيد الطلب يكون بالدفع عند الاستلام.",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTrustRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: buildOptimizedImageUrl(
              widget.product.imageUrl,
              variant: ImageVariant.thumbnail,
            ),
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            memCacheHeight: 200,
            placeholder: (context, url) => const ShimmerImagePlaceholder(),
            errorWidget: (context, url, error) => const Icon(
              Icons.broken_image,
              size: 20,
              color: Colors.grey,
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              if (_isMulti)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إجمالي المنتجات: ${_productsTotal.toStringAsFixed(1)} د.أ',
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'عدد القطع: $_totalQuantity ${widget.product.pricingUnitLabel}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        "${widget.unitPrice.toStringAsFixed(1)} د.أ / ${widget.product.pricingUnitLabel}",
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: _sheetQuantity > 1
                                ? () => setState(() => _sheetQuantity--)
                                : null,
                            child: Icon(
                              Icons.remove,
                              size: 16,
                              color: _sheetQuantity > 1 ? Colors.grey[700] : Colors.grey[400],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '$_sheetQuantity',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => setState(() => _sheetQuantity++),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildTrustRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        _TrustItem(icon: FontAwesomeIcons.shieldHalved, title: 'دفع آمن', subtitle: 'معلوماتك محمية'),
        SizedBox(width: 18),
        _TrustItem(icon: FontAwesomeIcons.truckFast, title: 'شحن سريع', subtitle: 'توصيل موثوق'),
        SizedBox(width: 18),
        _TrustItem(icon: FontAwesomeIcons.headset, title: 'دعم', subtitle: 'خدمة عملاء عبر الواتساب'),
      ],
    );
  }

  Widget _buildCouponRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: TextField(
            controller: _couponCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyCoupon(),
            decoration: InputDecoration(
              hintText: "كود خصم (إن وجد)",
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brandColor, width: 1.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: _isValidatingCoupon
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : (_appliedCoupon != null
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(
                            onPressed: _applyCoupon,
                            child: const Text(
                              "تطبيق",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          )),
              ),
            ),
          ),
        ),
        if (_appliedCoupon != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              "خصم مفعل: ${_appliedCoupon!.code}",
              style: const TextStyle(color: Colors.green, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildCodHighlightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF66BB6A)),
      ),
      child: Row(
        children: const [
          Icon(Icons.payments_outlined, color: Color(0xFF2E7D32), size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              "الدفع عند الاستلام – يمكنك مراجعة الطلب مع فريقنا قبل الدفع.",
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF1B5E20),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool requireDeliveryZone) {
    final productsTotal = _productsTotal;
    double discountAmount = 0;
    if (_appliedCoupon != null) {
      if (_appliedCoupon!.type == 'percent') {
        discountAmount = productsTotal * (_appliedCoupon!.value / 100);
      } else {
        discountAmount = _appliedCoupon!.value;
      }
      if (discountAmount > productsTotal) {
        discountAmount = productsTotal;
      }
    }

    final deliveryFee = _selectedZone?.price ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "ملخص التكلفة",
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          // رسالة ضمان بسيطة تطمئن العميل أثناء الإتمام
          const Text(
            "لن يتم سحب أي مبلغ الآن – سيتم تأكيد طلبك أولاً عبر الواتساب.",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          _summaryRow("إجمالي المنتجات", "${productsTotal.toStringAsFixed(1)} د.أ"),
          if (_appliedCoupon != null)
            _summaryRow("الخصم", "-${discountAmount.toStringAsFixed(1)} د.أ"),
          _summaryRow(
            "رسوم التوصيل",
            _selectedZone != null
                ? "${deliveryFee.toStringAsFixed(1)} د.أ (${_selectedZone!.name})"
                : (requireDeliveryZone
                    ? "يرجى اختيار منطقة التوصيل"
                    : "تحدد حسب المدينة"),
          ),
          const Divider(height: 16),
          _summaryRow(
            "الإجمالي المستحق",
            "${_totalPrice.toStringAsFixed(1)} د.أ",
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? _brandColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit(bool requireDeliveryZone) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // لم نعد نمنع الإرسال تماماً عند عدم اختيار منطقة التوصيل
    // إذا كانت المناطق مفعّلة وتم تركها فارغة، سنستمر مع وضع "غير محددة"
    // وسيقوم فريق خدمة العملاء بتأكيد الرسوم بعد فتح الواتساب.

      try {
        final productsTotal = _productsTotal;
      double discountAmount = 0;
      if (_appliedCoupon != null) {
        if (_appliedCoupon!.type == 'percent') {
          discountAmount = productsTotal * (_appliedCoupon!.value / 100);
        } else {
          discountAmount = _appliedCoupon!.value;
        }
        if (discountAmount > productsTotal) {
          discountAmount = productsTotal;
        }
      }
      final deliveryFee = _selectedZone?.price ?? 0;

      if (_isMulti) {
        // نمط عدة اختيارات لنفس المنتج
        final lines = widget.lines ?? const [];
        final customItems = lines
            .map(
              (line) => CustomCheckoutItem(
                product: widget.product,
                quantity: line.quantity,
                selectedSize: line.size,
                selectedColor: line.color,
                unitPrice: line.unitPrice,
              ),
            )
            .toList();

        await ref.read(cartProvider.notifier).checkoutCustomItemsViaWhatsApp(
              items: customItems,
              customerName: _nameCtrl.text,
              customerPhone: _phoneCtrl.text,
              storePhone: widget.storePhone,
              productsTotal: productsTotal,
              deliveryFee: deliveryFee,
              deliveryZoneName: _selectedZone?.name ?? 'غير محددة',
              discountAmount: discountAmount,
              coupon: _appliedCoupon,
              notes: null,
            );
      } else {
        // السلوك القديم: منتج واحد
        await ref.read(cartProvider.notifier).checkoutSingleProductViaWhatsApp(
              product: widget.product,
              quantity: _sheetQuantity,
              size: widget.selectedSize,
              color: widget.selectedColor,
              price: widget.unitPrice,
              customerName: _nameCtrl.text,
              customerPhone: _phoneCtrl.text,
              storePhone: widget.storePhone,
              productsTotal: productsTotal,
              deliveryFee: deliveryFee,
              deliveryZoneName: _selectedZone?.name ?? 'غير محددة',
              discountAmount: discountAmount,
              coupon: _appliedCoupon,
              notes: null,
            );
      }

      if (mounted) {
        Navigator.pop(context);
        AppNotifier.showSuccess(
          context,
          "تم تجهيز طلبك وفتح واتساب للتأكيد النهائي.",
        );
      }
    } catch (e) {
      if (mounted) {
        AppNotifier.showError(
          context,
          "تعذّر إرسال الطلب حالياً، تحقق من الاتصال أو جرّب مرة أخرى بعد قليل.",
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildDeliveryZonePicker(AsyncValue<List<DeliveryZone>> deliveryZonesAsync) {
    return deliveryZonesAsync.when(
      data: (zones) {
        if (zones.isEmpty) return const SizedBox.shrink();

        final selectedName = _selectedZone?.name ?? 'اختر منطقة التوصيل';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _openDeliveryZoneBottomSheet(zones),
            borderRadius: BorderRadius.circular(8),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'منطقة التوصيل',
                hintText: 'اختر المدينة / المنطقة',
                prefixIcon: const Icon(Icons.delivery_dining),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _brandColor, width: 1.4),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      selectedName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Future<void> _openDeliveryZoneBottomSheet(List<DeliveryZone> zones) async {
    final searchController = TextEditingController();
    List<DeliveryZone> filtered = List.from(zones);

    final selected = await showModalBottomSheet<DeliveryZone>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 16,
            right: 16,
            left: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              void onSearch(String value) {
                final query = value.trim();
                setModalState(() {
                  if (query.isEmpty) {
                    filtered = List.from(zones);
                  } else {
                    filtered = zones
                        .where((z) =>
                            z.name.contains(query) ||
                            z.price.toString().contains(query))
                        .toList();
                  }
                });
              }

              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر منطقة التوصيل',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: onSearch,
                      decoration: InputDecoration(
                        hintText: 'ابحث بالمدينة أو المنطقة...',
                        prefixIcon: const Icon(Icons.search),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: _brandColor, width: 1.4),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text('لا توجد نتائج مطابقة'),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final zone = filtered[index];
                                final isSelected = _selectedZone?.id == zone.id;
                                return ListTile(
                                  title: Text(zone.name),
                                  subtitle: Text(
                                    'رسوم التوصيل: ${zone.price.toStringAsFixed(2)} د.أ',
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check, color: Color(0xFF0A2647))
                                      : null,
                                  onTap: () => Navigator.of(context).pop(zone),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedZone = selected;
      });
    }
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon, {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      validator: (val) => val!.isEmpty ? "مطلوب" : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 18, color: Colors.grey[600]),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: _brandColor, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
      ),
    );
  }
}

class QuickCheckoutLine {
  final String? color;
  final String? size;
  final int quantity;
  final double unitPrice;

  const QuickCheckoutLine({
    required this.color,
    required this.size,
    required this.quantity,
    required this.unitPrice,
  });
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: FaIcon(
            icon,
            size: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
