import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/full_screen_gallery.dart';
import 'music_player_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _tab = "IMAGES";
  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<TaskProvider>(context);
    final list = prov.tasks
        .where(
          (t) =>
              t.status == 'completed' &&
              (_tab == "IMAGES" ? !t.isMusic : t.isMusic),
        )
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, List<AiTask>> groups = {};
    for (var t in list) {
      final d = DateFormat('yyyy年MM月dd日').format(t.timestamp);
      groups.putIfAbsent(d, () => []).add(t);
    }
    final keys = groups.keys.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _tBtn("IMAGES", _tab == "IMAGES"),
                _tBtn("MUSIC", _tab == "MUSIC"),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: keys.length,
            itemBuilder: (ctx, idx) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 12),
                  child: Text(
                    keys[idx],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white24,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _tab == "IMAGES" ? 2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: _tab == "IMAGES" ? 180 : 80,
                  ),
                  itemCount: groups[keys[idx]]!.length,
                  itemBuilder: (c, i) => _item(groups[keys[idx]]![i], list),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(AiTask t, List<AiTask> full) => GestureDetector(
    onTap: () {
      if (t.isMusic) {
        final playbackProvider = Provider.of<PlaybackProvider>(
          context,
          listen: false,
        );
        // Find all music tasks in the current grid
        final musicTasks = full.where((task) => task.isMusic).toList();
        final indexOfT = musicTasks.indexOf(t);

        playbackProvider.setPlaylist(
          musicTasks,
          initialIndex: indexOfT != -1 ? indexOfT : 0,
        );

        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const MusicPlayerScreen()),
        );
      } else {
        FullScreenGallery.show(context, full, full.indexOf(t));
      }
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Positioned.fill(
            child: t.isMusic
                ? Container(
                    color: glassColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.music_note,
                          color: accentEmerald,
                          size: 36,
                        ),
                        if (t.resultAudioUrl != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              Uri.parse(t.resultAudioUrl!).pathSegments.last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : Image.network(t.resultImageUrl!, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Text(
                t.prompt,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _tBtn(String l, bool a) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _tab = l),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: a ? accentEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            l,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: a ? Colors.white : Colors.white30,
            ),
          ),
        ),
      ),
    ),
  );
}
