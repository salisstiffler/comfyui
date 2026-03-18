import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';

class FullScreenGallery extends StatefulWidget {
  final List<AiTask> images;
  final int initialIndex;
  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  static void show(BuildContext context, List<AiTask> list, int idx) =>
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (_, __, ___) => FullScreenGallery(images: list, initialIndex: idx),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showInfo = false;
  late PhotoViewController _photoViewController;
  final FocusNode _focusNode = FocusNode();

  // Pull-to-dismiss logic
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _photoViewController = PhotoViewController();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _photoViewController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTask = widget.images[_currentIndex];
    // Calculate scale and opacity based on drag offset
    final dragFactor = (_dragOffset / 300).clamp(0.0, 1.0);
    final currentScale = (1.0 - (dragFactor * 0.3)).clamp(0.7, 1.0);
    final bgOpacity = (1.0 - (dragFactor * 0.8)).clamp(0.0, 1.0);

    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _next();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _prev();
          } else if (event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.98 * bgOpacity),
        body: Stack(
          children: [
            // Pull-to-dismiss Wrapper
            GestureDetector(
              onVerticalDragUpdate: (details) {
                // Only allow drag-to-dismiss if image is not zoomed
                if ((_photoViewController.scale ?? 1.0) <= 1.0) {
                  setState(() {
                    _isDragging = true;
                    _dragOffset += details.delta.dy;
                    if (_dragOffset < 0) _dragOffset = 0; // Only pull down
                  });
                }
              },
              onVerticalDragEnd: (details) {
                if (_dragOffset > 150 || details.primaryVelocity! > 800) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _isDragging = false;
                    _dragOffset = 0.0;
                  });
                }
              },
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Transform.scale(
                  scale: currentScale,
                  child: PhotoViewGallery.builder(
                    scrollPhysics: _isDragging ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                    builder: (BuildContext context, int index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: NetworkImage(widget.images[index].resultImageUrl ?? ''),
                        controller: index == _currentIndex ? _photoViewController : null,
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained * 0.5,
                        maxScale: PhotoViewComputedScale.covered * 10,
                        heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index].promptId),
                        onTapUp: (context, details, controllerValue) {
                          if (!_isDragging) setState(() => _showInfo = !_showInfo);
                        },
                      );
                    },
                    itemCount: widget.images.length,
                    loadingBuilder: (context, event) => const Center(child: CircularProgressIndicator(color: accentEmerald)),
                    backgroundDecoration: const BoxDecoration(color: Colors.transparent),
                    pageController: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _photoViewController.scale = 1.0;
                      });
                    },
                  ),
                ),
              ),
            ),

            // Top Bar (Hide when dragging)
            if (!_isDragging)
              Positioned(
                top: 0, left: 0, right: 0,
                child: AnimatedOpacity(
                  opacity: _showInfo ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'RobotoMono'),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 24),
                          onPressed: () => setState(() => _showInfo = !_showInfo),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              ),

            // Navigation Arrows (Hide when dragging)
            if (!_isDragging && _currentIndex > 0)
              Positioned(
                left: 16, top: 0, bottom: 0,
                child: Center(child: _navCircle(Icons.arrow_back_ios_new_rounded, _prev)),
              ),
            if (!_isDragging && _currentIndex < widget.images.length - 1)
              Positioned(
                right: 16, top: 0, bottom: 0,
                child: Center(child: _navCircle(Icons.arrow_forward_ios_rounded, _next)),
              ),

            // Info Overlay (Hide when dragging)
            if (!_isDragging)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutQuint,
                bottom: _showInfo ? 0 : -500,
                left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1410).withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.8), blurRadius: 30)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: accentEmerald.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                            child: const Text("DETAILS", style: TextStyle(color: accentEmerald, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white24),
                            onPressed: () => setState(() => _showInfo = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(currentTask.prompt, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500), maxLines: 8, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: [
                          _infoChip(Icons.speed, 'Steps: ${currentTask.steps}'),
                          _infoChip(Icons.tune, 'CFG: ${currentTask.cfg}'),
                          _infoChip(Icons.grain, 'Seed: ${currentTask.seed ?? "Random"}'),
                          _infoChip(Icons.aspect_ratio, '${currentTask.width}x${currentTask.height}'),
                        ],
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

  Widget _navCircle(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44, height: 44,
      decoration: BoxDecoration(color: Colors.black26, shape: BoxShape.circle, border: Border.all(color: Colors.white10)),
      child: Icon(icon, color: Colors.white70, size: 18),
    ),
  );

  Widget _infoChip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: accentEmerald),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
