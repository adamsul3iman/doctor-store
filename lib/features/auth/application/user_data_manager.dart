import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ الموديل: يعكس بيانات جدول profiles بدقة
class UserProfile {
  final String? id;
  final String name;
  final String phone;
  final String email;
  final String address;
  final String avatarUrl; // رابط الصورة الشخصية
  final String role; // 'admin' or 'customer'
  final double totalSpent;
  final int totalOrders;

  UserProfile({
    this.id,
    this.name = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.avatarUrl = '',
    this.role = 'customer',
    this.totalSpent = 0.0,
    this.totalOrders = 0,
  });

  bool get isGuest => id == null;
  bool get isAdmin => role == 'admin';

  /// نسبة اكتمال الملف الشخصي (0 - 1) بناءً على الحقول الأساسية
  double get completionPercent {
    int score = 0;
    if (name.trim().isNotEmpty) score++;
    if (phone.trim().isNotEmpty) score++;
    if (address.trim().isNotEmpty) score++;
    if (avatarUrl.trim().isNotEmpty) score++;
    const int maxScore = 4;
    return score / maxScore;
  }

  UserProfile copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? avatarUrl,
    String? role,
    double? totalSpent,
    int? totalOrders,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      totalSpent: totalSpent ?? this.totalSpent,
      totalOrders: totalOrders ?? this.totalOrders,
    );
  }
}

// ✅ البروفايدر الرئيسي
final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier() : super(UserProfile()) {
    _init();
  }

  SupabaseClient? _getClientOrNull() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      // في بيئات الاختبار أو في حال لم يتم استدعاء Supabase.initialize بعد
      return null;
    }
  }

  Future<void> _init() async {
    await _loadFromPrefs(); // تحميل السريع من الكاش
    await refreshProfile(); // مزامنة حقيقية مع السيرفر
  }

  // 1. التحميل المبدئي من الذاكرة المحلية
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = UserProfile(
      id: prefs.getString('user_id'),
      name: prefs.getString('user_name') ?? '',
      phone: prefs.getString('user_phone') ?? '',
      email: prefs.getString('user_email') ?? '',
      address: prefs.getString('user_address') ?? '',
      avatarUrl: prefs.getString('user_avatar_url') ?? '',
      role: prefs.getString('user_role') ?? 'customer',
    );
  }

  // 2. المزامنة مع قاعدة البيانات (الأهم)
  Future<void> refreshProfile() async {
    final client = _getClientOrNull();
    if (client == null) return;

    final user = client.auth.currentUser;
    if (user != null) {
      try {
        final meta = user.userMetadata;
        final metaFirst = meta?['first_name']?.toString().trim() ?? '';
        final metaLast = meta?['last_name']?.toString().trim() ?? '';
        final metaFull = meta?['full_name']?.toString().trim() ?? '';
        final metaName = metaFull.isNotEmpty
            ? metaFull
            : [metaFirst, metaLast].where((e) => e.isNotEmpty).join(' ');

        final data = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (data != null) {
          Map<String, dynamic> map;
          map = data;
        
          final updatedProfile = state.copyWith(
            id: user.id,
            email: user.email ?? state.email,
            name: (map['full_name']?.toString().trim().isNotEmpty ?? false)
                ? map['full_name']!.toString().trim()
                : (metaName.isNotEmpty ? metaName : state.name),
            phone: map['phone']?.toString() ?? state.phone,
            address: map['address']?.toString() ?? state.address,
            avatarUrl: map['avatar_url']?.toString() ?? state.avatarUrl,
            role: map['role']?.toString() ?? 'customer',
            totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0.0,
            totalOrders: (map['total_orders'] as num?)?.toInt() ?? 0,
          );

          state = updatedProfile;
          _saveToPrefs(updatedProfile); // تحديث الكاش
        } else {
          final updatedProfile = state.copyWith(
            id: user.id,
            email: user.email ?? state.email,
            name: metaName.isNotEmpty ? metaName : state.name,
          );

          state = updatedProfile;
          _saveToPrefs(updatedProfile);
        }
      } catch (e) {
        debugPrint("Sync Error: $e");
      }
    }
  }

  // 3. تحديث البيانات (تعديل البروفايل)
  Future<void> updateProfile({String? name, String? phone, String? address}) async {
    final client = _getClientOrNull();
    if (client == null) return;

    final user = client.auth.currentUser;
    if (user == null) return;

    // القيم الجديدة أو الاحتفاظ بالقديمة
    final newName = name ?? state.name;
    final newPhone = phone ?? state.phone;
    final newAddress = address ?? state.address;

    // 1. تحديث الواجهة فوراً (Optimistic UI)
    state = state.copyWith(name: newName, phone: newPhone, address: newAddress);
    
    // 2. تحديث السيرفر
    try {
      await client.from('profiles').update({
        'full_name': newName,
        'phone': newPhone,
        'address': newAddress,
      }).eq('id', user.id);
      
      // 3. تحديث الكاش
      await _saveToPrefs(state);
      
    } catch (e) {
      debugPrint("Update Error: $e");
      await refreshProfile(); // في حال الفشل، نعود للبيانات الحقيقية
      rethrow; // نرمي الخطأ ليعرض رسالة للمستخدم
    }
  }

  Future<void> _saveToPrefs(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    if (p.id != null) await prefs.setString('user_id', p.id!);
    await prefs.setString('user_name', p.name);
    await prefs.setString('user_phone', p.phone);
    await prefs.setString('user_email', p.email);
    await prefs.setString('user_address', p.address);
    await prefs.setString('user_avatar_url', p.avatarUrl);
    await prefs.setString('user_role', p.role);
  }

  Future<void> updateAvatar(String avatarUrl) async {
    final client = _getClientOrNull();
    if (client == null) return;

    final user = client.auth.currentUser;
    if (user == null) return;

    // تحديث الواجهة فوراً
    state = state.copyWith(avatarUrl: avatarUrl);

    try {
      await client.from('profiles').update({
        'avatar_url': avatarUrl,
      }).eq('id', user.id);

      await _saveToPrefs(state);
    } catch (e) {
      debugPrint("Avatar Update Error: $e");
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final client = _getClientOrNull();
    if (client != null) {
      await client.auth.signOut();
    }

    state = UserProfile(); // تصفير الحالة
  }
}