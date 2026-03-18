import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../providers/navigation_provider.dart';
import '../providers/generator_provider.dart';
import '../providers/music_provider.dart';
import '../theme/app_theme.dart';

import 'image_generator_screen.dart';
import 'music_generator_screen.dart';
import 'monitor_screen.dart';
import 'library_screen.dart';
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

  // Radial Menu State
  bool _isFabExpanded = false;
  late AnimationController _radialController;
  late Animation<double> _radialAnim;

  static const _navItems = [
    (Icons.auto_awesome_outlined, Icons.auto_awesome, '生成'),
    (Icons.monitor_outlined, Icons.monitor, '工作流'),
    (Icons.photo_library_outlined, Icons.photo_library, '素材库'),
    (Icons.auto_fix_high_outlined, Icons.auto_fix_high, '高级'),
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

    _radialController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _radialAnim = CurvedAnimation(
      parent: _radialController,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInBack,
    );

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
    _radialController.dispose();
    super.dispose();
  }

  void _onNavTap(int index, NavigationProvider nav) {
    if (_isFabExpanded) _toggleRadial();
    HapticFeedback.lightImpact();
    nav.setIndex(index);
    _navAnimControllers[index].forward().then((_) {
      _navAnimControllers[index].reverse();
    });
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

  void _toggleRadial() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _radialController.forward();
      } else {
        _radialController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    final safeIndex = nav.selectedIndex.clamp(0, _navItems.length - 1);

    return Scaffold(
      extendBody: true,
      backgroundColor: bgSpace,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                if (safeIndex == 0) _buildSubTabs(),
                Expanded(
                  child: IndexedStack(
                    index: safeIndex,
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
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if (_isFabExpanded || _radialController.isAnimating)
            GestureDetector(
              onTap: _toggleRadial,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _radialAnim,
                builder: (context, _) => Container(
                  color: Colors.black.withOpacity((0.6 * _radialAnim.value).clamp(0.0, 1.0)),
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          
          if (_isFabExpanded || _radialController.isAnimating)
            _buildRadialMenu(nav),
        ],
      ),
      bottomNavigationBar: _navbar(context, nav),
    );
  }

  Widget _buildRadialMenu(NavigationProvider nav) {
    final items = [
      (Icons.auto_awesome, "文生图", const Color(0xFF10B77F), () {
        nav.setIndex(0);
        _subTabController.animateTo(0);
        Provider.of<GeneratorProvider>(context, listen: false).setMode(GeneratorMode.textToImage);
      }),
      (Icons.edit_note, "图片编辑", const Color(0xFF6C63FF), () {
        nav.setIndex(0);
        _subTabController.animateTo(0);
        Provider.of<GeneratorProvider>(context, listen: false).setMode(GeneratorMode.imageEdit);
      }),
      (Icons.camera, "多角度", const Color(0xFFFF6B6B), () {
        nav.setIndex(0);
        _subTabController.animateTo(0);
        Provider.of<GeneratorProvider>(context, listen: false).setMode(GeneratorMode.multiAngle);
      }),
      (Icons.music_note, "简易音乐", const Color(0xFF00E5FF), () {
        nav.setIndex(0);
        _subTabController.animateTo(1);
        Provider.of<MusicGeneratorProvider>(context, listen: false).setIsSimpleMode(true);
      }),
      (Icons.queue_music, "高级音乐", const Color(0xFFFFD600), () {
        nav.setIndex(0);
        _subTabController.animateTo(1);
        Provider.of<MusicGeneratorProvider>(context, listen: false).setIsSimpleMode(false);
      }),
    ];

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !_isFabExpanded && !_radialController.isAnimating,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (int i = 0; i < items.length; i++)
              _buildRadialItem(i, items.length, items[i]),
          ],
        ),
      ),
    );
  }

  Widget _buildRadialItem(int index, int total, (IconData, String, Color, VoidCallback) item) {
    // Arc from 165 degrees to 15 degrees
    final startAngle = 165.0 * math.pi / 180.0;
    final endAngle = 15.0 * math.pi / 180.0;
    final currentAngle = startAngle - (index * (startAngle - endAngle) / (total - 1));
    
    return AnimatedBuilder(
      animation: _radialAnim,
      builder: (context, child) {
        // Increase radius slightly and ensure calculation moves things UP
        final radius = 160.0 * _radialAnim.value;
        final x = radius * math.cos(currentAngle);
        final y = radius * math.sin(currentAngle); // Positive sin for 15-165 degrees
        
        // 90 is approximate height of bottom nav
        return Positioned(
          bottom: 90 + y, 
          left: (MediaQuery.of(context).size.width / 2 - 28) + x,
          child: Opacity(
            opacity: _radialAnim.value.clamp(0.0, 1.0),
            child: GestureDetector(
              onTap: () {
                _toggleRadial();
                item.$4();
              },
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      shape: BoxShape.circle,
                      border: Border.all(color: item.$3.withOpacity(0.6), width: 2),
                      boxShadow: [
                        BoxShadow(color: item.$3.withOpacity(0.3), blurRadius: 15, spreadRadius: 1),
                      ],
                    ),
                    child: Icon(item.$1, color: item.$3, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.$2,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
            const Flexible(
              child: Text(
                'Comfy Pro Max',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < _navItems.length; i++) ...[
                  if (i == 2) const SizedBox(width: 56), 
                  _navItem(i, nav.selectedIndex == i, nav),
                ],
              ],
            ),
          ),
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
        onTap: _toggleRadial,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: _isFabExpanded 
                ? [const Color(0xFFFF6B6B), const Color(0xFFC91B65)]
                : [const Color(0xFF1DE9AA), const Color(0xFF10B77F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isFabExpanded ? const Color(0xFFC91B65) : accentEmerald).withOpacity(_fabPulseAnim.value * 0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Transform.rotate(
            angle: _isFabExpanded ? 45 * math.pi / 180 : 0,
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, bool active, NavigationProvider nav) {
    final item = _navItems[index];
    final safeIndex = nav.selectedIndex.clamp(0, _navItems.length - 1);
    final isActuallyActive = safeIndex == index;

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
                  isActuallyActive ? item.$2 : item.$1,
                  key: ValueKey(isActuallyActive),
                  color: isActuallyActive ? accentEmerald : Colors.white30,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActuallyActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActuallyActive ? accentEmerald : Colors.white30,
                ),
                child: Text(item.$3),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                height: 3,
                width: isActuallyActive ? 20 : 0,
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
