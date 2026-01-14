import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:doctor_store/shared/utils/settings_provider.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

class OwnerSection extends ConsumerWidget {
  const OwnerSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  child: settingsAsync.when(
                    data: (settings) {
                      final url = settings.ownerImageUrl.trim();
                      if (url.isNotEmpty) {
                        return CachedNetworkImage(
                          imageUrl: buildOptimizedImageUrl(
                            url,
                            variant: ImageVariant.fullScreen,
                          ),
                          height: 220,
                          fit: BoxFit.cover,
                          errorWidget: (c, o, s) => _OwnerImageFallback(),
                          placeholder: (c, o) => Container(
                            height: 220,
                            color: Colors.grey[200],
                          ),
                        );
                      }
                      return const _OwnerImageFallback();
                    },
                    loading: () => Container(
                      height: 220,
                      color: Colors.grey[200],
                    ),
                    error: (e, s) => const _OwnerImageFallback(),
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A2647).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'خدمة التفصيل الخاص',
                          style: TextStyle(
                            color: Color(0xFF0A2647),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'نحن لا نبيع فرشات جاهزة فقط.. نحن نصنع نومك!',
                        style: GoogleFonts.almarai(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0A2647),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'في متجر الدكتور، نسألك أسئلة طبية لنفصل لك الفرشة المناسبة تماماً لجسمك.',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: settingsAsync.when(
                data: (settings) => ElevatedButton.icon(
                  onPressed: () => _launchConsultation(settings.whatsapp),
                  icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 20),
                  label: const Text('احجز استشارة تفصيل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2647),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                loading: () => const Center(
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (e, s) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerImageFallback extends StatelessWidget {
  const _OwnerImageFallback();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/owner.jpg',
      height: 220,
      fit: BoxFit.cover,
      errorBuilder: (c, o, s) => Container(
        height: 220,
        color: Colors.grey[200],
        child: const Center(
          child: Icon(Icons.person, size: 50, color: Colors.grey),
        ),
      ),
    );
  }
}

Future<void> _launchConsultation(String phone) async {
  const message = 'مرحباً دكتور، أرغب بتفصيل فرشة طبية وأحتاج استشارة لتحديد المناسب لي.';
  final url = Uri.parse('https://wa.me/$phone?text=$message');
  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
