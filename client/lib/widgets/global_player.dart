import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../screens/music_player_screen.dart';

class GlobalMiniCirclePlayer extends StatefulWidget {
  const GlobalMiniCirclePlayer({super.key});

  @override
  State<GlobalMiniCirclePlayer> createState() => _GlobalMiniCirclePlayerState();
}

class _GlobalMiniCirclePlayerState extends State<GlobalMiniCirclePlayer>
    with TickerProviderStateMixin {
  Offset _position = Offset.zero;
  double _yFromBottom = 170.0;
  bool _isDragging = false;
  bool _isAtRight = true;
  late Size _screenSize;
  
  late AnimationController _appearCtrl;
  late Animation<double> _appearAnim;
  
  late AnimationController _rotateCtrl;
  
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    _appearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _appearAnim = CurvedAnimation(
      parent: _appearCtrl,
      curve: Curves.easeOutBack,
    );
    
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSize = MediaQuery.of(context).size;
    if (newSize.width <= 0 || newSize.height <= 0) return;

    if (_position == Offset.zero) {
      // 初始位置：右下角，距离底部 170
      _position = Offset(newSize.width - 76.0, newSize.height - _yFromBottom);
      _isAtRight = true;
    } else {
      // 窗口缩放时，同时保持水平磁吸和垂直相对底部的距离
      double newX = _isAtRight ? newSize.width - 76.0 : 12.0;
      double newY = (newSize.height - _yFromBottom).clamp(20.0, newSize.height - 106.0 - 64.0);
      _position = Offset(newX, newY);
    }
    _screenSize = newSize;
  }

  @override
  void dispose() {
    _appearCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _position += details.delta;
      // 拖拽时也遵循 y 轴限制 (导航栏上方)
      _position = Offset(
        _position.dx.clamp(0.0, _screenSize.width - 64.0),
        _position.dy.clamp(20.0, _screenSize.height - 106.0 - 64.0),
      );
      _yFromBottom = _screenSize.height - _position.dy;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      if (_position.dx > _screenSize.width / 2) {
        _position = Offset(_screenSize.width - 76.0, _position.dy);
        _isAtRight = true;
      } else {
        _position = Offset(12.0, _position.dy);
        _isAtRight = false;
      }
      _yFromBottom = _screenSize.height - _position.dy;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<PlaybackProvider>(context);

    // Sync appearance state with provider safely
    if (p.currentTask != null && !_appeared) {
      _appeared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _appearCtrl.forward();
      });
    } else if (p.currentTask == null && _appeared) {
      _appeared = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _appearCtrl.reverse();
      });
    }
    
    // 同步旋转动画
    if (p.isPlaying) {
      if (!_rotateCtrl.isAnimating) _rotateCtrl.repeat();
    } else {
      if (_rotateCtrl.isAnimating) _rotateCtrl.stop();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_appearAnim, _rotateCtrl]),
      builder: (context, child) {
        if (_appearAnim.value == 0 && !_appearCtrl.isAnimating) {
          return const SizedBox.shrink();
        }
        
        double progress = 0.0;
        if (p.duration.inMilliseconds > 0) {
          progress = p.position.inMilliseconds / p.duration.inMilliseconds;
        }

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: ScaleTransition(
            scale: _appearAnim,
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const MusicPlayerScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          const begin = Offset(0.0, 1.0);
                          const end = Offset.zero;
                          const curve = Curves.easeInOutQuart;
                          var tween = Tween(begin: begin, end: end).chain(
                            CurveTween(curve: curve),
                          );
                          return SlideTransition(
                            position: animation.drive(tween),
                            child: child,
                          );
                        },
                  ),
                );
              },
              child: AnimatedContainer(
                duration:
                    _isDragging ? Duration.zero : const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D1F18),
                  border: Border.all(
                    color: p.isPlaying
                        ? accentEmerald.withOpacity(0.8)
                        : Colors.white12,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.6),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                    if (p.isPlaying)
                      BoxShadow(
                        color: accentEmerald.withOpacity(0.4),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Album Art with Rotation
                    RotationTransition(
                      turns: _rotateCtrl,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: p.currentTask?.resultImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: p.currentTask!.resultImageUrl ?? '',
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.black26),
                                errorWidget: (context, url, error) => const Icon(Icons.music_note_rounded, color: Colors.white24),
                              )
                            : Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF1a2a6c),
                                      Color(0xFF10B77F),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white38,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),

                    // Dark overlay
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.4),
                      ),
                    ),

                    // Circular Progress
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3.0,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          accentEmerald,
                        ),
                        backgroundColor: Colors.white10,
                      ),
                    ),

                    // Play/Pause icon (tap handled by outer GestureDetector onTap)
                    GestureDetector(
                      onTap: p.togglePlay,
                      child: Container(
                        width: 40,
                        height: 40,
                        color: Colors.transparent,
                        child: Icon(
                          p.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
