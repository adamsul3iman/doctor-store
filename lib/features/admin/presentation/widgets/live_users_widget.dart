import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import '../../../../shared/services/analytics_service.dart';

/// Widget لعرض عدد المتصلين الآن (Live Users Counter)
class LiveUsersWidget extends StatefulWidget {
  const LiveUsersWidget({super.key});

  @override
  State<LiveUsersWidget> createState() => _LiveUsersWidgetState();
}

class _LiveUsersWidgetState extends State<LiveUsersWidget> {
  int _onlineUsers = 0;
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOnlineUsers();
    // تحديث كل 10 ثواني
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchOnlineUsers(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOnlineUsers() async {
    try {
      final count = await AnalyticsService.instance.getOnlineUsersCount();
      if (mounted) {
        setState(() {
          _onlineUsers = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF2E7D32),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with live indicator
          Row(
            children: [
              // Pulsing live dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'متواجدون الآن',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const Spacer(),
              // Refresh icon
              if (!_isLoading)
                GestureDetector(
                  onTap: _fetchOnlineUsers,
                  child: Icon(
                    Icons.refresh,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Count
          _isLoading
              ? Container(
                  width: 60,
                  height: 48,
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_onlineUsers',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'زائر',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 12),
          // Status text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Text(
                  'آخر 5 دقائق',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget مبسط للعرض في الـ AppBar أو مكان صغير
class LiveUsersBadge extends StatefulWidget {
  final VoidCallback? onTap;

  const LiveUsersBadge({super.key, this.onTap});

  @override
  State<LiveUsersBadge> createState() => _LiveUsersBadgeState();
}

class _LiveUsersBadgeState extends State<LiveUsersBadge> {
  int _onlineUsers = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchOnlineUsers();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _fetchOnlineUsers(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchOnlineUsers() async {
    try {
      final count = await AnalyticsService.instance.getOnlineUsersCount();
      if (mounted) {
        setState(() {
          _onlineUsers = count;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$_onlineUsers متصل',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
