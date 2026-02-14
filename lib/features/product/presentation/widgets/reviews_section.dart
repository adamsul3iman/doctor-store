import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:doctor_store/shared/widgets/constrained_dialog.dart';

// ignore_for_file: use_build_context_synchronously

class ReviewsSection extends StatefulWidget {
  final String productId;
  final double averageRating;
  final int ratingCount;

  // ممر اختباري اختياري: لو مررنا قائمة مراجعات جاهزة، لن نقوم بطلب Supabase.
  final List<Map<String, dynamic>>? initialReviews;

  const ReviewsSection({
    super.key,
    required this.productId,
    required this.averageRating,
    required this.ratingCount,
    this.initialReviews,
  });

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  Map<int, int> _starCounts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String _sortMode = 'newest'; // newest, highest

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());

    // في الاختبارات يمكن تمرير قائمة جاهزة لتفادي استدعاء Supabase
    if (widget.initialReviews != null) {
      _reviews = List<Map<String, dynamic>>.from(widget.initialReviews!);
      // حساب التوزيع النجمي بشكل مبسط من القائمة الممرَّرة
      final Map<int, int> counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (final r in _reviews) {
        final rawRating = r['rating'];
        final rating = rawRating is num ? rawRating.toInt() : 0;
        if (counts.containsKey(rating)) {
          counts[rating] = (counts[rating] ?? 0) + 1;
        }
      }
      _starCounts = counts;
      _isLoading = false;
    } else {
      _fetchReviews();
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final raw = await Supabase.instance.client
          .from('reviews')
          .select()
          .eq('product_id', widget.productId)
          // لا نظهر في صفحة المنتج إلا التقييمات المعتمدة من الأدمن
          .eq('is_approved', true)
          .order('created_at', ascending: false);

      // تحويل دفاعي إلى List<Map<String, dynamic>>
      final List<Map<String, dynamic>> data = [];
      final list = raw;
      for (final item in list) {
        data.add(item);
            }
      
      Map<int, int> counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
      for (var r in data) {
        final rawRating = r['rating'];
        final rating = rawRating is num ? rawRating.toInt() : 0;
        if (counts.containsKey(rating)) {
          counts[rating] = (counts[rating] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _reviews = data;
          _starCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reviews: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ الدالة الذكية للتحقق من المستخدم
  Future<void> _checkUserAndShowReviewSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final userEmail = prefs.getString('user_email');
    final userName = prefs.getString('user_name');

    // 1. هل المستخدم مسجل دخول (عن طريق التطبيق أو الدخول السريع السابق)؟
    if (userEmail != null && userEmail.isNotEmpty) {
      _showReviewBottomSheet(userName ?? "عميل", userEmail);
    } else {
      // 2. إذا لم يكن مسجلاً، اطلب منه الاسم والإيميل لمرة واحدة
      _showGuestLoginDialog();
    }
  }

  // نافذة طلب البيانات (للزوار)
  void _showGuestLoginDialog() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: ConstrainedDialog(
              maxWidth: 550,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A2647).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.rate_review_outlined, color: Color(0xFF0A2647), size: 30),
                  ),
                  const SizedBox(height: 15),
                  Text("رأيك يهمنا! ✨", style: GoogleFonts.almarai(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    "نود سماع تجربتك. يرجى كتابة اسمك وبريدك الإلكتروني لتوثيق التقييم.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: "الاسم",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "البريد الإلكتروني",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () async {
                        if (nameCtrl.text.isEmpty || !emailCtrl.text.contains('@')) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى إدخال بيانات صحيحة")));
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        // حفظ البيانات محلياً
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('user_name', nameCtrl.text.trim());
                        await prefs.setString('user_email', emailCtrl.text.trim());

                        if (!mounted) return;

                        Navigator.pop(context); // إغلاق النافذة
                        _showReviewBottomSheet(nameCtrl.text.trim(), emailCtrl.text.trim()); // فتح التقييم
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2647),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("متابعة للتقييم", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  // نافذة التقييم
  void _showReviewBottomSheet(String userName, String userEmail) {
    double userRating = 0;
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("كيف كانت تجربتك يا $userName؟", style: GoogleFonts.almarai(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) => const Icon(Icons.star, color: Color(0xFFD4AF37)),
              onRatingUpdate: (rating) {
                userRating = rating;
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "اكتب تفاصيل تجربتك هنا...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (userRating == 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("يرجى اختيار عدد النجوم")));
                    return;
                  }
                  
                  try {
                        await Supabase.instance.client.from('reviews').insert({
                          'product_id': widget.productId,
                          'rating': userRating.toInt(),
                          'comment': commentCtrl.text,
                          'user_name': userName,
                          'user_email': userEmail,
                          // التقييمات الجديدة تبدأ كـ "بانتظار المراجعة" حتى يعتمدها الأدمن
                          'is_approved': false,
                        });
                        
                        if (!mounted) return;

                        Navigator.pop(context);
                        _fetchReviews(); // تحديث القائمة فوراً
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("شكراً لتقييمك! تم النشر بنجاح")));
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("حدث خطأ: $e")));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2647), foregroundColor: Colors.white),
                child: const Text("نشر التقييم"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text("تقييمات العملاء", style: GoogleFonts.almarai(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        
        const SizedBox(height: 20),

        if (widget.ratingCount > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      widget.averageRating.toStringAsFixed(1),
                      style: GoogleFonts.almarai(fontSize: 45, fontWeight: FontWeight.bold, color: const Color(0xFF0A2647)),
                    ),
                    RatingBarIndicator(
                      rating: widget.averageRating,
                      itemBuilder: (context, index) => const Icon(Icons.star, color: Color(0xFFD4AF37)),
                      itemCount: 5,
                      itemSize: 18.0,
                    ),
                    const SizedBox(height: 5),
                    Text("${widget.ratingCount} تقييم", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _buildStarBar(5, _starCounts[5]!),
                      _buildStarBar(4, _starCounts[4]!),
                      _buildStarBar(3, _starCounts[3]!),
                      _buildStarBar(2, _starCounts[2]!),
                      _buildStarBar(1, _starCounts[1]!),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.rate_review_outlined, size: 50, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  const Text("كن أول من يقيم هذا المنتج!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _checkUserAndShowReviewSheet,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("أضف تجربتك للمنتج"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: Color(0xFF0A2647)),
                foregroundColor: const Color(0xFF0A2647),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        if (_reviews.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildSortChips(),
          ),

        const SizedBox(height: 20),

        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_reviews.isNotEmpty) ...[
          _buildReviewsList(),
        ]
        else
          const SizedBox.shrink(),

        const SizedBox(height: 50),
      ],
    );
  }

  List<Map<String, dynamic>> _getSortedReviews() {
    final list = List<Map<String, dynamic>>.from(_reviews);

    DateTime safeParseDate(dynamic value) {
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          debugPrint('Handled Error (reviews_section _safeParseDate): $e');
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    if (_sortMode == 'highest') {
      list.sort((a, b) {
        final ra = (a['rating'] as num?)?.toDouble() ?? 0.0;
        final rb = (b['rating'] as num?)?.toDouble() ?? 0.0;
        final cmp = rb.compareTo(ra);
        if (cmp != 0) return cmp;
        final da = safeParseDate(a['created_at']);
        final db = safeParseDate(b['created_at']);
        return db.compareTo(da);
      });
    } else {
      list.sort((a, b) {
        final da = safeParseDate(a['created_at']);
        final db = safeParseDate(b['created_at']);
        return db.compareTo(da); // الأحدث أولاً
      });
    }

    return list;
  }

  Widget _buildSortChips() {
    final options = [
      {'id': 'newest', 'label': 'الأحدث'},
      {'id': 'highest', 'label': 'الأعلى تقييمًا'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final id = opt['id'] as String;
          final label = opt['label'] as String;
          final isSelected = _sortMode == id;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8.0),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => setState(() => _sortMode = id),
              selectedColor: const Color(0xFF0A2647),
              backgroundColor: Colors.grey.shade100,
              labelStyle: GoogleFonts.almarai(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : const Color(0xFF0A2647),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAllReviewsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.8;
        return SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'كل التقييمات',
                      style: GoogleFonts.almarai(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSortChips(),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final sorted = _getSortedReviews();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: sorted.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildReviewCard(sorted[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsList() {
    final sorted = _getSortedReviews();
    final visibleReviews = sorted.take(3).toList();

    return Column(
      children: [
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleReviews.length,
          separatorBuilder: (c, i) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final review = visibleReviews[index];
            return _buildReviewCard(review);
          },
        ),
        if (sorted.length > 3)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: TextButton.icon(
              onPressed: _showAllReviewsBottomSheet,
              icon: const Icon(Icons.open_in_full),
              label: Text(
                'عرض كل التقييمات',
                style: GoogleFonts.almarai(fontWeight: FontWeight.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A2647),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStarBar(int star, int count) {
    double percent = widget.ratingCount == 0 ? 0 : count / widget.ratingCount;
    // حماية إضافية: أحياناً قد لا تتطابق أرقام backend مع ratingCount، فنضمن أن القيمة بين 0 و 1
    if (percent.isNaN || percent.isInfinite) {
      percent = 0;
    } else if (percent < 0) {
      percent = 0;
    } else if (percent > 1) {
      percent = 1;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text("$star", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
          const Icon(Icons.star, size: 10, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: LinearPercentIndicator(
              lineHeight: 6.0,
              percent: percent,
              barRadius: const Radius.circular(5),
              progressColor: const Color(0xFFD4AF37),
              backgroundColor: Colors.grey[200],
              animation: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    DateTime date;
    final rawDate = review['created_at'];
    if (rawDate is String) {
      try {
        date = DateTime.parse(rawDate);
      } catch (_) {
        date = DateTime.fromMillisecondsSinceEpoch(0);
      }
    } else {
      date = DateTime.fromMillisecondsSinceEpoch(0);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.grey[200],
                child: () {
                  final rawName = review['user_name']?.toString() ?? '';
                  final safeName = rawName.trim().isNotEmpty ? rawName.trim() : 'عميل';
                  final firstLetter = safeName[0].toUpperCase();
                  return Text(
                    firstLetter,
                    style: const TextStyle(color: Colors.black),
                  );
                }(),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (review['user_name'] ?? 'عميل').toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    timeago.format(date, locale: 'ar'),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          RatingBarIndicator(
            rating: (review['rating'] as num?)?.toDouble() ?? 0.0,
            itemBuilder: (context, index) => const Icon(Icons.star, color: Color(0xFFD4AF37)),
            itemCount: 5,
            itemSize: 14.0,
          ),
          const SizedBox(height: 8),
          Text(
            (review['comment'] ?? '').toString(),
            style: const TextStyle(height: 1.5, color: Colors.black87),
          ),
          if (review['admin_reply'] != null &&
              review['admin_reply'].toString().trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // أزرق فاتح خفيف
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified,
                    color: Color(0xFF1E88E5),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رد الإدارة',
                          style: GoogleFonts.almarai(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E88E5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review['admin_reply'].toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1F2933),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
