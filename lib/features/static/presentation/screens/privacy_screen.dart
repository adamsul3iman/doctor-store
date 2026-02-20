import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';
import 'package:doctor_store/shared/utils/static_page_provider.dart';
import 'package:doctor_store/shared/utils/seo_pages_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(staticPageProvider('privacy'));
    final seoAsync = ref.watch(seoPageProvider('privacy'));

    seoAsync.whenData((seo) {
      SeoManager.setPageSeo(
        title: (seo?.title.isNotEmpty ?? false)
            ? seo!.title
            : 'سياسة الخصوصية - متجر الدكتور',
        description: (seo?.description.isNotEmpty ?? false)
            ? seo!.description
            : 'اطلع على كيفية تعامل متجر الدكتور مع بياناتك الشخصية وحمايتها.',
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
                : 'سياسة الخصوصية',
            orElse: () => 'سياسة الخصوصية',
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
                error: (_, __) => const _DefaultPrivacyContent(),
                data: (page) {
                  if (page == null || page.content.trim().isEmpty) {
                    return const _DefaultPrivacyContent();
                  }
                  return _DynamicStaticPageContent(
                    title: page.title.isNotEmpty ? page.title : 'سياسة الخصوصية',
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

class _DefaultPrivacyContent extends StatelessWidget {
  const _DefaultPrivacyContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'حماية بياناتك أولوية لدينا',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'نلتزم في متجر الدكتور بالحفاظ على خصوصية معلوماتك الشخصية واستخدامها فقط للأغراض المرتبطة بتجربة تسوّقك وخدمتك بالشكل الأمثل.',
          style: TextStyle(fontSize: 14, height: 1.7, color: Colors.grey[800]),
        ),
        const SizedBox(height: 8),
        Text(
          'تُطبَّق هذه السياسة على استخدامك لموقعنا الإلكتروني drstore.me وأي قنوات رقمية رسمية تابعة للمتجر.',
          style: TextStyle(fontSize: 13, height: 1.7, color: Colors.grey[800]),
        ),
        const SizedBox(height: 16),
        _sectionTitle('المعلومات التي نقوم بجمعها'),
        _sectionBody('• بيانات التواصل (الاسم، رقم الهاتف، البريد الإلكتروني إن وجد).\n'
            '• بيانات الطلبات وعناوين التوصيل.\n'
            '• بيانات الاستخدام الأساسية لتحسين أداء الموقع وتجربة المستخدم.'),
        const SizedBox(height: 16),
        _sectionTitle('كيف نستخدم بياناتك؟'),
        _sectionBody('• تجهيز وتنفيذ طلبات الشراء.\n'
            '• التواصل معك بخصوص طلباتك أو استفساراتك.\n'
            '• إرسال عروض خاصة في حال موافقتك على ذلك.\n'
            '• تحسين منتجاتنا وخدماتنا بناءً على تفضيلات العملاء.'),
        const SizedBox(height: 16),
        _sectionTitle('مشاركة المعلومات مع أطراف ثالثة'),
        _sectionBody('لا نقوم ببيع أو مشاركة بياناتك مع أي جهة تجارية خارجية، ويقتصر استخدامها على مزودي خدمات الشحن أو الدفع عند الحاجة لإتمام طلبك فقط.'),
        const SizedBox(height: 16),
        _sectionTitle('حقوقك'),
        _sectionBody('يمكنك دائماً التواصل معنا لتحديث بياناتك، أو طلب توضيح حول طريقة استخدامها، أو إلغاء الاشتراك من الرسائل التسويقية.'),
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
