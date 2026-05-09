import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة نافذة تقييم التطبيق (In-App Review)
///
/// تستخدم Google Play In-App Review API لعرض نافذة التقييم
/// دون مغادرة التطبيق. يتم عرضها بعد فترات محددة من الاستخدام الإيجابي.
class AppReviewService {
  static final AppReviewService _instance = AppReviewService._internal();
  factory AppReviewService() => _instance;
  AppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  // Constants for review prompt logic
  static const String _prefsKeyLastPrompt = 'app_review_last_prompt';
  static const String _prefsKeyLaunchCount = 'app_review_launch_count';
  static const String _prefsKeySuccessfulActions = 'app_review_success_actions';
  static const String _prefsKeyHasReviewed = 'app_review_completed';

  // Minimum requirements before showing review prompt
  static const int _minLaunches = 5; // 5 فتحات للتطبيق
  static const int _minSuccessfulActions =
      3; // 3 إجراءات ناجحة (مشاهدة منتجات، إضافة للمفضلة)
  static const int _daysBetweenPrompts = 30; // 30 يوم بين كل محاولة

  /// التحقق مما إذا كان يجب عرض نافذة التقييم
  Future<bool> shouldShowReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // إذا قيّم المستخدم من قبل، لا تعرض مرة أخرى
    final hasReviewed = prefs.getBool(_prefsKeyHasReviewed) ?? false;
    if (hasReviewed) return false;

    // التحقق من عدد فتحات التطبيق
    final launchCount = prefs.getInt(_prefsKeyLaunchCount) ?? 0;
    if (launchCount < _minLaunches) return false;

    // التحقق من عدد الإجراءات الناجحة
    final successActions = prefs.getInt(_prefsKeySuccessfulActions) ?? 0;
    if (successActions < _minSuccessfulActions) return false;

    // التحقق من الفترة بين كل عرض
    final lastPrompt = prefs.getInt(_prefsKeyLastPrompt) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final daysSinceLastPrompt = (now - lastPrompt) / (1000 * 60 * 60 * 24);

    if (daysSinceLastPrompt < _daysBetweenPrompts) return false;

    // التحقق من توفر خدمة التقييم
    final isAvailable = await _inAppReview.isAvailable();
    return isAvailable;
  }

  /// عرض نافذة تقييم التطبيق
  ///
  /// يتم استدعاؤها بعد تجربة إيجابية (مثل إضافة منتج للمفضلة،
  /// أو مشاهدة تفاصيل منتج، أو فتح التطبيق عدة مرات)
  Future<void> requestReview() async {
    try {
      final shouldShow = await shouldShowReviewPrompt();
      if (!shouldShow) return;

      // عرض نافذة التقييم
      await _inAppReview.requestReview();

      // تسجيل وقت عرض النافذة
      await _recordPromptShown();
    } catch (e) {
      // في حالة فشل الـ Native Review، افتح صفحة المتجر
      await _inAppReview.openStoreListing(appStoreId: '');
    }
  }

  /// فتح صفحة التطبيق في Google Play مباشرة
  Future<void> openStoreListing() async {
    await _inAppReview.openStoreListing(appStoreId: '');
  }

  /// زيادة عدد فتحات التطبيق
  Future<void> incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefsKeyLaunchCount) ?? 0;
    await prefs.setInt(_prefsKeyLaunchCount, current + 1);
  }

  /// تسجيل إجراء ناجح (مشاهدة منتج، إضافة للمفضلة، إلخ)
  Future<void> recordSuccessfulAction() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefsKeySuccessfulActions) ?? 0;
    await prefs.setInt(_prefsKeySuccessfulActions, current + 1);

    // محاولة عرض التقييم بعد الإجراء الناجح
    await requestReview();
  }

  /// تسجيل أنه تم عرض نافذة التقييم
  Future<void> _recordPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_prefsKeyLastPrompt, now);
  }

  /// تسجيل أن المستخدم قيّم التطبيق (لمنع العرض مرة أخرى)
  Future<void> markAsReviewed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKeyHasReviewed, true);
  }

  /// الحصول على إحصائيات الاستخدام (للتصحيح)
  Future<Map<String, dynamic>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'launchCount': prefs.getInt(_prefsKeyLaunchCount) ?? 0,
      'successfulActions': prefs.getInt(_prefsKeySuccessfulActions) ?? 0,
      'lastPrompt': prefs.getInt(_prefsKeyLastPrompt) ?? 0,
      'hasReviewed': prefs.getBool(_prefsKeyHasReviewed) ?? false,
      'isAvailable': await _inAppReview.isAvailable(),
    };
  }

  /// إعادة ضبط الإحصائيات (للاختبار فقط)
  Future<void> resetStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyLaunchCount);
    await prefs.remove(_prefsKeySuccessfulActions);
    await prefs.remove(_prefsKeyLastPrompt);
    await prefs.remove(_prefsKeyHasReviewed);
  }
}
