import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';
import 'package:doctor_store/shared/utils/static_page_provider.dart';
import 'package:doctor_store/shared/utils/seo_pages_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageAsync = ref.watch(staticPageProvider('about'));
    final seoAsync = ref.watch(seoPageProvider('about'));

    seoAsync.whenData((seo) {
      SeoManager.setPageSeo(
        title: (seo?.title.isNotEmpty ?? false)
            ? seo!.title
            : 'من نحن - متجر الدكتور',
        description: (seo?.description.isNotEmpty ?? false)
            ? seo!.description
            : 'تعرف على متجر الدكتور، المتجر المتخصص في حلول النوم المريحة والعملية.',
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
                : 'من نحن',
            orElse: () => 'من نحن',
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
                error: (_, __) => const _DefaultAboutContent(),
                data: (page) {
                  if (page == null || page.content.trim().isEmpty) {
                    return const _DefaultAboutContent();
                  }
                  return _DynamicStaticAboutContent(
                    title: page.title.isNotEmpty ? page.title : 'من نحن',
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

class _DefaultAboutContent extends StatelessWidget {
  const _DefaultAboutContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'متجر الدكتور للنوم والراحة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'تسوقنا أونلاين عبر موقعنا الرسمي drstore.me أو من خلال قنواتنا المعتمدة.',
          style: TextStyle(
            fontSize: 13,
            height: 1.6,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'متجر متخصص في حلول النوم المريحة والعملية، من الفرشات الطبية عالية الجودة، إلى المفارش والوسائد والإكسسوارات التي ترتقي بتجربة نومك اليومية.',
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'رسالتنا',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'أن نقدّم لعملائنا نومًا أعمق وحياةً أرقى عبر منتجات مختارة بعناية وخدمة ما بعد البيع مبنية على الثقة والشفافية.',
          style: TextStyle(
            fontSize: 14,
            height: 1.7,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'لماذا متجر الدكتور؟',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '• استشارات مخصصة لاختيار الفرشة والوسادة الأنسب لك.\n'
          '• منتجات أصلية بعناية خاصة وجودة عالية.\n'
          '• تجربة شراء سلسة عبر الواتساب أو الموقع.\n'
          '• متابعة وخدمة ما بعد البيع لضمان رضاك التام.',
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

class _DynamicStaticAboutContent extends StatelessWidget {
  final String title;
  final String content;

  const _DynamicStaticAboutContent({
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
            fontSize: 20,
            fontWeight: FontWeight.w800,
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
