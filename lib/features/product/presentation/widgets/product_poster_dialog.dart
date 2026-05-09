import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/shared/utils/product_nav_helper.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';
import 'package:doctor_store/shared/widgets/app_network_image.dart';
import 'package:doctor_store/shared/widgets/constrained_dialog.dart';

class ProductPosterDialog extends StatefulWidget {
  final Product product;
  const ProductPosterDialog({super.key, required this.product});

  @override
  State<ProductPosterDialog> createState() => _ProductPosterDialogState();
}

class _ProductPosterDialogState extends State<ProductPosterDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isSharing = false;

  String _buildProductUrl() {
    // استخدام الهيلبر الموحد لبناء رابط كامل مع الدومين والمسار الصحيح
    return buildFullProductUrl(widget.product);
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);

    try {
      // 1. التقاط الصورة
      final Uint8List? imageBytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 20),
      );

      if (!mounted) return;

      if (imageBytes != null) {
        // ✅ التعديل هنا: استخدام XFile.fromData مباشرة
        // هذا يعمل على الويب والموبايل ولا يحتاج path_provider
        final xFile = XFile.fromData(
          imageBytes,
          mimeType: 'image/png',
          name: 'product_card_${widget.product.id}.png',
        );

        final url = _buildProductUrl();

        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [xFile],
          text:
              'ما رأيك بهذا المنتج المميز من متجر الدكتور؟ 😍\n${widget.product.title}\nشاهده هنا: $url',
        );

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        debugPrint("فشل التقاط الصورة: البيانات فارغة");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("عذراً، حدث خطأ أثناء تجهيز الصورة")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error sharing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("حدث خطأ غير متوقع: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // رابط المنتج
    final productUrl = _buildProductUrl();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedDialog(
        maxWidth: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ================== منطقة التصميم القابل للتصوير ==================
            Screenshot(
              controller: _screenshotController,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. رأس البطاقة (صورة المنتج)
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(20)),
                      child: SizedBox(
                        height: 250,
                        width: double.infinity,
                        child: AppNetworkImage(
                          url: widget.product.imageUrl,
                          variant: ImageVariant.heroBanner,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            height: 250,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(Icons.image, color: Colors.grey),
                            ),
                          ),
                          errorWidget: Container(
                            height: 250,
                            color: Colors.grey[200],
                            child: const Center(
                              child:
                                  Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2. تفاصيل المنتج
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "متجر الدكتور 🩺",
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.product.title,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A2647),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "${widget.product.price.toStringAsFixed(0)} د.أ",
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // 3. كود QR
                          Column(
                            children: [
                              QrImageView(
                                data: productUrl,
                                version: QrVersions.auto,
                                size: 70.0,
                                eyeStyle:
                                    const QrEyeStyle(color: Color(0xFF0A2647)),
                                dataModuleStyle: const QrDataModuleStyle(
                                    color: Color(0xFF0A2647)),
                                backgroundColor: Colors.white,
                              ),
                              const SizedBox(height: 4),
                              const Text("امسح للطلب",
                                  style: TextStyle(fontSize: 9)),
                            ],
                          )
                        ],
                      ),
                    ),

                    // 4. تذييل جمالي
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37), // اللون الذهبي
                        borderRadius:
                            BorderRadius.vertical(bottom: Radius.circular(20)),
                      ),
                      child: const Text(
                        "راحتك.. تخصصنا ✨",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ================================================================

            const SizedBox(height: 20),

            // زر المشاركة
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSharing ? null : _shareImage,
                icon: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                label: Text(
                    _isSharing ? "جاري التصميم..." : "مشاركة البطاقة كصورة"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2647),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}
