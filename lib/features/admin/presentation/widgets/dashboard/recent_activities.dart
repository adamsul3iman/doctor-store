import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../data/services/admin_dashboard_service.dart';

class RecentActivitiesList extends StatelessWidget {
  final List<RecentActivity>? activities;

  const RecentActivitiesList({super.key, this.activities});

  @override
  Widget build(BuildContext context) {
    final data = activities ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.notifications_active, color: const Color(0xFFFF6F00), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'آخر النشاطات',
                      style: GoogleFonts.almarai(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0A2647),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'عرض الكل',
                    style: GoogleFonts.almarai(
                      fontSize: 12,
                      color: const Color(0xFF0A2647),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const SizedBox(
                height: 100,
                child: Center(
                  child: Text('لا توجد نشاطات حديثة', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final activity = data[index];
                  return _ActivityItem(activity: activity);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final RecentActivity activity;

  const _ActivityItem({required this.activity});

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();

    // Configure Arabic for timeago
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                activity.title,
                style: GoogleFonts.almarai(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0A2647),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                activity.subtitle,
                style: GoogleFonts.almarai(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          timeago.format(activity.time, locale: 'ar'),
          style: GoogleFonts.almarai(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }

  Color _getColor() {
    switch (activity.type) {
      case ActivityType.order:
        return const Color(0xFF4CAF50);
      case ActivityType.review:
        return const Color(0xFFFFC107);
      case ActivityType.product:
        return const Color(0xFFFF6F00);
    }
  }

  IconData _getIcon() {
    switch (activity.type) {
      case ActivityType.order:
        return Icons.shopping_bag;
      case ActivityType.review:
        return Icons.star;
      case ActivityType.product:
        return Icons.inventory;
    }
  }
}
