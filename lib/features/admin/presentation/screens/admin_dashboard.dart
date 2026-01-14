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
import 'admin_settings_view.dart';
import 'admin_coupons_view.dart';
import 'admin_categories_view.dart';
import 'admin_delivery_zones_view.dart';
import 'admin_sub_categories_view.dart';

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
  final List<Widget> _views = [
    const DashboardHomeView(),
    const AdminOrdersView(),
    const AdminProductsView(),
    const AdminCategoriesView(),
    const AdminSubCategoriesView(),
    const AdminCouponsView(),
    const AdminDeliveryZonesView(),
    const AdminBannersView(),
    const AdminClientsView(),
    const AdminReviewsView(),
    const AdminSettingsView(),
  ];

  // بيانات عناصر القائمة
  final List<_AdminMenuItem> _menuItems = [
    _AdminMenuItem("الرئيسية", Icons.dashboard_outlined, Icons.dashboard),
    _AdminMenuItem("الطلبات", FontAwesomeIcons.boxOpen, FontAwesomeIcons.box),
    _AdminMenuItem("المنتجات", Icons.inventory_2_outlined, Icons.inventory_2),
    _AdminMenuItem("الأقسام", Icons.category_outlined, Icons.category),
    _AdminMenuItem("الفئات الفرعية", Icons.label_outline, Icons.label),
    _AdminMenuItem("الكوبونات", Icons.local_offer_outlined, Icons.local_offer),
    _AdminMenuItem("مناطق التوصيل", Icons.delivery_dining_outlined, Icons.delivery_dining),
    _AdminMenuItem("البانرات", Icons.view_carousel_outlined, Icons.view_carousel),
    _AdminMenuItem("العملاء", Icons.people_outline, Icons.people),
    _AdminMenuItem("التقييمات", Icons.star_outline, Icons.star),
    _AdminMenuItem("الإعدادات", Icons.settings_outlined, Icons.settings),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return _buildDesktopLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  // تصميم الكمبيوتر (NavigationRail)
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          NavigationRail(
            extended: _isExtended,
            backgroundColor: const Color(0xFF0A2647),
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
              _saveLastTab(index);
            },
            leading: Column(
              children: [
                const SizedBox(height: 20),
                Icon(Icons.local_hospital, color: Colors.white, size: _isExtended ? 40 : 30),
                if (_isExtended) ...[
                  const SizedBox(height: 10),
                  Text("متجر الدكتور", style: GoogleFonts.almarai(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 20),
                IconButton(
                  icon: Icon(_isExtended ? Icons.arrow_back_ios : Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  onPressed: () => setState(() => _isExtended = !_isExtended),
                ),
                const SizedBox(height: 20),
              ],
            ),
            destinations: _menuItems.map((item) {
              return NavigationRailDestination(
                icon: Icon(item.icon, color: Colors.white70),
                selectedIcon: Icon(item.activeIcon, color: const Color(0xFFD4AF37)),
                label: Text(item.title, style: GoogleFonts.almarai(color: Colors.white)),
              );
            }).toList(),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedIconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
            selectedLabelTextStyle: GoogleFonts.almarai(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold),
            unselectedLabelTextStyle: GoogleFonts.almarai(color: Colors.white70),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _views[_selectedIndex]),
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
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/');
            },
          )
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0A2647)),
              accountName: Text("لوحة التحكم", style: GoogleFonts.almarai(fontWeight: FontWeight.bold, fontSize: 18)),
              accountEmail: Text("admin@doctorstore.com", style: GoogleFonts.almarai(color: Colors.white70)),
              currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, color: Color(0xFF0A2647), size: 30)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _menuItems.length,
                itemBuilder: (context, index) {
                  final item = _menuItems[index];
                  final isSelected = _selectedIndex == index;
                  return ListTile(
                    leading: Icon(isSelected ? item.activeIcon : item.icon, color: isSelected ? const Color(0xFF0A2647) : Colors.grey[600]),
                    title: Text(item.title, style: GoogleFonts.almarai(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF0A2647) : Colors.black87)),
                    tileColor: isSelected ? const Color(0xFF0A2647).withValues(alpha: 0.05) : null,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      _saveLastTab(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: _views[_selectedIndex],
    );
  }
}

class _AdminMenuItem {
  final String title;
  final IconData icon;
  final IconData activeIcon;
  _AdminMenuItem(this.title, this.icon, this.activeIcon);
}