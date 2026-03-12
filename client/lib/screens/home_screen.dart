import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../providers/navigation_provider.dart';
import '../providers/generator_provider.dart';
import '../theme/app_theme.dart';

import 'image_generator_screen.dart';
import 'music_generator_screen.dart';
import 'monitor_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  bool _isOnline = false;
  String _user = "Guest";
  Map<String, dynamic>? _systemStats;

  @override
  void initState() {
    super.initState();
    _load();
    Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  void _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      final savedUrl = p.getString('server_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        ApiService.baseUrl = savedUrl;
      }
      _user = p.getString('username') ?? "Guest";
      ApiService.userId = _user;
    });
    _check();
  }

  void _check() async {
    try {
      final response = await ApiService.checkHealthFull();
      if (mounted) {
        setState(() {
          _isOnline = response?['status'] == 'online';
          _systemStats = response;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isOnline = false);
    }
  }

  void _showQuickActions(BuildContext context, NavigationProvider nav) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: bgSpace,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "CREATE SOMETHING NEW",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white24,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionItem(
                  ctx,
                  Icons.auto_awesome,
                  "Image",
                  () {
                    nav.setIndex(0);
                    Provider.of<GeneratorProvider>(context, listen: false).setI2I(false);
                    Navigator.pop(ctx);
                  },
                ),
                _actionItem(
                  ctx,
                  Icons.edit_note,
                  "Edit",
                  () {
                    nav.setIndex(0);
                    Provider.of<GeneratorProvider>(context, listen: false).setI2I(true);
                    Navigator.pop(ctx);
                  },
                ),
                _actionItem(
                  ctx,
                  Icons.music_note,
                  "Music",
                  () {
                    nav.setIndex(1);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _actionItem(BuildContext ctx, IconData icon, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: accentEmerald.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: accentEmerald.withOpacity(0.3)),
              ),
              child: Icon(icon, color: accentEmerald, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            _tabs(nav),
            Expanded(
              child: PageView(
                controller: nav.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const GeneratorScreen(),
                  const MusicGeneratorScreen(),
                  const MonitorScreen(),
                  const LibraryScreen(),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _navbar(context, nav),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _isOnline ? accentEmerald : Colors.red,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_isOnline ? accentEmerald : Colors.red).withOpacity(
                  0.5,
                ),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Comfy Pro Max',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const Spacer(),
        if (_systemStats != null && _isOnline) ...[
          _statChip(Icons.memory, "${((_systemStats!['vram']?['free'] ?? 0) / 1024 / 1024 / 1024).toStringAsFixed(1)}G"),
          const SizedBox(width: 8),
        ],
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentEmerald.withOpacity(0.3)),
            image: const DecorationImage(
              image: NetworkImage(
                "https://lh3.googleusercontent.com/aida-public/AB6AXuBwNfcTmuMd1GR2qJrsuGplDVN7ABP1ro_AO0ASg8GJcazrysQSW1IEmU5UaXD_ARQVTx7nFlD1YdSPr0gTC_eoPO52PLsl_IJC7qNdfEJ27i7L4p3rojbg5YwIOWl6CtHqF85H3YQaNs93OroUILiXuvcwBim4l3l8FC6mgPHParItdpB6giHV8BsM1ZWUzwNti4FUGSIe04n_FwweXGkrusoSI38Hq_a2ZJREXInvY0wKMf5bae8ErakSXUmA7gcOBm0WanOQvDlo",
              ),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _statChip(IconData icon, String val) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: glassColor,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: glassBorder),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: accentEmerald),
        const SizedBox(width: 4),
        Text(
          val,
          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _tabs(NavigationProvider nav) {
    if (nav.selectedIndex > 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _tabItem("Image", nav.selectedIndex == 0, () => nav.setIndex(0)),
          const SizedBox(width: 24),
          _tabItem("Music", nav.selectedIndex == 1, () => nav.setIndex(1)),
        ],
      ),
    );
  }

  Widget _tabItem(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? accentEmerald : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: active ? accentEmerald : Colors.white54,
            ),
          ),
        ),
      );

  Widget _navbar(BuildContext context, NavigationProvider nav) => Stack(
    alignment: Alignment.topCenter,
    clipBehavior: Clip.none,
    children: [
      Container(
        height: 90,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgSpace,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(
              Icons.home,
              "Home",
              nav.selectedIndex == 0 || nav.selectedIndex == 1,
              () => nav.setIndex(0),
            ),
            _navItem(
              Icons.explore_outlined,
              "Explore",
              nav.selectedIndex == 2,
              () => nav.setIndex(2),
            ),
            const SizedBox(width: 50),
            _navItem(
              Icons.auto_awesome_motion_outlined,
              "Library",
              nav.selectedIndex == 3,
              () => nav.setIndex(3),
            ),
            _navItem(
              Icons.settings_outlined,
              "Settings",
              nav.selectedIndex == 4,
              () => nav.setIndex(4),
            ),
          ],
        ),
      ),
      Positioned(
        top: -20,
        child: GestureDetector(
          onTap: () => _showQuickActions(context, nav),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentEmerald,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentEmerald.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 32),
          ),
        ),
      ),
    ],
  );

  Widget _navItem(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: active ? accentEmerald : Colors.white30, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: active ? accentEmerald : Colors.white30,
          ),
        ),
      ],
    ),
  );
}
