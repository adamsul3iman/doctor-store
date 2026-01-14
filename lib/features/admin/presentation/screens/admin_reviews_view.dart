// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;

class AdminReviewsView extends StatefulWidget {
  const AdminReviewsView({super.key});

  @override
  State<AdminReviewsView> createState() => _AdminReviewsViewState();
}

class _AdminReviewsViewState extends State<AdminReviewsView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  String? _updatingReviewId;
  String _filter = 'all'; // all, approved, pending
  final Set<String> _selectedReviewIds = {};

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      // نجلب التقييم مع اسم المنتج المرتبط به
      final raw = await Supabase.instance.client
          .from('reviews')
          .select('*, products(title)')
          .order('created_at', ascending: false);

      if (mounted) {
        final list = raw;
        setState(() {
          _reviews = list
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoading = false;
          _selectedReviewIds.removeWhere(
            (id) => !_reviews.any((r) => r['id']?.toString() == id),
          );
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteReview(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: const Text("هل أنت متأكد من حذف هذا التعليق؟"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "حذف",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final deleted = await Supabase.instance.client
          .from('reviews')
          .delete()
          .eq('id', id)
          .select(); // نتحقق من أن صفاً واحداً على الأقل تم حذفه فعلاً (ولم تمنع RLS العملية)

      if (deleted.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لم يتم حذف التقييم. تأكد أن حساب الأدمن مضاف في جدول admins وأن سياسات RLS على reviews تسمح بالحذف.',
            ),
          ),
        );
        return;
      }

      _selectedReviewIds.remove(id);
      await _fetchReviews(); // تحديث القائمة
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("تم حذف التقييم")));
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
      );
    }
  }

  Future<void> _deleteSelectedReviews() async {
    if (_selectedReviewIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("تأكيد الحذف"),
        content: Text(
          "هل تريد حذف ${_selectedReviewIds.length} تعليقاً دفعة واحدة؟",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "حذف",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final id in _selectedReviewIds) {
        await Supabase.instance.client
            .from('reviews')
            .delete()
            .eq('id', id);
      }

      if (!mounted) return;
      setState(() {
        _selectedReviewIds.clear();
      });
      await _fetchReviews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف التعليقات المحددة')),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
      );
    }
  }

  Future<void> _toggleApproval(Map<String, dynamic> review) async {
    final id = review['id'];
    if (id == null) return;

    final currentStatus = review['is_approved'] == true;
    final newStatus = !currentStatus;

    setState(() {
      _updatingReviewId = id.toString();
    });

    try {
      final updated = await Supabase.instance.client
          .from('reviews')
          .update({'is_approved': newStatus})
          .eq('id', id)
          .select(); // نطلب الصف المحدث لنعرف إن كانت RLS منعت العملية أم لا

      if (updated.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'لم يتم تغيير حالة التعليق. تأكد أن حساب الأدمن مضاف في جدول admins وأن سياسات RLS على reviews تسمح بالتعديل.',
              ),
            ),
          );
        }
        return;
      }

      await _fetchReviews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus ? 'تم قبول التعليق' : 'تم إخفاء التعليق',
            ),
          ),
        );
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        final msg = e.message;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingReviewId = null;
        });
      }
    }
  }

  Future<void> _showReplyDialog(Map<String, dynamic> review) async {
    final id = review['id'];
    if (id == null) return;

    final TextEditingController replyCtrl = TextEditingController(
      text: review['admin_reply']?.toString() ?? '',
    );
    bool isSaving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('رد على تقييم العميل'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اكتب رد الإدارة الذي سيظهر للعميل أسفل تقييمه.\n'
                    'يمكنك مثلاً شكر العميل أو توضيح أي استفسار.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: replyCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'اكتب رد الإدارة هنا...',
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final text = replyCtrl.text.trim();
                          if (text.isEmpty) {
                            setState(() {
                              error = 'يرجى كتابة نص الرد أو إلغاء العملية.';
                            });
                            return;
                          }

                          setState(() {
                            isSaving = true;
                            error = null;
                          });

                          try {
                            await Supabase.instance.client
                                .from('reviews')
                                .update({
                                  'admin_reply': text,
                                  'admin_replied_at':
                                      DateTime.now().toUtc().toIso8601String(),
                                })
                                .eq('id', id);

                            if (mounted) {
                              Navigator.of(ctx).pop();
                              await _fetchReviews();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('تم حفظ رد الإدارة على التقييم'),
                                ),
                              );
                            }
                          } on PostgrestException catch (e) {
                            setState(() {
                              error = e.message;
                            });
                          } catch (e) {
                            setState(() {
                              error =
                                  'تعذر حفظ الرد حالياً، حاول لاحقاً. ($e)';
                            });
                          } finally {
                            setState(() {
                              isSaving = false;
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('حفظ الرد'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredReviews {
    if (_filter == 'all') return _reviews;
    if (_filter == 'approved') {
      return _reviews.where((r) => r['is_approved'] == true).toList();
    }
    if (_filter == 'pending') {
      return _reviews.where((r) => r['is_approved'] != true).toList();
    }
    return _reviews;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visibleIds = _filteredReviews
        .map((r) => r['id']?.toString())
        .whereType<String>()
        .toList();
    final allVisibleSelected = visibleIds.isNotEmpty &&
        visibleIds.every((id) => _selectedReviewIds.contains(id));

    return Column(
      children: [
        // Filter Chips + أدوات التحديد الجماعي
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('الكل (${_reviews.length})'),
                    selected: _filter == 'all',
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = 'all');
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      'معتمد (${_reviews.where((r) => r['is_approved'] == true).length})',
                    ),
                    selected: _filter == 'approved',
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = 'approved');
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      'بانتظار المراجعة (${_reviews.where((r) => r['is_approved'] != true).length})',
                    ),
                    selected: _filter == 'pending',
                    onSelected: (selected) {
                      if (selected) setState(() => _filter = 'pending');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: allVisibleSelected,
                    onChanged: _filteredReviews.isEmpty
                        ? null
                        : (_) {
                            setState(() {
                              if (allVisibleSelected) {
                                _selectedReviewIds.removeWhere(
                                  (id) => visibleIds.contains(id),
                                );
                              } else {
                                _selectedReviewIds.addAll(visibleIds);
                              }
                            });
                          },
                  ),
                  const Text('تحديد الكل (في القائمة الحالية)'),
                  const Spacer(),
                  if (_selectedReviewIds.isNotEmpty)
                    Text('المحدد: ${_selectedReviewIds.length}'),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedReviewIds.isEmpty
                        ? null
                        : _deleteSelectedReviews,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('حذف المحدد'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Reviews List
        Expanded(
          child: _filteredReviews.isEmpty
              ? const Center(child: Text('لا توجد تقييمات'))
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredReviews.length,
                  itemBuilder: (context, index) {
                    final review = _filteredReviews[index];

                    final productData = review['products'];
                    final String productTitle;
                    if (productData is Map<String, dynamic>) {
                      productTitle = (productData['title'] ?? 'منتج محذوف').toString();
                    } else if (productData is Map) {
                      productTitle = (Map<String, dynamic>.from(productData)['title'] ?? 'منتج محذوف').toString();
                    } else {
                      productTitle = 'منتج محذوف';
                    }

                    final isApproved = review['is_approved'] == true;

                    final clientRaw = review['clients'];
                    final Map<String, dynamic>? client =
                        clientRaw is Map<String, dynamic>
                            ? clientRaw
                            : (clientRaw is Map
                                ? Map<String, dynamic>.from(clientRaw)
                                : null);
                    final id = review['id']?.toString();
                    final isSelected =
                        id != null && _selectedReviewIds.contains(id);
                    final userName = review['user_name']?.toString() ??
                        client?['full_name']?.toString() ??
                        client?['email']?.toString() ??
                        'زائر';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isApproved
                              ? Colors.green.withValues(alpha: 0.3)
                              : Colors.orange.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: id == null
                                      ? null
                                      : (value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedReviewIds.add(id);
                                            } else {
                                              _selectedReviewIds.remove(id);
                                            }
                                          });
                                        },
                                ),
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      Colors.blue.withValues(alpha: 0.1),
                                  backgroundImage:
                                      client?['avatar_url'] != null
                                          ? NetworkImage(
                                              client!['avatar_url'].toString(),
                                            )
                                          : null,
                                  child: client?['avatar_url'] == null
                                      ? Text(
                                          userName.substring(0, 1).toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.blue,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (client?['email'] != null)
                                        Text(
                                          client!['email'].toString(),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  () {
                                    final rawDate = review['created_at'];
                                    DateTime dt;
                                    if (rawDate is String) {
                                      try {
                                        dt = DateTime.parse(rawDate);
                                      } catch (_) {
                                        dt = DateTime.fromMillisecondsSinceEpoch(0);
                                      }
                                    } else {
                                      dt = DateTime.fromMillisecondsSinceEpoch(0);
                                    }
                                    return timeago.format(dt, locale: 'ar');
                                  }(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag,
                                    size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    productTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0A2647),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    Icons.star,
                                    size: 14,
                                    color: i < (review['rating'] ?? 0)
                                        ? Colors.amber
                                        : Colors.grey[300],
                                  ),
                                ),
                              ],
                            ),
                            if (review['comment'] != null &&
                                review['comment'].toString().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  review['comment'].toString(),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isApproved
                                            ? Icons.check_circle
                                            : Icons.pending,
                                        size: 14,
                                        color: isApproved
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        isApproved ? 'معتمد' : 'بانتظار المراجعة',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isApproved
                                              ? Colors.green
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: () => _showReplyDialog(review),
                                  icon: const Icon(
                                    Icons.reply,
                                    size: 18,
                                    color: Color(0xFF0A2647),
                                  ),
                                  label: const Text(
                                    'رد الإدارة',
                                    style:
                                        TextStyle(color: Color(0xFF0A2647)),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      _updatingReviewId == review['id']?.toString()
                                          ? null
                                          : () => _toggleApproval(review),
                                  icon: Icon(
                                    isApproved
                                        ? Icons.visibility_off
                                        : Icons.check,
                                    size: 18,
                                  ),
                                  label: Text(
                                    isApproved ? 'إخفاء' : 'قبول',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () =>
                                      _deleteReview(review['id']),
                                  icon: const Icon(
                                    Icons.delete_forever,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'حذف',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
