import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/full_screen_gallery.dart';
import 'music_player_screen.dart';

class MonitorScreen extends StatelessWidget {
  const MonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<TaskProvider>(context);
    final tasks = prov.tasks;
    final Map<String, List<AiTask>> groups = {};
    for (var t in tasks) {
      final date = (t.status == 'running' || t.status == 'queued')
          ? "ACTIVE"
          : DateFormat('yyyy年MM月dd日').format(t.timestamp);
      groups.putIfAbsent(date, () => []).add(t);
    }
    final keys = groups.keys.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: tasks.isEmpty && !prov.isLoading
          ? _emptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: keys.length,
              itemBuilder: (ctx, idx) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 16),
                    child: Row(
                      children: [
                        if (keys[idx] == "ACTIVE")
                          _AnimatedDot()
                        else
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              shape: BoxShape.circle,
                            ),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          keys[idx],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: keys[idx] == "ACTIVE"
                                ? accentEmerald
                                : Colors.white24,
                          ),
                        ),
                        if (keys[idx] == "ACTIVE") ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentEmerald.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${groups[keys[idx]]!.length}',
                              style: const TextStyle(
                                color: accentEmerald,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  ...groups[keys[idx]]!.map(
                    (t) => _buildBentoCard(ctx, t, prov),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: const Icon(
            Icons.history_rounded,
            color: Colors.white12,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'NO RECORDS YET',
          style: TextStyle(
            color: Colors.white12,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your generation history will appear here',
          style: TextStyle(color: Colors.white10, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _buildBentoCard(
    BuildContext context,
    AiTask task,
    TaskProvider prov,
  ) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: task.status == 'running'
                ? accentEmerald.withOpacity(0.35)
                : Colors.white.withOpacity(0.05),
          ),
          boxShadow: task.status == 'running'
              ? [
                  BoxShadow(
                    color: accentEmerald.withOpacity(0.08),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Theme(
          data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            leading: _statusPulse(task.status),
            title: Text(
              task.prompt,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    _badge(
                      task.status,
                      c: task.status == 'completed'
                          ? accentEmerald
                          : (task.status == 'failed'
                              ? Colors.red
                              : Colors.amber),
                    ),
                    if (task.isMusic && task.workflowMode != null) ...[
                      const SizedBox(width: 6),
                      _badge(task.workflowMode!, c: const Color(0xFF6C63FF)),
                    ],
                  ],
                ),
                if (task.status == 'running' ||
                    task.status == 'pending' ||
                    task.status == 'queued') ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress > 0 ? task.progress : null,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation(accentEmerald),
                      minHeight: 2,
                    ),
                  ),
                ],
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),
                    _meta(
                      'SPECS',
                      'CFG: ${task.cfg} · Sampler: ${task.sampler} · Seed: ${task.seed ?? "Auto"}',
                    ),
                    const SizedBox(height: 8),
                    if (task.resultFilename != null)
                      _meta('FILE', task.resultFilename!.split('/').last),
                    if (task.isMusic && task.resultAudioUrl != null)
                      _meta(
                        'AUDIO',
                        Uri.parse(task.resultAudioUrl!).pathSegments.last,
                      ),
                    if (task.status == 'completed') ...[
                      const SizedBox(height: 12),
                      if (!task.isMusic && task.resultImageUrl != null)
                        GestureDetector(
                          onTap: () =>
                              FullScreenGallery.show(context, [task], 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              children: [
                                Image.network(
                                  task.resultImageUrl ?? '',
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (task.isMusic && task.resultAudioUrl != null)
                        GestureDetector(
                          onTap: () {
                            Provider.of<PlaybackProvider>(
                              context,
                              listen: false,
                            ).setPlaylist([task]);
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MusicPlayerScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accentEmerald.withOpacity(0.2),
                                  accentEmerald.withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accentEmerald.withOpacity(0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_filled,
                                  color: accentEmerald,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'PLAY AUDIO',
                                  style: TextStyle(
                                    color: accentEmerald,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => ApiService.cancelTask(
                          task.promptId,
                        ).then((_) => prov.refresh()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 14,
                                color: Colors.red,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'DELETE',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _statusPulse(String s) {
    final Color color = s == 'completed'
        ? accentEmerald
        : (s == 'running' ? Colors.amber : Colors.white12);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          if (s == 'running')
            BoxShadow(
              color: Colors.amber.withOpacity(0.6),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          if (s == 'completed')
            BoxShadow(
              color: accentEmerald.withOpacity(0.4),
              blurRadius: 6,
              spreadRadius: 1,
            ),
        ],
      ),
    );
  }

  Widget _badge(String t, {required Color c}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: c.withOpacity(0.25)),
    ),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        color: c,
        fontSize: 8,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _meta(String l, String v) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l,
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white24,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(height: 2),
      Text(v, style: const TextStyle(fontSize: 12, color: Colors.white60)),
    ],
  );
}

class _AnimatedDot extends StatefulWidget {
  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accentEmerald,
          boxShadow: [
            BoxShadow(
              color: accentEmerald.withOpacity(_anim.value * 0.8),
              blurRadius: 8,
              spreadRadius: _anim.value * 2,
            ),
          ],
        ),
      ),
    );
  }
}
