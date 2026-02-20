import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart'; // ⚠️ REMOVED for smaller bundle

class SmartDescription extends StatefulWidget {
  final String description;

  const SmartDescription({super.key, required this.description});

  @override
  State<SmartDescription> createState() => _SmartDescriptionState();
}

class _SmartDescriptionState extends State<SmartDescription> with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  late List<String> _lines;

  @override
  void initState() {
    super.initState();
    // تنظيف النص وتقسيمه بذكاء
    _lines = widget.description
        .replaceAll(RegExp(r'\n+'), '\n') // إزالة الأسطر الفارغة المتكررة
        .split('\n')
        .where((line) => line.trim().isNotEmpty) // حذف الأسطر الفارغة تماماً
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // إذا كان النص قصيراً (أقل من 6 أسطر) نعرضه كله، وإلا نختصره
    final bool isLongText = _lines.length > 6;
    final List<String> visibleLines = (isExpanded || !isLongText) ? _lines : _lines.take(5).toList();

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB), // خلفية رمادية فاتحة جداً مريحة للعين
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...visibleLines.map((line) => _buildSmartLine(line)),
            
            // زر قراءة المزيد بتصميم جميل
            if (isLongText)
              GestureDetector(
                onTap: () => setState(() => isExpanded = !isExpanded),
                child: Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isExpanded 
                          ? [Colors.white, Colors.white] 
                          : [Colors.white.withValues(alpha: 0.1), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? "عرض تفاصيل أقل" : "قراءة باقي التفاصيل",
                        style: TextStyle(
                          color: const Color(0xFF0A2647),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: const Color(0xFF0A2647),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartLine(String rawLine) {
    String line = rawLine.trim();
    
    // 1. تحليل الخصائص (مثل: "اللون: أحمر" أو "المقاس : كبير")
    if (line.contains(':') && line.length < 50) {
      final parts = line.split(':');
      if (parts.length == 2) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF0A2647)),
              const SizedBox(width: 8),
              Text(
                "${parts[0].trim()}: ",
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800]),
              ),
              Expanded(
                child: Text(
                  parts[1].trim(),
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
        );
      }
    }

    // 2. تحليل العناوين (أسطر قصيرة لا تنتهي بنقطة وليست قائمة)
    // نعتبر السطر عنواناً إذا كان قصيراً ولا يحتوي على رموز القوائم
    bool isHeading = line.length < 35 && 
                     !line.endsWith('.') && 
                     !line.startsWith('-') && 
                     !line.startsWith('•');

    if (isHeading) {
      return Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        padding: const EdgeInsets.only(right: 8),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Color(0xFFD4AF37), width: 3)), // خط ذهبي بجانب العنوان
        ),
        child: Text(
          line,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0A2647),
          ),
        ),
      );
    }

    // 3. تحليل القوائم (أي سطر يبدأ برمز أو رقم)
    bool isListItem = line.startsWith('-') || 
                      line.startsWith('•') || 
                      line.startsWith('*') || 
                      RegExp(r'^\d+\.').hasMatch(line);

    if (isListItem) {
      // حذف الرمز من البداية لعرض نظيف
      String content = line.replaceAll(RegExp(r'^[-•*]|\d+\.'), '').trim();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 8),
              child: Icon(Icons.circle, size: 6, color: Color(0xFFD4AF37)),
            ),
            Expanded(
              child: Text(
                content,
                style: TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    // 4. النص العادي (الفقرات)
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        line,
        style: TextStyle(
          fontSize: 14,
          height: 1.8, // تباعد أسطر ممتاز للقراءة
          color: Colors.grey[700],
        ),
      ),
    );
  }
}