import 'package:flutter/material.dart';
import 'modern_admin_dashboard.dart';

// Legacy wrapper - redirects to modern dashboard
class DashboardHomeView extends StatelessWidget {
  final Function(int)? onNavigateToTab;
  
  const DashboardHomeView({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    return ModernAdminDashboard(onNavigateToTab: onNavigateToTab);
  }
}
