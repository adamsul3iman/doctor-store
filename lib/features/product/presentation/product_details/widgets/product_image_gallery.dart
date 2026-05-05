import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:doctor_store/shared/utils/image_url_helper.dart';

/// Product Image Gallery with isolated state.
/// 
/// This widget manages its own image index state, preventing rebuilds
/// of the parent screen during image swipes.
class ProductImageGallery extends StatefulWidget {
  final String productId;
  final List<String> imageUrls;
  final double height;
  final bool showIndicators;
  final bool isFeatured;
  final VoidCallback? onImageTap;
  final ValueChanged<int>? onImageChanged;

  const ProductImageGallery({
    super.key,
    required this.productId,
    required this.imageUrls,
    required this.height,
    this.showIndicators = true,
    this.isFeatured = false,
    this.onImageTap,
    this.onImageChanged,
  });

  @override
  State<ProductImageGallery> createState() => ProductImageGalleryState();
}

class ProductImageGalleryState extends State<ProductImageGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  /// Current displayed image index (accessible for external access)
  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      widget.onImageChanged?.call(index);
    }
  }

  /// Animates to a specific image by its URL.
  /// Returns true if the image was found and animated to.
  /// Animates to a specific image by its URL.
  /// Returns true if the image was found and animated to.
  bool animateToImage(String imageUrl) {
    final index = widget.imageUrls.indexOf(imageUrl);
    if (index != -1 && _pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: widget.height,
        color: Colors.grey[100],
        child: const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // PageView Gallery
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageUrls.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final imageUrl = widget.imageUrls[index];
            return GestureDetector(
              onTap: widget.onImageTap != null
                  ? () => widget.onImageTap!()
                  : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Main Image
                  Hero(
                    tag: 'product_${widget.productId}_image_$index',
                    child: CachedNetworkImage(
                      imageUrl: buildOptimizedImageUrl(
                        imageUrl,
                        variant: ImageVariant.fullScreen,
                      ),
                      fit: BoxFit.cover,
                      memCacheHeight: 900,
                      placeholder: (c, u) => Container(color: Colors.grey[100]),
                      errorWidget: (c, u, e) => const Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.35),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  // Featured Badge
                  if (widget.isFeatured)
                    Positioned(
                      right: 16,
                      top: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "منتج مختار بعناية",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        // Page Indicators
        if (widget.showIndicators && widget.imageUrls.length > 1)
          Positioned(
            bottom: 18,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (index) {
                final isActive = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// Full-screen image gallery dialog.
/// 
/// Shows images in a modal with zoom support and infinite loop pagination.
class ProductFullscreenGallery extends StatefulWidget {
  final String productId;
  final List<String> imageUrls;
  final int initialIndex;

  const ProductFullscreenGallery({
    super.key,
    required this.productId,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<ProductFullscreenGallery> createState() =>
      _ProductFullscreenGalleryState();
}

class _ProductFullscreenGalleryState extends State<ProductFullscreenGallery> {
  late final PageController _pageController;
  late int _current;

  @override
  void initState() {
    super.initState();
    final safeInitial = widget.initialIndex.clamp(
      0,
      widget.imageUrls.length - 1,
    );
    _current = safeInitial;
    // Infinite loop: start at a high page number
    _pageController = PageController(
      initialPage: safeInitial + (widget.imageUrls.length * 1000),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // PageView with infinite loop
        PageView.builder(
          controller: _pageController,
          onPageChanged: (page) {
            setState(() {
              _current = page % widget.imageUrls.length;
            });
          },
          itemBuilder: (context, page) {
            final imageIndex = page % widget.imageUrls.length;
            final imageUrl = widget.imageUrls[imageIndex];
            return Center(
              child: Hero(
                tag: 'product_${widget.productId}_image_$imageIndex',
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.7,
                  maxScale: 4,
                  child: CachedNetworkImage(
                    imageUrl: buildOptimizedImageUrl(
                      imageUrl,
                      variant: ImageVariant.fullScreen,
                    ),
                    fit: BoxFit.contain,
                    memCacheHeight: 1600,
                    placeholder: (context, url) => Container(
                      color: Colors.black,
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        // Close Button
        Positioned(
          top: 40,
          right: 20,
          child: SafeArea(
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.6),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),

        // Page Counter & Indicators
        Positioned(
          bottom: 26,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${_current + 1}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        " / ${widget.imageUrls.length}",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.imageUrls.length,
                          (index) {
                            final isActive = index == _current;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 2.5,
                              ),
                              width: isActive ? 14 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
