import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

import '../providers/player_provider.dart';
import '../theme/app_theme.dart';

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
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
      backgroundColor: bgSpace,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'PLAYLIST',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: provider.playlist.length,
                  itemBuilder: (ctx, index) {
                    final task = provider.playlist[index];
                    final isPlaying = index == provider.currentIndex;
                    return ListTile(
                      leading: task.resultImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                task.resultImageUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white54,
                              ),
                            ),
                      title: Text(
                        task.prompt.isEmpty ? "Unknown Track" : task.prompt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isPlaying ? accentEmerald : Colors.white,
                          fontWeight: isPlaying
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: const Text(
                        'AI Generated',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: isPlaying
                          ? const Icon(Icons.equalizer, color: accentEmerald)
                          : null,
                      onTap: () {
                        provider.playAtIndex(index);
                        Navigator.pop(ctx);
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

    if (provider.isPlaying && !_waveController.isAnimating) {
      _waveController.repeat(reverse: true);
    } else if (!provider.isPlaying && _waveController.isAnimating) {
      _waveController.stop();
    }

    return Scaffold(
      backgroundColor: bgSpace,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          children: [
            Text(
              'PLAYING FROM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.white54,
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
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Large Album Art
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentEmerald.withValues(alpha: 0.2),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.black26,
                        child: task.resultImageUrl != null
                            ? Image.network(
                                task.resultImageUrl!,
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
                                    size: 100,
                                    color: Colors.white30,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentEmerald.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Track Info
              Text(
                task.prompt.isEmpty ? "Unknown Track" : task.prompt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI Generated',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: accentEmerald,
                ),
              ),
              const SizedBox(height: 24),

              // Animated Waveform
              SizedBox(
                height: 48,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(20, (index) {
                        // Base heights to keep some structure
                        final baseHeights = [
                          16.0,
                          32.0,
                          24.0,
                          40.0,
                          48.0,
                          28.0,
                          36.0,
                          44.0,
                          20.0,
                          32.0,
                          24.0,
                          40.0,
                          16.0,
                          28.0,
                          36.0,
                          48.0,
                          32.0,
                          40.0,
                          24.0,
                          16.0,
                        ];
                        // If playing, animate with some randomness based on the controller value
                        double currentHeight = baseHeights[index];
                        if (provider.isPlaying) {
                          // Use sine wave based on index and animation value for smooth continuous motion
                          double phase = (index / 20.0) * math.pi * 2;
                          double wave = math.sin(
                            _waveController.value * math.pi * 2 + phase,
                          );
                          currentHeight =
                              baseHeights[index] * 0.5 +
                              (baseHeights[index] * 0.5 * wave.abs());
                        }
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: 4,
                          height: currentHeight,
                          decoration: BoxDecoration(
                            color: accentEmerald.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Progress Slider
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: accentEmerald,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: accentEmerald,
                      overlayColor: accentEmerald.withValues(alpha: 0.2),
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final maxMs = provider.duration.inMilliseconds > 0
                            ? provider.duration.inMilliseconds.toDouble()
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(provider.position),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          _formatDuration(provider.duration),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Playback Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      _getModeIcon(provider.mode),
                      color: accentEmerald,
                    ),
                    iconSize: 28,
                    onPressed: () {
                      provider.togglePlaybackMode();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white),
                    iconSize: 40,
                    onPressed: provider.previous,
                  ),
                  GestureDetector(
                    onTap: provider.togglePlay,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentEmerald,
                        boxShadow: [
                          BoxShadow(
                            color: accentEmerald.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        provider.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.black87,
                        size: 48,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    iconSize: 40,
                    onPressed: provider.next,
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music, color: Colors.white70),
                    iconSize: 28,
                    onPressed: () {
                      _showPlaylist(context, provider);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
