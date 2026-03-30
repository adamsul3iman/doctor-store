import 'dart:async';

import 'package:flutter/material.dart';
import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:doctor_store/features/product/presentation/widgets/product_card.dart';
import 'package:doctor_store/shared/utils/responsive_layout.dart';
import 'package:doctor_store/shared/services/smart_search_service.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Product> _results = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String _currentQuery = '';
  int _currentPage = 0;
  static const int _pageSize = 20;
  
  // ✅ Debounce timer
  Timer? _debounceTimer;
  
  // ✅ LRU Cache for search results
  final _searchCache = _LRUCache<String, List<Product>>(capacity: 10);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final initialQuery = widget.initialQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      _controller.text = initialQuery;
      _currentQuery = initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _search(initialQuery, reset: true);
      });
    }
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (!_scrollController.hasReachedEnd) return;
    if (_isLoading || !_hasMore) return;
    _loadMore();
  }
  
  void _onSearchChanged(String query) {
    // ✅ Cancel previous timer
    _debounceTimer?.cancel();
    
    // ✅ Set new debounce timer (500ms)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _search(query, reset: true);
      }
    });
  }

  Future<void> _search(String query, {bool reset = false}) async {
    final trimmed = query.trim();
    
    if (trimmed.isEmpty) {
      setState(() {
        _results.clear();
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }
    
    if (reset) {
      _currentPage = 0;
      _hasMore = true;
      _currentQuery = trimmed;
      _results.clear();
    }
    
    // ✅ Check cache first
    final cacheKey = '${trimmed}_$_currentPage';
    final cached = _searchCache.get(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _results.addAll(cached);
        _isLoading = false;
      });
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // ✅ Use SmartSearchService with pagination
      final results = await SmartSearchService.instance.smartSearchPaginated(
        trimmed,
        page: _currentPage,
        pageSize: _pageSize,
      );
      
      // ✅ Cache results
      _searchCache.put(cacheKey, results);
      
      if (mounted) {
        setState(() {
          _results.addAll(results);
          _hasMore = results.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("خطأ في عملية البحث: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("حدث خطأ أثناء البحث")),
        );
      }
    }
  }
  
  Future<void> _loadMore() async {
    if (_currentQuery.isEmpty) return;
    _currentPage++;
    await _search(_currentQuery, reset: false);
  }

  Future<void> _refresh() async {
    if (_currentQuery.isEmpty) return;
    _searchCache.clear();
    await _search(_currentQuery, reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search, // تغيير زر الكيبورد لـ "بحث"
          decoration: const InputDecoration(
            hintText: "ابحث عن منتج بالاسم أو الوصف...",
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: (query) => _search(query, reset: true),
          onChanged: _onSearchChanged,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _results.isEmpty && _controller.text.isEmpty
          ? const Center(child: Text("ابدأ بكتابة اسم المنتج للبحث"))
          : _results.isEmpty && !_isLoading
            ? const Center(child: Text("لم نجد نتائج تطابق بحثك!"))
            : LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = ResponsiveLayout.gridCountForWidth(
                    constraints.maxWidth,
                    desiredItemWidth: 120,
                    minCount: 3,
                    maxCount: 5,
                  );
                  final isCompact = crossAxisCount >= 3;
                  const spacing = 12.0;
                  final mainAxisExtent = ResponsiveLayout.productCardMainAxisExtent(
                    constraints.maxWidth,
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: spacing,
                    isCompact: isCompact,
                  );

                  return GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: mainAxisExtent,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                    ),
                    itemCount: _results.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _results.length) {
                        return _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : const SizedBox.shrink();
                      }
                      return ProductCard(
                        product: _results[index],
                        isCompact: isCompact,
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// ✅ LRU Cache for search results
class _LRUCache<K, V> {
  final int capacity;
  final _cache = <K, V>{};
  final _accessOrder = <K>[];

  _LRUCache({required this.capacity});

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    _updateAccess(key);
    return _cache[key];
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
      _updateAccess(key);
    } else {
      if (_cache.length >= capacity) {
        final oldest = _accessOrder.removeAt(0);
        _cache.remove(oldest);
      }
      _cache[key] = value;
      _accessOrder.add(key);
    }
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  void _updateAccess(K key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }
}

/// ✅ Extension for scroll controller pagination
extension _ScrollControllerExtension on ScrollController {
  bool get hasReachedEnd {
    if (!hasClients) return false;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    return currentScroll >= maxScroll * 0.9; // Trigger at 90%
  }
}