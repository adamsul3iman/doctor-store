import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:doctor_store/core/theme/app_theme.dart';
import 'package:doctor_store/features/cart/application/cart_manager.dart';
import 'package:doctor_store/features/auth/presentation/widgets/account_icon.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';

/// Reusable AppBar for RTL layout with:
/// Right: [Menu/Back, Share, Cart]
/// Center: Logo or Title
/// Left: Search icon (optional)
class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final bool isHome;
  final String? title;
  final Widget? centerWidget;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final String? sharePath;
  final String? shareTitle;
  final VoidCallback? onShareTap;
  final Color iconColor;
  /// تحكم في إظهار زر المشاركة من عدمه (افتراضياً ظاهر للحفاظ على السلوك القديم)
  final bool showShare;
  /// في بعض الشاشات (مثل كل المجموعات) نريد وضع أيقونة السلة بجانب البحث في الجهة اليسرى (RTL)
  final bool moveCartNextToSearch;

  const CustomAppBar({
    super.key,
    required this.isHome,
    this.title,
    this.centerWidget,
    this.showSearch = true,
    this.onSearchTap,
    this.sharePath,
    this.shareTitle,
    this.onShareTap,
    this.iconColor = AppTheme.primary,
    this.showShare = true,
    this.moveCartNextToSearch = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: CustomAppBarContent(
        isHome: isHome,
        title: title,
        centerWidget: centerWidget,
        showSearch: showSearch,
        onSearchTap: onSearchTap,
        sharePath: sharePath,
        shareTitle: shareTitle,
        onShareTap: onShareTap,
        iconColor: iconColor,
        showShare: showShare,
        moveCartNextToSearch: moveCartNextToSearch,
      ),
    );
  }
}

class CustomAppBarContent extends ConsumerWidget {
  final bool isHome;
  final String? title;
  final Widget? centerWidget;
  final bool showSearch;
  final VoidCallback? onSearchTap;
  final String? sharePath;
  final String? shareTitle;
  final VoidCallback? onShareTap;
  final Color iconColor;
  final bool showShare;
  final bool moveCartNextToSearch;

  const CustomAppBarContent({
    super.key,
    required this.isHome,
    this.title,
    this.centerWidget,
    this.showSearch = true,
    this.onSearchTap,
    this.sharePath,
    this.shareTitle,
    this.onShareTap,
    this.iconColor = AppTheme.primary,
    this.showShare = true,
    this.moveCartNextToSearch = false,
  });
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final cartCount =
        cartItems.fold<int>(0, (sum, item) => sum + item.quantity);

    // إخفاء أيقونة السلة داخل صفحة السلة نفسها بناءً على المسار الحالي
    final String matchedLocation = GoRouterState.of(context).matchedLocation;
    final bool isCartRoute = matchedLocation == '/cart';

    final appBarTitleStyle = Theme.of(context).appBarTheme.titleTextStyle ??
        const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        );

    final Widget center = centerWidget ??
        (title != null
            ? Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: appBarTitleStyle.copyWith(color: iconColor),
              )
            : const SizedBox.shrink());

    return SizedBox(
      height: kToolbarHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center: logo or title (مرن مع قص عند الطول الزائد)
          Positioned.fill(
            left: 160, // مساحة كبيرة لأيقونات البحث + السلة + الحساب
            right: 60,  // مساحة لأيقونة الرجوع/القائمة
            child: Center(child: center),
          ),

          // Right side: only Menu / Back (leading in RTL)
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: isHome ? 'القائمة' : 'رجوع',
                  icon: Icon(
                    isHome ? PhosphorIcons.list() : PhosphorIcons.arrowLeft(),
                    color: iconColor,
                  ),
                  onPressed: () {
                    if (isHome) {
                      showQuickNavBar(context);
                    } else {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    }
                  },
                ),
              ],
            ),
          ),

          // Left side: Search + Cart + Profile (actions in RTL)
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSearch)
                  IconButton(
                    tooltip: 'بحث',
                    icon: Icon(
                      PhosphorIcons.magnifyingGlass(),
                      color: iconColor,
                    ),
                    onPressed: onSearchTap,
                  ),
                if (!isCartRoute)
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => context.push('/cart'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            PhosphorIcons.shoppingBag(),
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        if (cartCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Center(
                                child: Text(
                                  '$cartCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                AccountIcon(color: iconColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
