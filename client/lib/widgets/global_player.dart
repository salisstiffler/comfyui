import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../screens/music_player_screen.dart';

class GlobalMiniCirclePlayer extends StatefulWidget {
  const GlobalMiniCirclePlayer({super.key});

  @override
  State<GlobalMiniCirclePlayer> createState() => _GlobalMiniCirclePlayerState();
}

class _GlobalMiniCirclePlayerState extends State<GlobalMiniCirclePlayer> {
  Offset _position = const Offset(
    20,
    100,
  ); // Initial position from bottom-right (handled in build via MediaQuery)
  bool _isDragging = false;
  late Size _screenSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
    // Set initial position to bottom right if it hasn't been set yet
    if (_position == const Offset(20, 100)) {
      _position = Offset(_screenSize.width - 80, _screenSize.height - 180);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _position += details.delta;

      // Constrain to screen bounds
      _position = Offset(
        _position.dx.clamp(0.0, _screenSize.width - 60.0),
        _position.dy.clamp(0.0, _screenSize.height - 60.0),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      // Snap to nearest edge (left or right)
      if (_position.dx > _screenSize.width / 2) {
        _position = Offset(
          _screenSize.width - 70.0,
          _position.dy,
        ); // Snap right
      } else {
        _position = Offset(10.0, _position.dy); // Snap left
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<PlaybackProvider>(context);
    if (p.currentTask == null) return const SizedBox.shrink();

    // Calculate progress for circular border
    double progress = 0.0;
    if (p.duration.inMilliseconds > 0) {
      progress = p.position.inMilliseconds / p.duration.inMilliseconds;
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
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
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
            ),
          );
        },
        child: AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgSpace,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: accentEmerald.withValues(alpha: p.isPlaying ? 0.4 : 0.0),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Album Art Background
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: p.currentTask!.resultImageUrl != null
                    ? Image.network(
                        p.currentTask!.resultImageUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1a2a6c),
                              Color(0xFFb21f1f),
                              Color(0xFFfdbb2d),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white54,
                          size: 24,
                        ),
                      ),
              ),

              // Dark overlay for visibility
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),

              // Circular Progress Indicator
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    accentEmerald,
                  ),
                  backgroundColor: Colors.transparent,
                ),
              ),

              // Play/Pause Icon
              GestureDetector(
                onTap: p.togglePlay,
                child: Container(
                  width: 36,
                  height: 36,
                  color: Colors.transparent, // intercepts taps
                  child: Icon(
                    p.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
