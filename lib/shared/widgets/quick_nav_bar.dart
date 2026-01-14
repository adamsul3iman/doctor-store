import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/features/auth/application/user_data_manager.dart';
import 'package:doctor_store/shared/utils/link_share_helper.dart';
import 'package:doctor_store/shared/utils/settings_provider.dart';

/// تفتح هذه الدالة لوحة تنقل سريعة حديثة بتصميم مبسّط
Future<void> showQuickNavBar(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const QuickNavBar(),
  );
}

/// لوحة تنقل عصرية تجمع بين بطاقة ترحيب + شبكة أزرار رئيسية + قائمة ثانوية + زر مشاركة التطبيق
class QuickNavBar extends ConsumerWidget {
  const QuickNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final user = ref.watch(userProfileProvider);
    final size = MediaQuery.of(context).size;
    final bool isWide = size.width >= 700;
    final double panelWidth = isWide ? 380 : size.width * 0.9;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.black.withValues(alpha: 0.35),
        child: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Container(
              margin: const EdgeInsets.all(12),
              width: panelWidth,
              height: size.height - 24,
              child: Material(
                elevation: 20,
                borderRadius: BorderRadius.circular(24),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(context),
                    const Divider(height: 1),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProfileCard(user: user),
                            const SizedBox(height: 20),
                            const _MainActionsGrid(),
                            const SizedBox(height: 24),
                            const _SecondaryList(),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _ShareAppButton(settingsAsync: settingsAsync),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              PhosphorIcons.list(),
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'القائمة السريعة للمتجر',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            icon: Icon(PhosphorIcons.x(), color: Colors.grey[800]),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final UserProfile user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGuest = user.isGuest;
    final name = isGuest
        ? 'ضيفنا الكريم'
        : (user.name.isNotEmpty ? user.name : 'عميل متجر الدكتور');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
            child: Icon(
              PhosphorIcons.user(),
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً، $name',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isGuest
                      ? 'سجّل دخولك لحفظ المفضلة وتتبع طلباتك بسهولة.'
                      : 'يمكنك عرض ملفك الشخصي وتعديل بياناتك من هنا.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              if (isGuest) {
                router.go('/login');
              } else {
                router.push('/profile');
              }
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'عرض الملف',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MainActionsGrid extends StatelessWidget {
  const _MainActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _GridItem(
        icon: PhosphorIcons.house(),
        label: 'الصفحة الرئيسية',
        onTap: (ctx) => _go(ctx, '/'),
      ),
      _GridItem(
        icon: PhosphorIcons.squaresFour(),
        label: 'كل المنتجات',
        onTap: (ctx) => _push(ctx, '/all_products'),
      ),
      _GridItem(
        icon: PhosphorIcons.tag(),
        label: 'العروض',
        onTap: (ctx) => _push(ctx, '/all_products?sort=offers'),
      ),
      _GridItem(
        icon: PhosphorIcons.receipt(),
        label: 'طلباتي',
        onTap: (ctx) => _push(ctx, '/orders'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }
}

class _GridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function(BuildContext) onTap;

  const _GridItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 22),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryList extends StatelessWidget {
  const _SecondaryList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SecondaryItem(
          icon: PhosphorIcons.storefront(),
          label: 'من نحن',
          onTap: (ctx) => _push(ctx, '/about'),
        ),
        _SecondaryItem(
          icon: PhosphorIcons.phone(),
          label: 'اتصل بنا',
          onTap: (ctx) => _push(ctx, '/contact'),
        ),
      ],
    );
  }
}

class _SecondaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final void Function(BuildContext) onTap;

  const _SecondaryItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => onTap(context),
    );
  }
}

class _ShareAppButton extends StatelessWidget {
  final AsyncValue<AppSettings> settingsAsync;

  const _ShareAppButton({required this.settingsAsync});

  @override
  Widget build(BuildContext context) {
    return settingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (settings) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => shareAppPage(
              path: '/',
              title: AppSettings.storeName,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: Icon(
              PhosphorIcons.shareNetwork(),
              size: 20,
            ),
            label: const Text(
              'مشاركة تطبيق المتجر',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      },
    );
  }
}

void _go(BuildContext context, String path) {
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.go(path);
}

void _push(BuildContext context, String path) {
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.push(path);
}
