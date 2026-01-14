import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/core/theme/app_theme.dart';

class AppFooter extends ConsumerWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final year = DateTime.now().year;

    return settingsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (settings) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
          decoration: const BoxDecoration(
            color: AppTheme.primary,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;

              final brandSection = _buildBrandSection(settings);
              final quickSection = _buildQuickLinksSection(context);
              final newsletterSection = _buildNewsletterSection(context);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isMobile) ...[
                    brandSection,
              const SizedBox(height: 24),
            _buildLinksSection(settings, context),
                    const SizedBox(height: 24),
                    quickSection,
                    const SizedBox(height: 24),
                    newsletterSection,
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: brandSection),
                        const SizedBox(width: 32),
                        Expanded(flex: 2, child: _buildLinksSection(settings, context)),
                        const SizedBox(width: 32),
                        Expanded(flex: 2, child: quickSection),
                        const SizedBox(width: 32),
                        Expanded(flex: 3, child: newsletterSection),
                      ],
                    ),
                  ],

                  const SizedBox(height: 28),
                  const Divider(color: Colors.white24, height: 1),
                  const SizedBox(height: 16),

                  // الشريط السفلي لحقوق النشر
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '© $year متجر الدكتور. جميع الحقوق محفوظة.',
                        style: GoogleFonts.almarai(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      if (!isMobile)
                        Text(
                          settings.ownerName.isNotEmpty
                              ? 'بإدارة: ${settings.ownerName}'
                              : 'راحة وجودة تختارها بنفسك.',
                          style: GoogleFonts.almarai(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBrandSection(AppSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'متجر الدكتور',
                  style: GoogleFonts.almarai(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'نوم أفخم.. حياة أرقى',
                  style: GoogleFonts.almarai(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'نوفر لك حلول نوم وراحة متكاملة، من الفرشات الطبية حتى أدق تفاصيل غرفة النوم، بجودة عالية وتجربة تسوّق سلسة.',
          style: GoogleFonts.almarai(
            color: Colors.white70,
            fontSize: 12,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (settings.facebook.isNotEmpty)
              _buildSocialIcon(FontAwesomeIcons.facebookF, settings.facebook),
            if (settings.instagram.isNotEmpty)
              _buildSocialIcon(FontAwesomeIcons.instagram, settings.instagram),
            if (settings.tiktok.isNotEmpty)
              _buildSocialIcon(FontAwesomeIcons.tiktok, settings.tiktok),
          ],
        ),
      ],
    );
  }

  Widget _buildLinksSection(AppSettings settings, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المتجر',
          style: GoogleFonts.almarai(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _FooterLink(label: 'من نحن', onTap: () {
          context.push('/about');
        }),
        _FooterLink(label: 'سياسة الخصوصية', onTap: () {
          context.push('/privacy');
        }),
        _FooterLink(label: 'الشروط والأحكام', onTap: () {
          context.push('/terms');
        }),
        _FooterLink(label: 'اتصل بنا', onTap: () {
          context.push('/contact');
        }),
        _FooterLink(label: 'الصفحة الرئيسية', onTap: () {
          context.go('/');
        }),
      ],
    );
  }

  Widget _buildQuickLinksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'تسوّق سريع',
          style: GoogleFonts.almarai(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _FooterLink(
          label: 'المنتجات الجديدة',
          onTap: () => context.push('/all_products?sort=new'),
        ),
        _FooterLink(
          label: 'الأكثر مبيعاً',
          onTap: () => context.push('/all_products?sort=best'),
        ),
        _FooterLink(
          label: 'العروض الحالية',
          onTap: () => context.push('/all_products?sort=offers'),
        ),
      ],
    );
  }

  Widget _buildNewsletterSection(BuildContext context) {
    final controller = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'النشرة البريدية',
          style: GoogleFonts.almarai(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'اشترك ليصلك جديد العروض والمنتجات المميّزة أولاً بأول.',
          style: GoogleFonts.almarai(
            color: Colors.white70,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.almarai(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'أدخل بريدك الإلكتروني',
                  hintStyle: GoogleFonts.almarai(color: Colors.white54, fontSize: 11),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.secondary, width: 1.4),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('سيتم تفعيل النشرة البريدية قريباً بإذن الله.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'اشترك',
                  style: GoogleFonts.almarai(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'لن نزعجك بالرسائل، نرسل لك فقط ما يستحق.',
          style: GoogleFonts.almarai(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, String url) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8.0),
      child: InkWell(
        onTap: () => _launchUrl(url),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Text(
            label,
            style: GoogleFonts.almarai(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
