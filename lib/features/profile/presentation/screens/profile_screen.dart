import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/image_compressor.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/shared/utils/wishlist_manager.dart';
import 'package:doctor_store/shared/services/analytics_service.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import '../widgets/edit_profile_sheet.dart';

// ignore_for_file: use_build_context_synchronously

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("حسابي", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        // تمت إزالة زر القائمة (الهامبرغر) لعدم الحاجة إليه في هذه الشاشة
      ),
      body: user.isGuest
          ? _buildGuestView(context, ref)
          : RefreshIndicator(
              onRefresh: () async {
                await ref.read(userProfileProvider.notifier).refreshProfile();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 1. كارت المعلومات الشخصية
                    _buildProfileHeader(
                      user,
                      context,
                      () => _changeAvatar(context, ref),
                    ),

                    const SizedBox(height: 16),

                    // 1.1 شريط اكتمال الملف الشخصي + تلميح تسويقي
                    _buildProfileCompletionBar(user, context),

                    const SizedBox(height: 30),

                    // 2.5 لمحات سريعة عن المفضلة والسلة لتحفيز الشراء
                    _buildFunnelQuickActions(context, ref, user),

                    const SizedBox(height: 24),

                    // قسم: حسابي (البيانات الشخصية والأمان)
                    _buildSectionTitle("حسابي"),
                    _buildCard(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person_outline,
                          title: "تعديل البيانات",
                          subtitle: "الاسم، الهاتف، العنوان",
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const EditProfileSheet(),
                          ),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.email_outlined,
                          title: "البريد الإلكتروني",
                          subtitle: "تحديث بريد تسجيل الدخول",
                          onTap: () => _showChangeEmailDialog(context, ref),
                        ),
                        _buildDivider(),
                        _buildMenuItem(
                          icon: Icons.lock_outline,
                          title: "كلمة المرور",
                          subtitle: "تغيير/إعادة تعيين",
                          onTap: () => _showChangePasswordDialog(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // قسم: نشاطي (الطلبات)
                    _buildSectionTitle("نشاطي"),
                    _buildCard(
                      children: [
                        _buildMenuItem(
                          icon: FontAwesomeIcons.boxOpen,
                          title: "طلباتي السابقة",
                          subtitle: "تتبع حالة طلباتك وتاريخ الشراء",
                          showBadge: user.totalOrders > 0,
                          badgeText: "${user.totalOrders}",
                          onTap: () => context.push('/orders'),
                        ),
                      ],
                    ),

                    // لوحة التحكم للمشرف (إن وجدت)
                    if (user.isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildSectionTitle("إدارة المتجر"),
                      _buildCard(
                        children: [
                          _buildMenuItem(
                            icon: Icons.dashboard_outlined,
                            title: "لوحة التحكم",
                            subtitle: "إدارة المنتجات والطلبات والإحصائيات",
                            isHighLighted: true,
                            onTap: () => context.push('/admin/dashboard'),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 32),

                    // قسم: إدارة الحساب (في الأسفل وبشكل أقل وضوحاً)
                    _buildSectionTitle("إدارة الحساب", color: Colors.grey),
                    _buildCard(
                      backgroundColor: Colors.grey[50],
                      children: [
                        // تسجيل الخروج
                        _buildMenuItem(
                          icon: Icons.logout,
                          title: "تسجيل الخروج",
                          subtitle: "العودة للتصفح كضيف",
                          iconColor: Colors.orange[700],
                          onTap: () async {
                            final shouldLogout = await _showLogoutConfirmDialog(context);
                            if (!shouldLogout) return;
                            await ref.read(userProfileProvider.notifier).logout();
                            if (context.mounted) context.go('/');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // حذف الحساب - في أسفل الصفحة كنص صغير غير بارز
                    Center(
                      child: TextButton.icon(
                        onPressed: () => _showDeleteAccountDialog(context, ref),
                        icon: Icon(Icons.delete_outline, size: 16, color: Colors.grey[500]),
                        label: Text(
                          "حذف الحساب نهائياً",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGuestView(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_circle_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text(
              "أنت تتصفح كزائر",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "يمكنك الطلب كضيف بسهولة، لكن إنشاء حساب يساعدك على تتبع طلباتك وحفظ العناوين والمفضلة.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                AnalyticsService.instance.trackEvent('profile_guest_go_to_login');
                // تحويل الزائر إلى صفحة تسجيل الدخول الموحدة /login
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2647),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text("تسجيل الدخول / إنشاء حساب"),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                AnalyticsService.instance.trackEvent('profile_continue_as_guest');
                if (cartItems.isNotEmpty) {
                  context.go('/cart');
                } else {
                  context.go('/');
                }
              },
              child: Text(
                cartItems.isNotEmpty
                    ? "إكمال الطلب كضيف بدون إنشاء حساب"
                    : "تصفح المنتجات كضيف بدون إنشاء حساب",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0A2647),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
    UserProfile user,
    BuildContext context,
    VoidCallback onChangeAvatar,
  ) {
    final displayName = user.name.trim().isNotEmpty
        ? user.name.trim()
        : (user.email.trim().isNotEmpty
            ? user.email.trim().split('@').first
            : 'User');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2647), Color(0xFF163A5F)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onChangeAvatar,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  backgroundImage: user.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(
                          buildOptimizedImageUrl(
                            user.avatarUrl,
                            variant: ImageVariant.thumbnail,
                          ),
                        )
                      : null,
                  child: user.avatarUrl.isNotEmpty
                      ? null
                      : Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : "U",
                          style: const TextStyle(
                            fontSize: 26,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                Positioned(
                  bottom: -2,
                  left: -2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onChangeAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 14,
                        color: Color(0xFF0A2647),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                if (user.email.isNotEmpty)
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                if (user.phone.isNotEmpty)
                  Text(
                    user.phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        width: constraints.maxWidth,
                        child: Row(
                          children: [
                            Flexible(
                              flex: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified, color: Color(0xFFD4AF37), size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'عميل متجر الدكتور',
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (user.totalOrders > 0)
                              Expanded(
                                child: Text(
                                  '${user.totalOrders} طلب حتى الآن',
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCompletionBar(UserProfile user, BuildContext context) {
    final percent = user.completionPercent;
    final percentText = '${(percent * 100).round()}%';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: Color(0xFF0A2647)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اكتمال ملفك الشخصي: $percentText',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percent,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF0A2647)),
                ),
                const SizedBox(height: 6),
                Text(
                  percent < 1.0
                      ? 'أكمل بياناتك لتحصل على توصيات أدق وشحن أسرع في طلباتك القادمة.'
                      : 'ملفك مكتمل، يمكنك الطلب بسهولة تامة وبنقرة واحدة.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          if (percent < 1.0)
            TextButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const EditProfileSheet(),
                );
              },
              child: const Text('إكمال', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildFunnelQuickActions(BuildContext context, WidgetRef ref, UserProfile user) {
    final wishlistIds = ref.watch(wishlistProvider);
    final cartItems = ref.watch(cartProvider);

    if (wishlistIds.isEmpty && cartItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جاهز تكمل طلبك؟',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (wishlistIds.isNotEmpty)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite, color: Colors.redAccent),
              title: Text(
                'لديك ${wishlistIds.length} منتج في المفضلة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('راجع مفضلتك واضف المنتجات للسلة بخطوة واحدة', style: TextStyle(fontSize: 11)),
              trailing: TextButton(
                onPressed: () {
                  AnalyticsService.instance.trackEvent('open_wishlist_from_profile');
                  context.push('/wishlist');
                },
                child: const Text('عرض', style: TextStyle(fontSize: 12)),
              ),
            ),
          if (cartItems.isNotEmpty)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_cart, color: Color(0xFF0A2647)),
              title: Text(
                'سلتك جاهزة ب${cartItems.length} منتج',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('انتقل للسلة وأكمل الطلب عبر واتساب خلال دقيقة', style: TextStyle(fontSize: 11)),
              trailing: TextButton(
                onPressed: () {
                  AnalyticsService.instance.trackEvent('open_cart_from_profile');
                  context.push('/cart');
                },
                child: const Text('إكمال الشراء', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isHighLighted = false,
    bool showBadge = false,
    String? badgeText,
    Color? iconColor,
  }) {
    final Color effectiveIconColor = iconColor ?? (isDestructive ? Colors.red : (isHighLighted ? const Color(0xFF0A2647) : const Color(0xFF5A6C7D)));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive ? Colors.red.withValues(alpha: 0.08) : (isHighLighted ? const Color(0xFF0A2647).withValues(alpha: 0.08) : const Color(0xFFEEF2F5)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: effectiveIconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600, 
                        fontSize: 14, 
                        color: isDestructive ? Colors.red[700] : Colors.black87,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle, 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey[500],
                          height: 1.3,
                        ),
                      ),
                  ],
                ),
              ),
              if (showBadge && badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A2647),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 11, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color ?? const Color(0xFF0A2647),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color ?? const Color(0xFF0A2647),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children, Color? backgroundColor}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2647).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(
          color: backgroundColor == null 
            ? Colors.grey.withValues(alpha: 0.08) 
            : Colors.transparent,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 66,
      endIndent: 16,
      color: Colors.grey[100],
    );
  }

  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider);
    if (user.isGuest || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل دخولك أولاً لتعيين صورة شخصية')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedImage = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedImage == null) return;

    // حوار تحميل صغير أثناء رفع الصورة
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final originalBytes = await pickedImage.readAsBytes();
      final originalExt = pickedImage.name.split('.').last;

      // ضغط الصورة قبل الرفع لتقليل الحجم (WebP + max 1024px + ~1MB)
      final compressed = await AppImageCompressor.compress(
        originalBytes,
        originalExtension: originalExt,
      );

      final supabase = Supabase.instance.client;
      final ext = compressed.extension;
      final path = '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      await supabase.storage.from('avatars').uploadBinary(
            path,
            compressed.bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: ext == 'webp' ? 'image/webp' : 'image/jpeg',
            ),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(path);

      await ref.read(userProfileProvider.notifier).updateAvatar(publicUrl);

      if (context.mounted) {
        Navigator.of(context).pop(); // إغلاق حوار التحميل
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث صورتك الشخصية'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء رفع الصورة، حاول مرة أخرى لاحقاً. (تفاصيل تقنية: $e)'),
          ),
        );
      }
    }
  }

  Future<void> _showChangeEmailDialog(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider);
    if (user.isGuest || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل دخولك أولاً لتعديل بريدك الإلكتروني')),
      );
      return;
    }

    final emailController = TextEditingController(text: user.email);
    String? errorMessage;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'تعديل البريد الإلكتروني',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني الجديد',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'قد يرسل Supabase رسالة تأكيد إلى بريدك الجديد قبل اعتماد التغيير.',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final newEmail = emailController.text.trim();
                          if (newEmail.isEmpty || !newEmail.contains('@')) {
                            setState(() {
                              errorMessage = 'يرجى إدخال بريد إلكتروني صالح';
                            });
                            return;
                          }

                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final supabase = Supabase.instance.client;
                            await supabase.auth.updateUser(
                              UserAttributes(email: newEmail),
                            );

                            await ref.read(userProfileProvider.notifier).refreshProfile();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم تحديث البريد الإلكتروني بنجاح'),
                                ),
                              );
                            }

                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }
                          } on AuthException catch (e) {
                            setState(() {
                              errorMessage = e.message;
                            });
                          } catch (_) {
                            setState(() {
                              errorMessage =
                                  'حدث خطأ أثناء تحديث البريد الإلكتروني، حاول مرة أخرى.';
                            });
                          } finally {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                'تغيير كلمة المرور',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      prefixIcon: Icon(Icons.lock_reset),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final pass = passwordController.text.trim();
                          final confirm = confirmController.text.trim();

                          if (pass.isEmpty || pass.length < 6) {
                            setState(() {
                              errorMessage =
                                  'يرجى إدخال كلمة مرور لا تقل عن 6 أحرف / أرقام';
                            });
                            return;
                          }
                          if (pass != confirm) {
                            setState(() {
                              errorMessage = 'كلمتا المرور غير متطابقتين';
                            });
                            return;
                          }

                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final supabase = Supabase.instance.client;
                            await supabase.auth.updateUser(
                              UserAttributes(password: pass),
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم تحديث كلمة المرور بنجاح'),
                                ),
                              );
                            }

                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop();
                            }
                          } on AuthException catch (e) {
                            setState(() {
                              errorMessage = e.message;
                            });
                          } catch (_) {
                            setState(() {
                              errorMessage =
                                  'حدث خطأ أثناء تحديث كلمة المرور، حاول مرة أخرى.';
                            });
                          } finally {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showDeleteAccountDialog(
      BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider);
    if (user.isGuest || user.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يجب تسجيل الدخول أولاً قبل حذف الحساب'),
        ),
      );
      return;
    }

    bool isLoading = false;
    String? errorMessage;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: Text(
                'حذف الحساب نهائياً',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سيتم حذف حسابك وجميع بياناتك المرتبطة بشكل نهائي وفقاً لسياسة الخصوصية.'
                    '\\nهذا الإجراء لا يمكن التراجع عنه، ولن تتمكن من استعادة حسابك لاحقاً.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'إذا كان لديك أي استفسار قبل الحذف النهائي، فضلاً تواصل مع خدمة العملاء.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          setState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          try {
                            final supabase = Supabase.instance.client;

                            // هذه الدالة يجب إنشاؤها في Supabase (RPC) مع صلاحيات مناسبة
                            // تقوم بـ: حذف المستخدم من auth.users + تنظيف بياناته.
                            await supabase.rpc('delete_my_account');

                            if (Navigator.of(dialogContext).canPop()) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } on PostgrestException catch (_) {
                            setState(() {
                              errorMessage =
                                  'تعذَّر حذف الحساب حالياً، حاول مرة أخرى لاحقاً أو تواصل مع الدعم.';
                            });
                          } catch (_) {
                            setState(() {
                              errorMessage =
                                  'حدث خطأ غير متوقع أثناء حذف الحساب، حاول مرة أخرى لاحقاً.';
                            });
                          } finally {
                            setState(() {
                              isLoading = false;
                            });
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حذف الحساب'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      // بعد النجاح من RPC، نسجّل خروج المستخدم محلياً ونعيده للصفحة الرئيسية
      await ref.read(userProfileProvider.notifier).logout();
      if (context.mounted) {
        context.go('/');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف حسابك بنجاح'),
          ),
        );
      }
    }
  }

  Future<bool> _showLogoutConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'تأكيد تسجيل الخروج',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('هل أنت متأكد أنك تريد تسجيل الخروج من متجر الدكتور؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
