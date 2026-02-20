import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle

class QuickActionsGrid extends StatelessWidget {
  final Function(String action) onActionTap;

  const QuickActionsGrid({
    super.key,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction('add_product', 'إضافة منتج', Icons.add_box, const Color(0xFF4CAF50)),
      _QuickAction('add_coupon', 'إضافة كوبون', Icons.local_offer, const Color(0xFFFF6F00)),
      _QuickAction('add_banner', 'إضافة بانر', Icons.image, const Color(0xFF9C27B0)),
      _QuickAction('view_orders', 'الطلبات الجديدة', Icons.shopping_bag, const Color(0xFF2196F3)),
      _QuickAction('view_clients', 'العملاء', Icons.people, const Color(0xFFFFC107)),
      _QuickAction('settings', 'الإعدادات السريعة', Icons.settings, const Color(0xFF607D8B)),
    ];

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6F00).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.flash_on, color: const Color(0xFFFF6F00), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'إجراءات سريعة',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0A2647),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.0,
              ),
              itemCount: actions.length,
              itemBuilder: (context, index) {
                final action = actions[index];
                return _QuickActionButton(
                  action: action,
                  onTap: () => onActionTap(action.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final String id;
  final String title;
  final IconData icon;
  final Color color;

  _QuickAction(this.id, this.title, this.icon, this.color);
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            action.color.withValues(alpha: 0.15),
            action.color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: action.color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: action.color.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    action.icon,
                    color: action.color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    action.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0A2647),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
