import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'undress_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  bool _isOnline = false;
  String _user = "Guest";
  Map<String, dynamic>? _systemStats;
  late TabController _subTabController;

  late List<AnimationController> _navAnimControllers;
  late List<Animation<double>> _navScaleAnims;
  late AnimationController _fabPulseController;
  late Animation<double> _fabPulseAnim;

  static const _navItems = [
    (Icons.auto_awesome_outlined, Icons.auto_awesome, '生成'),
    (Icons.monitor_outlined, Icons.monitor, '工作流'),
    (Icons.photo_library_outlined, Icons.photo_library, '素材库'),
    (Icons.auto_fix_high_outlined, Icons.auto_fix_high, '高级'),
    (Icons.settings_outlined, Icons.settings, '设置'),
  ];

  @override
  void initState() {
    super.initState();
    _navAnimControllers = List.generate(
      _navItems.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      ),
    );
    _navScaleAnims = _navAnimControllers.map((ctrl) {
      return Tween<double>(begin: 1.0, end: 1.15).animate(
        CurvedAnimation(parent: ctrl, curve: Curves.easeOutBack),
      );
    }).toList();

    _fabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _fabPulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _fabPulseController, curve: Curves.easeInOut),
    );

    _subTabController = TabController(length: 2, vsync: this);

    _load();
    Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    for (final c in _navAnimControllers) {
      c.dispose();
    }
    _fabPulseController.dispose();
    _subTabController.dispose();
    super.dispose();
  }

  void _onNavTap(int index, NavigationProvider nav) {
    HapticFeedback.lightImpact();
    _navAnimControllers[index].forward().then((_) {
      _navAnimControllers[index].reverse();
    });
    nav.setIndex(index);
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
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F18),
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
              "快速创建",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white38,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _actionItem(
                  ctx,
                  Icons.auto_awesome,
                  "文生图",
                  const Color(0xFF10B77F),
                  () {
                    nav.setIndex(0);
                    Provider.of<GeneratorProvider>(context, listen: false)
                        .setI2I(false);
                    Navigator.pop(ctx);
                  },
                ),
                _actionItem(
                  ctx,
                  Icons.edit_note,
                  "图生图",
                  const Color(0xFF6C63FF),
                  () {
                    nav.setIndex(0);
                    Provider.of<GeneratorProvider>(context, listen: false)
                        .setI2I(true);
                    Navigator.pop(ctx);
                  },
                ),
                _actionItem(
                  ctx,
                  Icons.auto_fix_high,
                  "高级",
                  const Color(0xFFFF6B6B),
                  () {
                    nav.setIndex(3);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionItem(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.3), color.withOpacity(0.08)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
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
      backgroundColor: bgSpace,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            if (nav.selectedIndex == 0) _buildSubTabs(),
            Expanded(
              child: IndexedStack(
                index: nav.selectedIndex,
                children: [
                  TabBarView(
                    controller: _subTabController,
                    children: const [
                      GeneratorScreen(),
                      MusicGeneratorScreen(),
                    ],
                  ),
                  const MonitorScreen(),
                  const LibraryScreen(),
                  const UndressScreen(),
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

  Widget _buildSubTabs() => Container(
        padding: const EdgeInsets.only(left: 20, top: 12, bottom: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TabBar(
            controller: _subTabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicator: const UnderlineTabIndicator(
              borderSide: BorderSide(color: accentEmerald, width: 3),
              insets: EdgeInsets.symmetric(horizontal: 4),
            ),
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white30,
            labelPadding: const EdgeInsets.only(right: 24, left: 4),
            labelStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontFamily: 'Inter',
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              fontFamily: 'Inter',
            ),
            tabs: const [
              Tab(text: "图片"),
              Tab(text: "音乐"),
            ],
          ),
        ),
      );

  Widget _header() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Status indicator with label
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:
                    (_isOnline ? accentEmerald : Colors.red).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      (_isOnline ? accentEmerald : Colors.red).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _pulseDot(_isOnline ? accentEmerald : Colors.red),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color:
                          _isOnline ? accentEmerald : Colors.red.withOpacity(0.9),
                      letterSpacing: 1.5,
                    ),
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
              _statChip(
                Icons.memory,
                "${((_systemStats!['vram']?['free'] ?? 0) / 1024 / 1024 / 1024).toStringAsFixed(1)}G",
              ),
              const SizedBox(width: 8),
            ],
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: accentEmerald.withOpacity(0.4), width: 2),
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

  Widget _pulseDot(Color color) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        builder: (_, v, __) {
          return Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(v * 0.7),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          );
        },
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
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _navbar(BuildContext context, NavigationProvider nav) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F18),
        border: Border(top: BorderSide(color: glassBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          // Nav items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < _navItems.length; i++) ...[
                  if (i == 2) const SizedBox(width: 56), // FAB space
                  _navItem(i, nav.selectedIndex == i, nav),
                ],
              ],
            ),
          ),
          // FAB
          Positioned(
            top: -22,
            child: _fabButton(context, nav),
          ),
        ],
      ),
    );
  }

  Widget _fabButton(BuildContext context, NavigationProvider nav) {
    return AnimatedBuilder(
      animation: _fabPulseAnim,
      builder: (_, __) => GestureDetector(
        onTap: () => _showQuickActions(context, nav),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1DE9AA), Color(0xFF10B77F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: accentEmerald.withOpacity(_fabPulseAnim.value * 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _navItem(int index, bool active, NavigationProvider nav) {
    final item = _navItems[index];
    return GestureDetector(
      onTap: () => _onNavTap(index, nav),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _navScaleAnims[index],
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  active ? item.$2 : item.$1,
                  key: ValueKey(active),
                  color: active ? accentEmerald : Colors.white30,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? accentEmerald : Colors.white30,
                ),
                child: Text(item.$3),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: 3,
                width: active ? 20 : 0,
                decoration: BoxDecoration(
                  color: accentEmerald,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
