import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  String _tab = "IMAGES";
  late AnimationController _tabAnimCtrl;

  @override
  void initState() {
    super.initState();
    _tabAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();
  }

  @override
  void dispose() {
    _tabAnimCtrl.dispose();
    super.dispose();
  }

  void _switchTab(String tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    _tabAnimCtrl
      ..reset()
      ..forward();
  }

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
        _header(list),
        if (list.isEmpty)
          Expanded(child: _emptyState())
        else
          Expanded(
            child: FadeTransition(
              opacity: _tabAnimCtrl,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                itemCount: keys.length,
                itemBuilder: (ctx, idx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 16),
                      child: Text(
                        keys[idx],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.white24,
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _tab == "IMAGES" ? 2 : 1,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        mainAxisExtent: _tab == "IMAGES" ? 190 : 110,
                      ),
                      itemCount: groups[keys[idx]]!.length,
                      itemBuilder: (c, i) =>
                          _item(groups[keys[idx]]![i], list),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _header(List<AiTask> list) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Row(
      children: [
        // Segmented Tab Switcher
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: glassBorder),
            ),
            child: Row(
              children: [
                _tBtn("IMAGES", Icons.photo_library_outlined, _tab == "IMAGES"),
                _tBtn("MUSIC", Icons.music_note_outlined, _tab == "MUSIC"),
              ],
            ),
          ),
        ),
        if (_tab == "MUSIC" && list.isNotEmpty) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              final playback = Provider.of<PlaybackProvider>(
                context,
                listen: false,
              );
              playback.setPlaylist(list);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MusicPlayerScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentEmerald.withOpacity(0.3),
                    accentEmerald.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentEmerald.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: accentEmerald, size: 16),
                  SizedBox(width: 4),
                  Text(
                    '全部播放',
                    style: TextStyle(
                      color: accentEmerald,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _tab == "IMAGES"
              ? Icons.photo_library_outlined
              : Icons.music_note_outlined,
          color: Colors.white10,
          size: 48,
        ),
        const SizedBox(height: 16),
        Text(
          _tab == "IMAGES" ? 'NO IMAGES YET' : 'NO MUSIC YET',
          style: const TextStyle(
            color: Colors.white12,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ],
    ),
  );

  Widget _item(AiTask t, List<AiTask> full) => GestureDetector(
    onTap: () {
      if (t.isMusic) {
        final playbackProvider = Provider.of<PlaybackProvider>(
          context,
          listen: false,
        );
        final musicTasks = full.where((task) => task.isMusic).toList();
        final indexOfT = musicTasks.indexOf(t);

        playbackProvider.setPlaylist(
          musicTasks,
          initialIndex: indexOfT != -1 ? indexOfT : 0,
        );

        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (ctx, anim, _) => const MusicPlayerScreen(),
            transitionsBuilder: (ctx, anim, _, child) => SlideTransition(
              position: Tween(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          ),
        );
      } else {
        FullScreenGallery.show(context, full, full.indexOf(t));
      }
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (t.isMusic)
            _musicCard(t)
          else
            CachedNetworkImage(
              imageUrl: t.resultImageUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.white.withOpacity(0.05),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentEmerald),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => const Icon(Icons.error_outline, color: Colors.white24),
            ),
          // Gradient overlay + label
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 8),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _musicCard(AiTask t) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF1a2a6c).withOpacity(0.8),
          accentEmerald.withOpacity(0.15),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -10,
          bottom: -10,
          child: Icon(
            Icons.music_note_rounded,
            size: 80,
            color: accentEmerald.withOpacity(0.07),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentEmerald.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentEmerald.withOpacity(0.3)),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: accentEmerald,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              if (t.resultAudioUrl != null)
                Text(
                  Uri.parse(t.resultAudioUrl!).pathSegments.last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _tBtn(String l, IconData icon, bool a) => Expanded(
    child: GestureDetector(
      onTap: () => _switchTab(l),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: a ? accentEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: a ? Colors.white : Colors.white30,
            ),
            const SizedBox(width: 6),
            Text(
              l,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: a ? Colors.white : Colors.white30,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
