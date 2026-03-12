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
          ? const Center(
              child: Text(
                'EMPTY RECORDS',
                style: TextStyle(color: Colors.white10, letterSpacing: 2),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: keys.length,
              itemBuilder: (ctx, idx) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 12),
                    child: Text(
                      keys[idx],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: keys[idx] == "ACTIVE"
                            ? accentEmerald
                            : Colors.white24,
                      ),
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

  Widget _buildBentoCard(
    BuildContext context,
    AiTask task,
    TaskProvider prov,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: glassColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: task.status == 'running'
            ? accentEmerald.withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
      ),
    ),
    child: Theme(
      data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: _statusPulse(task.status),
        title: Text(
          task.prompt,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _badge(
                  task.status,
                  c: task.status == 'completed'
                      ? accentEmerald
                      : (task.status == 'failed' ? Colors.red : Colors.amber),
                ),
                if (task.isMusic && task.workflowMode != null) ...[
                  const SizedBox(width: 8),
                  _badge(task.workflowMode!, c: Colors.blue),
                ],
              ],
            ),
            if (task.status == 'running' || task.status == 'pending' || task.status == 'queued') ...[
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
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: Colors.white10),
                _meta(
                  'SPECIFICATIONS',
                  'CFG: ${task.cfg} • Sampler: ${task.sampler} • Seed: ${task.seed ?? "Auto"}',
                ),
                const SizedBox(height: 8),
                if (task.resultFilename != null)
                  _meta('FILE NAME', task.resultFilename!.split('/').last),
                if (task.isMusic && task.resultAudioUrl != null)
                  _meta(
                    'AUDIO FILE',
                    Uri.parse(task.resultAudioUrl!).pathSegments.last,
                  ),
                if (task.status == 'completed') ...[
                  const SizedBox(height: 12),
                  if (!task.isMusic && task.resultImageUrl != null)
                    GestureDetector(
                      onTap: () => FullScreenGallery.show(context, [task], 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          task.resultImageUrl!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    )
                  else if (task.isMusic && task.resultAudioUrl != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        Provider.of<PlaybackProvider>(
                          context,
                          listen: false,
                        ).setPlaylist([task]);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const MusicPlayerScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('PLAY AUDIO'),
                    ),
                ],
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => ApiService.cancelTask(
                      task.promptId,
                    ).then((_) => prov.refresh()),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.white24,
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

  Widget _statusPulse(String s) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      color: s == 'completed'
          ? accentEmerald
          : (s == 'running' ? Colors.amber : Colors.white10),
      shape: BoxShape.circle,
      boxShadow: [
        if (s == 'running')
          BoxShadow(
            color: Colors.amber.withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
      ],
    ),
  );
  Widget _badge(String t, {required Color c}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900),
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
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(v, style: const TextStyle(fontSize: 10, color: Colors.white70)),
    ],
  );
}
