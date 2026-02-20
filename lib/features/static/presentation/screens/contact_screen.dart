import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/shared/utils/static_page_provider.dart';
import 'package:doctor_store/shared/utils/seo_pages_provider.dart';
import 'package:doctor_store/shared/utils/seo_manager.dart';
import 'package:doctor_store/shared/widgets/app_footer.dart';
import 'package:doctor_store/shared/widgets/quick_nav_bar.dart';

class ContactScreen extends ConsumerWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final pageAsync = ref.watch(staticPageProvider('contact'));
    final seoAsync = ref.watch(seoPageProvider('contact'));

    seoAsync.whenData((seo) {
      SeoManager.setPageSeo(
        title: (seo?.title.isNotEmpty ?? false)
            ? seo!.title
            : 'اتصل بنا - متجر الدكتور',
        description: (seo?.description.isNotEmpty ?? false)
            ? seo!.description
            : 'تواصل مع فريق متجر الدكتور للاستفسارات وطلب المساعدة في اختيار المنتج المناسب.',
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
                : 'اتصل بنا',
            orElse: () => 'اتصل بنا',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  pageAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const _DefaultContactIntro(),
                    data: (page) {
                      if (page == null || page.content.trim().isEmpty) {
                        return const _DefaultContactIntro();
                      }
                      return _DynamicContactIntro(
                        title: page.title.isNotEmpty ? page.title : 'اتصل بنا',
                        content: page.content,
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  settingsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
                    data: (settings) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _contactTile(
                            icon: FontAwesomeIcons.whatsapp,
                            label: 'واتساب',
                            value: settings.whatsapp.isNotEmpty
                                ? settings.whatsapp
                                : 'متوفر عبر الواتساب',
                            onTap: () async {
                              if (settings.whatsapp.isEmpty) return;
                              final uri = Uri.parse('https://wa.me/${settings.whatsapp}');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          _contactTile(
                            icon: Icons.email_outlined,
                            label: 'البريد الإلكتروني',
                            value: 'يمكنك مراسلتنا عبر النموذج داخل الواتساب أو الرسائل.',
                          ),
                          const SizedBox(height: 10),
                          _contactTile(
                            icon: Icons.location_on_outlined,
                            label: 'الموقع',
                            value: 'يتم تزويدك بالتفاصيل عند تأكيد الطلب.',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}

class _DefaultContactIntro extends StatelessWidget {
  const _DefaultContactIntro();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'يسعدنا تواصلك معنا',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0A2647),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'فريق متجر الدكتور جاهز للرد على استفساراتك، مساعدتك في اختيار المنتج المناسب، ومتابعة طلباتك.',
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

class _DynamicContactIntro extends StatelessWidget {
  final String title;
  final String content;

  const _DynamicContactIntro({
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
        const SizedBox(height: 8),
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

Widget _contactTile({required IconData icon, required String label, required String value, VoidCallback? onTap}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0A2647)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0A2647),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
