import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _rotationController;
  late AnimationController _slideInController;
  late Animation<double> _slideInAnim;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    _slideInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideInAnim = CurvedAnimation(
      parent: _slideInController,
      curve: Curves.easeOutCubic,
    );
    _slideInController.forward();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _rotationController.dispose();
    _slideInController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  void _showPlaylist(BuildContext context, PlaybackProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F18),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: glassBorder),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'PLAYLIST',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Colors.white60,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${provider.playlist.length} tracks',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white30,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.playlist.length,
                  itemBuilder: (ctx, index) {
                    final task = provider.playlist[index];
                    final isActive = index == provider.currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? accentEmerald.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive
                              ? accentEmerald.withOpacity(0.3)
                              : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: task.resultImageUrl != null
                              ? Image.network(
                                  task.resultImageUrl ?? '',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF1a2a6c),
                                        accentEmerald.withOpacity(0.4),
                                      ],
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.music_note,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ),
                        ),
                        title: Text(
                          task.prompt.isEmpty ? "Unknown Track" : task.prompt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isActive ? accentEmerald : Colors.white,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: const Text(
                          'AI Generated',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        trailing: isActive
                            ? const Icon(Icons.equalizer, color: accentEmerald, size: 20)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        onTap: () {
                          provider.playAtIndex(index);
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.loop:
        return Icons.repeat;
      case PlaybackMode.single:
        return Icons.repeat_one;
      case PlaybackMode.shuffle:
        return Icons.shuffle;
      case PlaybackMode.order:
        return Icons.format_list_numbered;
    }
  }

  String _getModeLabel(PlaybackMode mode) {
    switch (mode) {
      case PlaybackMode.loop:
        return '列表循环';
      case PlaybackMode.single:
        return '单曲循环';
      case PlaybackMode.shuffle:
        return '随机播放';
      case PlaybackMode.order:
        return '顺序播放';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PlaybackProvider>(context);
    final task = provider.currentTask;

    if (task == null) {
      return const Scaffold(
        backgroundColor: bgSpace,
        body: Center(child: Text("No Track Playing")),
      );
    }

    // Sync wave animation with play state
    if (provider.isPlaying && !_waveController.isAnimating) {
      _waveController.repeat(reverse: true);
    } else if (!provider.isPlaying && _waveController.isAnimating) {
      _waveController.stop();
    }

    // Sync rotation with play state
    if (provider.isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!provider.isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    return Scaffold(
      backgroundColor: bgSpace,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          children: [
            Text(
              'NOW PLAYING',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.5,
                color: Colors.white38,
              ),
            ),
            Text(
              'Comfy Pro Max',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white12),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Blurred backdrop
          if (task.resultImageUrl != null)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Image.network(
                  task.resultImageUrl ?? '',
                  fit: BoxFit.cover,
                  color: Colors.black.withOpacity(0.6),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: bgSpace.withOpacity(0.75),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _slideInAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(_slideInAnim),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Rotating Album Art
                      Expanded(
                        flex: 4,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: AnimatedBuilder(
                              animation: _rotationController,
                              builder: (context, child) => Transform.rotate(
                                angle: _rotationController.value * 2 * math.pi,
                                child: child,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentEmerald.withOpacity(0.25),
                                      blurRadius: 60,
                                      spreadRadius: 15,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: task.resultImageUrl != null
                                      ? Image.network(
                                          task.resultImageUrl ?? '',
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
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
                                          child: const Center(
                                            child: Icon(
                                              Icons.music_note,
                                              size: 80,
                                              color: Colors.white30,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Track Info
                      const SizedBox(height: 24),
                      Text(
                        task.prompt.isEmpty ? "Unknown Track" : task.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'AI Generated · ${_getModeLabel(provider.mode)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: accentEmerald.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Animated Waveform
                      SizedBox(
                        height: 44,
                        child: AnimatedBuilder(
                          animation: _waveController,
                          builder: (context, child) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(28, (index) {
                                final baseHeights = [
                                  10.0, 22.0, 16.0, 30.0, 38.0, 20.0,
                                  28.0, 36.0, 14.0, 24.0, 18.0, 32.0,
                                  10.0, 20.0, 28.0, 40.0, 24.0, 32.0,
                                  16.0, 10.0, 22.0, 34.0, 18.0, 26.0,
                                  38.0, 14.0, 20.0, 28.0,
                                ];
                                double currentHeight = baseHeights[index];
                                if (provider.isPlaying) {
                                  double phase = (index / 28.0) * math.pi * 2;
                                  double wave = math.sin(
                                    _waveController.value * math.pi * 2 + phase,
                                  );
                                  currentHeight = baseHeights[index] * 0.4 +
                                      (baseHeights[index] * 0.6 * wave.abs());
                                }
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1.5,
                                  ),
                                  width: 3,
                                  height: currentHeight,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        accentEmerald,
                                        accentEmerald.withOpacity(0.3),
                                      ],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Progress Slider
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              activeTrackColor: accentEmerald,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              overlayColor: accentEmerald.withOpacity(0.2),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14,
                              ),
                            ),
                            child: Builder(
                              builder: (context) {
                                final maxMs =
                                    provider.duration.inMilliseconds > 0
                                        ? provider.duration.inMilliseconds
                                            .toDouble()
                                        : 1.0;
                                final currentMs = provider.position.inMilliseconds
                                    .toDouble()
                                    .clamp(0.0, maxMs);
                                return Slider(
                                  value: currentMs,
                                  min: 0,
                                  max: maxMs,
                                  onChanged: (value) {
                                    provider.seek(
                                      Duration(milliseconds: value.toInt()),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(provider.position),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _formatDuration(provider.duration),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Playback Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Mode button
                          _controlBtn(
                            child: Icon(
                              _getModeIcon(provider.mode),
                              color: accentEmerald,
                              size: 22,
                            ),
                            onTap: provider.togglePlaybackMode,
                          ),
                          // Previous
                          _controlBtn(
                            child: const Icon(
                              Icons.skip_previous_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            onTap: provider.previous,
                          ),
                          // Play/Pause (big)
                          GestureDetector(
                            onTap: provider.togglePlay,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1DE9AA), Color(0xFF10B77F)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentEmerald.withOpacity(
                                      provider.isPlaying ? 0.4 : 0.2,
                                    ),
                                    blurRadius: provider.isPlaying ? 24 : 12,
                                    spreadRadius:
                                        provider.isPlaying ? 4 : 0,
                                  ),
                                ],
                              ),
                              child: Icon(
                                provider.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 42,
                              ),
                            ),
                          ),
                          // Next
                          _controlBtn(
                            child: const Icon(
                              Icons.skip_next_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                            onTap: provider.next,
                          ),
                          // Playlist
                          _controlBtn(
                            child: const Icon(
                              Icons.queue_music_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                            onTap: () => _showPlaylist(context, provider),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlBtn({required Widget child, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white10),
          ),
          child: Center(child: child),
        ),
      );
}
