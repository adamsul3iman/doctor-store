import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/analytics_service.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/utils/delivery_zones_provider.dart';
import 'package:doctor_store/shared/utils/network_status_provider.dart';
import 'package:doctor_store/shared/widgets/custom_app_bar.dart';
import 'package:doctor_store/shared/widgets/image_shimmer_placeholder.dart';
import 'package:doctor_store/core/theme/app_theme.dart';

// ignore_for_file: use_build_context_synchronously

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  final _couponController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  DeliveryZone? _selectedZone;

  @override
  void initState() {
    super.initState();
    final userProfile = ref.read(userProfileProvider);
    nameController = TextEditingController(text: userProfile.name);
    phoneController = TextEditingController(text: userProfile.phone);
    addressController = TextEditingController(text: userProfile.address);

    // تتبع زيارة شاشة السلة
    final cartItems = ref.read(cartProvider);
    AnalyticsService.instance.trackEvent('cart_view', props: {
      'items_count': cartItems.length,
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final coupon = ref.watch(couponProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final deliveryZonesAsync = ref.watch(deliveryZonesProvider);

    // حساب مجموع المنتجات وقيمة الخصم محلياً
    double productsTotal = cartItems.fold(
        0, (sum, item) => sum + item.activePrice * item.quantity);

    double discountAmount = 0;
    if (coupon != null) {
      if (coupon.type == 'percent') {
        discountAmount = productsTotal * (coupon.value / 100);
      } else {
        discountAmount = coupon.value;
      }
      if (discountAmount > productsTotal) {
        discountAmount = productsTotal;
      }
    }

    final double totalAfterDiscount = productsTotal - discountAmount;
    final double deliveryFee = _selectedZone?.price ?? 0;
    final double grandTotal = totalAfterDiscount + deliveryFee;

    final bool requireDeliveryZone = deliveryZonesAsync.maybeWhen(
      data: (zones) => zones.isNotEmpty,
      orElse: () => false,
    );

    return Scaffold(
      appBar: CustomAppBar(
        isHome: false,
        title: 'سلة المشتريات',
        showSearch: false,
        sharePath: '/cart',
        shareTitle: 'سلة مشترياتي من متجر الدكتور',
      ),
      body: cartItems.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined,
                      size: 80, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text("السلة فارغة",
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text("تصفح المنتجات"),
                  )
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                // نجعل محتوى السلة بالكامل قابلاً للتمرير لتجنب مشكلة BOTTOM OVERFLOWED
                // وكذلك لضمان ظهور جميع المنتجات وقسم تأكيد الطلب على الشاشات الصغيرة.
            return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildCheckoutSteps(),
                        // زر تفريغ السلة بالكامل
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'سلة المشتريات',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('تفريغ السلة'),
                                      content: const Text(
                                        'هل أنت متأكد من حذف كل المنتجات من السلة؟',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('إلغاء'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('تفريغ'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    ref
                                        .read(cartProvider.notifier)
                                        .clearCart();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text('تم تفريغ السلة'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'تفريغ السلة',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // قائمة المنتجات داخل السلة – غير قابلة للتمرير منفصلاً
                        ListView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          cacheExtent: 600,
                          itemCount: cartItems.length,
                          itemBuilder: (context, index) {
                            final item = cartItems[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: buildOptimizedImageUrl(
                                          item.product.imageUrl,
                                          variant: ImageVariant.thumbnail,
                                        ),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        memCacheHeight: 220,
                                        placeholder: (context, url) =>
                                            const ShimmerImagePlaceholder(),
                                        errorWidget:
                                            (context, url, error) =>
                                                const Icon(
                                          Icons.broken_image,
                                          size: 24,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.product.title,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                          if (item.selectedSize != null)
                                            Text(
                                                "المقاس: ${item.selectedSize} | اللون: ${item.selectedColor ?? '-'}",
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey)),
                                          Text("${item.activePrice} د.أ",
                                              style: const TextStyle(
                                                  color: Color(0xFF0A2647),
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () => ref
                                              .read(cartProvider.notifier)
                                              .decrementQuantity(item),
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red),
                                        ),
                                        Text("${item.quantity}",
                                            style: const TextStyle(
                                                fontWeight:
                                                    FontWeight.bold)),
                                        IconButton(
                                          onPressed: () => ref
                                              .read(cartProvider.notifier)
                                              .incrementQuantity(item),
                                          icon: const Icon(
                                              Icons.add_circle_outline,
                                              color: Colors.green),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        // قسم تأكيد الطلب + الإجماليات يصبح جزءاً من نفس التمرير
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, -5))
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _couponController,
                                        decoration: InputDecoration(
                                          hintText: "لديك كود خصم؟",
                                          filled: true,
                                          fillColor: Colors.grey[50],
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      onPressed: () async {
                                        if (_couponController.text.isEmpty) {
                                          return;
                                        }
                                        // ✅ حماية السياق (Context Safety)
                                        final error = await validateCoupon(
                                            ref, _couponController.text);
                                        if (!mounted) return;

                                        if (error == null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      "تم تفعيل الخصم!"),
                                                  backgroundColor:
                                                      Colors.green));
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text(error),
                                                  backgroundColor:
                                                      Colors.red));
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 18, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text("تطبيق"),
                                    ),
                                  ],
                                ),
                                if (coupon != null)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(top: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                            "كوبون مفعل: ${coupon.code}",
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontWeight:
                                                    FontWeight.bold)),
                                        const Spacer(),
                                        InkWell(
                                          onTap: () => ref
                                              .read(couponProvider.notifier)
                                              .state = null,
                                          child: const Icon(Icons.close,
                                              size: 16,
                                              color: Colors.red),
                                        )
                                      ],
                                    ),
                                  ),

                                const Divider(height: 30),

                                // اختيار منطقة التوصيل (واجهة احترافية مع بحث)
                                _buildDeliveryZonePicker(
                                    deliveryZonesAsync),

                                // تلميح صغير لتشجيع إكمال الملف الشخصي وتهيئة الدفع السريع
                                _buildProfileHint(ref),
                                _buildCodHighlightCard(),
                                const SizedBox(height: 12),

                                _buildCompactField(nameController,
                                    "الاسم الكامل", Icons.person),
                                const SizedBox(height: 10),
                                _buildCompactField(
                                    phoneController,
                                    "رقم الهاتف",
                                    Icons.phone,
                                    isNumber: true),
                                const SizedBox(height: 20),

                                // ملخص الأسعار: منتجات / خصم / توصيل / إجمالي
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "مجموع المنتجات:",
                                          style:
                                              TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          '${productsTotal.toStringAsFixed(2)} د.أ',
                                          style: const TextStyle(
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    if (discountAmount > 0)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            "الخصم:",
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors
                                                    .green),
                                          ),
                                          Text(
                                            '-${discountAmount.toStringAsFixed(2)} د.أ',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors
                                                    .green),
                                          ),
                                        ],
                                      ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "رسوم التوصيل:",
                                          style:
                                              TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          '${deliveryFee.toStringAsFixed(2)} د.أ',
                                          style: const TextStyle(
                                              fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "* رسوم التوصيل تقديرية وتختلف حسب حجم الطلب.",
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey),
                                      textAlign: TextAlign.right,
                                    ),
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          "الإجمالي النهائي:",
                                          style: TextStyle(
                                              fontWeight:
                                                  FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                        Text(
                                          '${grandTotal.toStringAsFixed(2)} د.أ',
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.bold,
                                            fontSize: 20,
                                            color:
                                                Color(0xFF0A2647),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                settingsAsync.when(
                                  data: (settings) => SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () async {
                                              if (_formKey
                                                  .currentState!
                                                  .validate()) {
                                                setState(() =>
                                                    _isSubmitting =
                                                        true);

                                                // التأكد من اختيار منطقة التوصيل إذا كانت مفعّلة في لوحة التحكم
                                                if (requireDeliveryZone &&
                                                    _selectedZone ==
                                                        null) {
                                                  ScaffoldMessenger.of(
                                                          context)
                                                      .showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                          'يرجى اختيار منطقة التوصيل قبل إتمام الطلب'),
                                                    ),
                                                  );
                                                  setState(() =>
                                                      _isSubmitting =
                                                          false);
                                                  return;
                                                }

                                                try {
                                                  await AnalyticsService
                                                      .instance
                                                      .trackEvent(
                                                          'cart_checkout_start',
                                                          props: {
                                                            'items_count':
                                                                cartItems
                                                                    .length,
                                                            'total':
                                                                grandTotal,
                                                          });

                                                  // التحقق من الاتصال قبل إرسال الطلب عبر واتساب
                                                  final netStatus = ref
                                                      .read(networkStatusProvider)
                                                      .asData
                                                      ?.value;
                                                  if (netStatus ==
                                                      NetworkStatus.offline) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'لا يوجد اتصال بالإنترنت، لا يمكن إرسال الطلب حالياً.',
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                    setState(() =>
                                                        _isSubmitting =
                                                            false);
                                                    return;
                                                  }

                                                  await ref
                                                      .read(cartProvider
                                                          .notifier)
                                                      .checkoutViaWhatsApp(
                                                        customerName:
                                                            nameController
                                                                .text,
                                                        customerPhone:
                                                            phoneController
                                                                .text,
                                                        totalAmount:
                                                            grandTotal,
                                                        productsTotal:
                                                            productsTotal,
                                                        deliveryFee:
                                                            deliveryFee,
                                                        deliveryZoneName:
                                                            _selectedZone
                                                                    ?.name ??
                                                                'غير محددة',
                                                        discountAmount:
                                                            discountAmount,
                                                        storePhone: settings
                                                            .whatsapp,
                                                        coupon: coupon,
                                                        notes: null,
                                                      );

                                                  await AnalyticsService
                                                      .instance
                                                      .trackEvent(
                                                          'cart_checkout_success',
                                                          props: {
                                                            'items_count':
                                                                cartItems
                                                                    .length,
                                                            'total':
                                                                grandTotal,
                                                          });
                                                } catch (e) {
                                                  if (mounted) {
                                                    // ✅ حماية السياق
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                            const SnackBar(
                                                      content: Text(
                                                        "حدث خطأ أثناء إتمام الطلب، حاول مرة أخرى. إذا استمر، تواصل معنا عبر واتساب.",
                                                      ),
                                                    ));
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(() =>
                                                        _isSubmitting =
                                                            false);
                                                  }
                                                }
                                              }
                                            },
                                      icon: const FaIcon(
                                          FontAwesomeIcons.whatsapp),
                                      label: _isSubmitting
                                          ? const Text(
                                              "جاري التنفيذ...")
                                          : const Text(
                                              "تأكيد الطلب عبر واتساب"),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF25D366),
                                        foregroundColor:
                                            Colors.white,
                                        padding: const EdgeInsets
                                            .symmetric(vertical: 15),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(
                                                    12)),
                                      ),
                                    ),
                                  ),
                                  loading: () => const Center(
                                      child:
                                          CircularProgressIndicator()),
                                  error: (e, s) => const Text(
                                      "تأكد من الاتصال بالإنترنت"),
                                ),
                                const SizedBox(height: 6),
                                const Align(
                                  alignment: Alignment.center,
                                  child: Text(
                                    'يمكنك إتمام الطلب كضيف الآن، والدفع يكون عند الاستلام.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCheckoutSteps() {
    const activeColor = AppTheme.primary;
    final inactiveColor = Colors.grey.shade400;

    Widget buildStep({
      required IconData icon,
      required String label,
      required bool isActive,
    }) {
      final color = isActive ? activeColor : inactiveColor;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: buildStep(
              icon: Icons.shopping_cart,
              label: 'السلة',
              isActive: true,
            ),
          ),
          Expanded(
            child: buildStep(
              icon: Icons.person,
              label: 'بيانات التواصل',
              isActive: true,
            ),
          ),
          Expanded(
            child: buildStep(
              icon: Icons.check_circle_outline,
              label: 'تأكيد الطلب',
              isActive: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHint(WidgetRef ref) {
    final user = ref.watch(userProfileProvider);
    final percent = user.completionPercent;

    if (user.isGuest) {
      return const Text(
        'أكمل طلبك كضيف الآن، ويمكنك إنشاء حساب لاحقاً لحفظ بياناتك للطلبات القادمة.',
        style: TextStyle(fontSize: 11, color: Colors.grey),
      );
    }

    return Text(
      percent < 1.0
          ? 'تم تعبئة بياناتك تلقائياً من ملفك الشخصي، يمكنك تعديلها هنا وسيتم حفظها للمرات القادمة.'
          : 'بياناتك مخزنة وآمنة، يمكنك إتمام الطلب بنقرة واحدة تقريباً.',
      style: const TextStyle(fontSize: 11, color: Colors.grey),
    );
  }

  /// ويدجت اختيار منطقة التوصيل مع مربع بحث داخل BottomSheet
  Widget _buildDeliveryZonePicker(
      AsyncValue<List<DeliveryZone>> deliveryZonesAsync) {
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
              decoration: const InputDecoration(
                labelText: 'منطقة التوصيل',
                hintText: 'اختر المدينة / المنطقة',
                prefixIcon: Icon(Icons.delivery_dining),
                border: OutlineInputBorder(),
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
                      decoration: const InputDecoration(
                        hintText: 'ابحث بالمدينة أو المنطقة...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
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
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final zone = filtered[index];
                                final isSelected = _selectedZone?.id == zone.id;
                                return ListTile(
                                  title: Text(zone.name),
                                  subtitle: Text(
                                    'رسوم التوصيل: ${zone.price.toStringAsFixed(2)} د.أ',
                                  ),
                                  trailing: isSelected
                                      ? const Icon(Icons.check,
                                          color: Color(0xFF0A2647))
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

  Widget _buildCodHighlightCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
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
              'الدفع عند الاستلام – سيتم تأكيد طلبك عبر واتساب أولاً.',
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

  Widget _buildCompactField(
      TextEditingController controller, String hint, IconData icon,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      validator: (value) => value!.isEmpty ? "هذا الحقل مطلوب" : null,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

