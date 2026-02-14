import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ الآن هذا الملف موجود ولن يظهر خطأ
import 'dashboard_home_view.dart'; 

import 'admin_products_view.dart';
import 'admin_banners_view.dart';
import 'admin_orders_view.dart';
import 'admin_clients_view.dart';
import 'admin_reviews_view.dart';
import 'analytics_view.dart';
import 'admin_coupons_view.dart';
import 'admin_categories_view.dart';
import 'admin_delivery_zones_view.dart';
import 'admin_sub_categories_view.dart';
import 'shipping_costs_screen.dart'; // ✅ صفحة إدارة أسعار الشحن

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  bool _isExtended = true;

  static const _kLastAdminTabKey = 'admin_last_tab';

  // القائمة البرمجية للصفحات
  List<Widget> get _views => [
    DashboardHomeView(onNavigateToTab: (index) {
      setState(() => _selectedIndex = index);
      _saveLastTab(index);
    }),
    const AdminOrdersView(),
    const AdminProductsView(),
    const AdminCategoriesView(),
    const AdminSubCategoriesView(),
    const AdminCouponsView(),
    const AdminBannersView(),
    const AdminReviewsView(),
    const AdminClientsView(),
    const AdminDeliveryZonesView(),
    const ShippingCostsScreen(), // ✅ صفحة إدارة أسعار الشحن
    const AnalyticsView(),
  ];

  // بيانات عناصر القائمة
  final List<_AdminMenuItem> _menuItems = [
    _AdminMenuItem(
      title: 'نظرة عامة',
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      group: _AdminMenuGroup.overview,
    ),
    _AdminMenuItem(
      title: 'الطلبات',
      icon: FontAwesomeIcons.boxOpen,
      activeIcon: FontAwesomeIcons.box,
      group: _AdminMenuGroup.orders,
    ),
    _AdminMenuItem(
      title: 'المنتجات',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      group: _AdminMenuGroup.catalog,
    ),
    _AdminMenuItem(
      title: 'الأقسام',
      icon: Icons.category_outlined,
      activeIcon: Icons.category,
      group: _AdminMenuGroup.catalog,
    ),
    _AdminMenuItem(
      title: 'الفئات الفرعية',
      icon: Icons.label_outline,
      activeIcon: Icons.label,
      group: _AdminMenuGroup.catalog,
    ),
    _AdminMenuItem(
      title: 'الكوبونات',
      icon: Icons.local_offer_outlined,
      activeIcon: Icons.local_offer,
      group: _AdminMenuGroup.marketing,
    ),
    _AdminMenuItem(
      title: 'البانرات',
      icon: Icons.view_carousel_outlined,
      activeIcon: Icons.view_carousel,
      group: _AdminMenuGroup.marketing,
    ),
    _AdminMenuItem(
      title: 'التقييمات',
      icon: Icons.star_outline,
      activeIcon: Icons.star,
      group: _AdminMenuGroup.marketing,
    ),
    _AdminMenuItem(
      title: 'العملاء',
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      group: _AdminMenuGroup.marketing,
    ),
    _AdminMenuItem(
      title: 'مناطق التوصيل',
      icon: Icons.delivery_dining_outlined,
      activeIcon: Icons.delivery_dining,
      group: _AdminMenuGroup.operations,
    ),
    _AdminMenuItem(
      title: 'أسعار الشحن',
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      group: _AdminMenuGroup.operations,
    ),
    _AdminMenuItem(
      title: 'الإحصائيات',
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      group: _AdminMenuGroup.overview,
    ),
    _AdminMenuItem(
      title: 'الإعدادات',
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      group: _AdminMenuGroup.settings,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadLastTab();
  }

  Future<void> _loadLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kLastAdminTabKey);
    if (idx != null && idx >= 0 && idx < _views.length) {
      setState(() => _selectedIndex = idx);
    }
  }

  Future<void> _saveLastTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastAdminTabKey, index);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ استخدام LayoutBuilder للتبديل بين تصميم الموبايل والكمبيوتر
    return Directionality(
      textDirection: TextDirection.rtl,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  // تصميم الكمبيوتر (NavigationRail)
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('لوحة التحكم', style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2647),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            tooltip: 'العودة للمتجر',
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(child: _views[_selectedIndex]),
          const VerticalDivider(thickness: 1, width: 1),
          _buildSidebar(
            isDrawer: false,
            onNavigate: (index) {
              setState(() => _selectedIndex = index);
              _saveLastTab(index);
            },
          ),
        ],
      ),
    );
  }

  // تصميم الموبايل (Drawer)
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_menuItems[_selectedIndex].title, style: GoogleFonts.almarai(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2647),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'العودة للمتجر',
            onPressed: () {
              context.go('/');
            },
          )
        ],
      ),
      drawer: Drawer(
        child: _buildSidebar(
          isDrawer: true,
          onNavigate: (index) {
            setState(() => _selectedIndex = index);
            _saveLastTab(index);
            Navigator.pop(context);
          },
        ),
      ),
      body: _views[_selectedIndex],
    );
  }

  Widget _buildSidebar({
    required bool isDrawer,
    required void Function(int index) onNavigate,
  }) {
    const navy = Color(0xFF0A2647);
    const orange = Color(0xFFFF6F00);

    final grouped = <_AdminMenuGroup, List<MapEntry<int, _AdminMenuItem>>>{};
    for (var i = 0; i < _menuItems.length; i++) {
      grouped.putIfAbsent(_menuItems[i].group, () => []).add(MapEntry(i, _menuItems[i]));
    }

    Widget groupHeader(String title) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Text(
          title,
          style: GoogleFonts.almarai(
            color: Colors.white.withValues(alpha: 0.7),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    Widget navTile(int index, _AdminMenuItem item) {
      final isSelected = _selectedIndex == index;
      return ListTile(
        dense: true,
        leading: Icon(
          isSelected ? item.activeIcon : item.icon,
          color: isSelected ? orange : Colors.white.withValues(alpha: 0.75),
          size: 20,
        ),
        title: _isExtended || isDrawer
            ? Text(
                item.title,
                style: GoogleFonts.almarai(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              )
            : null,
        selected: isSelected,
        selectedTileColor: Colors.white.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () => onNavigate(index),
      );
    }

    final content = Container(
      width: isDrawer ? null : (_isExtended ? 280 : 88),
      color: navy,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.local_hospital, color: Colors.white, size: 26),
                  if (_isExtended || isDrawer) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'متجر الدكتور',
                        style: GoogleFonts.almarai(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (!isDrawer)
                    IconButton(
                      tooltip: _isExtended ? 'تصغير' : 'توسيع',
                      icon: Icon(
                        _isExtended
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _isExtended = !_isExtended),
                    ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  groupHeader('نظرة عامة'),
                  for (final entry in grouped[_AdminMenuGroup.overview] ?? const [])
                    navTile(entry.key, entry.value),
                  groupHeader('الطلبات'),
                  for (final entry in grouped[_AdminMenuGroup.orders] ?? const [])
                    navTile(entry.key, entry.value),
                  groupHeader('الكتالوج'),
                  for (final entry in grouped[_AdminMenuGroup.catalog] ?? const [])
                    navTile(entry.key, entry.value),
                  groupHeader('التسويق'),
                  for (final entry in grouped[_AdminMenuGroup.marketing] ?? const [])
                    navTile(entry.key, entry.value),
                  groupHeader('العمليات'),
                  for (final entry in grouped[_AdminMenuGroup.operations] ?? const [])
                    navTile(entry.key, entry.value),
                  groupHeader('الإعدادات'),
                  for (final entry in grouped[_AdminMenuGroup.settings] ?? const [])
                    navTile(entry.key, entry.value),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: ListTile(
                dense: true,
                leading: Icon(
                  Icons.logout,
                  color: Colors.red.shade300,
                  size: 20,
                ),
                title: (_isExtended || isDrawer)
                    ? Text(
                        'تسجيل الخروج',
                        style: GoogleFonts.almarai(
                          color: Colors.red.shade200,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
                onTap: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
    );

    return content;
  }
}

enum _AdminMenuGroup {
  overview,
  orders,
  catalog,
  marketing,
  operations,
  settings,
}

class _AdminMenuItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  final _AdminMenuGroup group;

  const _AdminMenuItem({
    required this.title,
    required this.icon,
    required this.activeIcon,
    required this.group,
  });
}