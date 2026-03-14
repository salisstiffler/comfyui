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

class _GlobalMiniCirclePlayerState extends State<GlobalMiniCirclePlayer>
    with SingleTickerProviderStateMixin {
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;
  late Size _screenSize;
  late AnimationController _appearCtrl;
  late Animation<double> _appearAnim;
  bool _appeared = false;

  @override
  void initState() {
    super.initState();
    _appearCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _appearAnim = CurvedAnimation(
      parent: _appearCtrl,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _screenSize = MediaQuery.of(context).size;
    if (_position == const Offset(20, 100)) {
      _position = Offset(_screenSize.width - 80, _screenSize.height - 200);
    }
  }

  @override
  void dispose() {
    _appearCtrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _position += details.delta;
      _position = Offset(
        _position.dx.clamp(0.0, _screenSize.width - 64.0),
        _position.dy.clamp(0.0, _screenSize.height - 80.0),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _isDragging = false;
      if (_position.dx > _screenSize.width / 2) {
        _position = Offset(_screenSize.width - 76.0, _position.dy);
      } else {
        _position = Offset(12.0, _position.dy);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Provider.of<PlaybackProvider>(context);

    // Trigger appear animation when a track becomes available
    if (p.currentTask != null && !_appeared) {
      _appeared = true;
      _appearCtrl.forward();
    } else if (p.currentTask == null && _appeared) {
      _appeared = false;
      _appearCtrl.reverse();
    }

    if (p.currentTask == null && !_appearCtrl.isAnimating) {
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
                    ? accentEmerald.withOpacity(0.5)
                    : Colors.white12,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color:
                      accentEmerald.withOpacity(p.isPlaying ? 0.35 : 0.0),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Album Art
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: p.currentTask?.resultImageUrl != null
                      ? Image.network(
                          p.currentTask!.resultImageUrl ?? '',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
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

                // Dark overlay
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),

                // Circular Progress
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.5,
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
                    width: 38,
                    height: 38,
                    color: Colors.transparent,
                    child: Icon(
                      p.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
