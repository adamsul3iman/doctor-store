import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';
import 'package:doctor_store/shared/utils/static_page_provider.dart';
import 'package:doctor_store/shared/utils/seo_pages_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(staticPageProvider('terms'));
    final seoAsync = ref.watch(seoPageProvider('terms'));

    seoAsync.whenData((seo) {
      SeoManager.setPageSeo(
        title: (seo?.title.isNotEmpty ?? false)
            ? seo!.title
            : 'الشروط والأحكام - متجر الدكتور',
        description: (seo?.description.isNotEmpty ?? false)
            ? seo!.description
            : 'تعرف على الشروط والأحكام الخاصة باستخدام متجر الدكتور وخدماته.',
        imageUrl: seo?.imageUrl,
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'القائمة السريعة',
            onPressed: () => showQuickNavBar(context),
          ),
        ],
        title: Text(
          pageAsync.maybeWhen(
            data: (page) => (page?.title.isNotEmpty ?? false)
                ? page!.title
                : 'الشروط والأحكام',
            orElse: () => 'الشروط والأحكام',
          ),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: pageAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _DefaultTermsContent(),
                data: (page) {
                  if (page == null || page.content.trim().isEmpty) {
                    return const _DefaultTermsContent();
                  }
                  return _DynamicStaticPageContent(
                    title: page.title.isNotEmpty ? page.title : 'الشروط والأحكام',
                    content: page.content,
                  );
                },
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}

class _DefaultTermsContent extends StatelessWidget {
  const _DefaultTermsContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'باستخدامك لمتجر الدكتور، بما في ذلك موقعنا الإلكتروني drstore.me وأي قنوات رقمية تابعة له، فأنت توافق على الشروط التالية:',
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('أولاً: الطلبات والدفع'),
        _sectionBody('• يتم تأكيد الطلب بعد التواصل معك عبر الواتساب أو الهاتف.\n'
            '• قد تتغير الأسعار أو العروض في أي وقت دون إشعار مسبق، مع الحفاظ على السعر المتفق عليه للطلبات المؤكّدة.'),
        const SizedBox(height: 16),
        _sectionTitle('ثانياً: الشحن والتوصيل'),
        _sectionBody('• يتم توصيل الطلبات إلى العنوان الذي يحدده العميل.\n'
            '• تختلف مدة التوصيل حسب المدينة وحجم الطلب، ويتم توضيحها لك قبل التأكيد.'),
        const SizedBox(height: 16),
        _sectionTitle('ثالثاً: الاستبدال والاسترجاع'),
        _sectionBody('• نحرص على رضاك التام، ويمكنك طلب الاستبدال أو الاسترجاع وفق سياسة المتجر المعمول بها، بشرط بقاء المنتج بحالته الأصلية.\n'
            '• بعض المنتجات الخاصة أو التفصيلية قد لا يشملها الاسترجاع الكامل.'),
        const SizedBox(height: 16),
        _sectionTitle('رابعاً: استخدام الموقع'),
        _sectionBody('يُمنع إساءة استخدام الموقع أو محاولة الوصول غير المشروع لبيانات أو أنظمة المتجر.'),
      ],
    );
  }
}

class _DynamicStaticPageContent extends StatelessWidget {
  final String title;
  final String content;

  const _DynamicStaticPageContent({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}

Widget _sectionTitle(String text) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      color: const Color(0xFF0A2647),
    ),
  );
}

Widget _sectionBody(String text) {
  return Text(
    text,
    style: TextStyle(
      fontSize: 14,
      height: 1.7,
      color: Colors.grey[800],
    ),
  );
}
