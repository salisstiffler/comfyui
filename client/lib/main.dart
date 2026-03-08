import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'services/api_service.dart';
import 'models/task_model.dart';

// --- State Management ---
class GeneratorProvider extends ChangeNotifier {
  String prompt = "";
  double steps = 8;
  double cfg = 1.0;
  String sampler = 'res_multistep';
  double batchSize = 1;
  String aspectRatio = '1:1';
  int? seed;
  bool randomSeed = true;

  void updateFromTask(AiTask task) {
    prompt = task.prompt;
    steps = task.steps.toDouble();
    cfg = task.cfg;
    sampler = task.sampler;
    batchSize = task.batchSize.toDouble();
    seed = task.seed;
    randomSeed = task.seed == null;
    
    if (task.width == 1024 && task.height == 1024) aspectRatio = '1:1';
    else if (task.width == 832 && task.height == 1216) aspectRatio = '2:3';
    else if (task.width == 1216 && task.height == 832) aspectRatio = '3:2';
    
    notifyListeners();
  }

  void setPrompt(String p) => {prompt = p, notifyListeners()};
  void setSteps(double s) => {steps = s, notifyListeners()};
  void setCfg(double c) => {cfg = c, notifyListeners()};
  void setSampler(String s) => {sampler = s, notifyListeners()};
  void setBatchSize(double b) => {batchSize = b, notifyListeners()};
  void setAspectRatio(String a) => {aspectRatio = a, notifyListeners()};
  void setSeed(int? s) => {seed = s, notifyListeners()};
  void setRandomSeed(bool r) => {randomSeed = r, notifyListeners()};
}

class NavigationProvider extends ChangeNotifier {
  int selectedIndex = 0;
  final PageController pageController = PageController();
  void setIndex(int index) {
    selectedIndex = index;
    pageController.jumpToPage(index);
    notifyListeners();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeneratorProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    const accentEmerald = Color(0xFF22C55E);
    const bgSpace = Color(0xFF0F172A);
    return MaterialApp(
      title: 'ComfyProMax',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgSpace,
        primaryColor: accentEmerald,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentEmerald,
          primary: accentEmerald,
          surface: const Color(0xFF1E293B),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  bool _isServerOnline = false;
  Timer? _healthCheckTimer;
  String _username = "Guest";

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _checkHealth();
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkHealth());
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? "Guest";
      ApiService.userId = _username;
    });
  }

  Future<void> _checkHealth() async {
    try {
      final isAlive = await ApiService.checkHealth();
      if (mounted && _isServerOnline != isAlive) setState(() => _isServerOnline = isAlive);
    } catch (_) {
      if (mounted && _isServerOnline) setState(() => _isServerOnline = false);
    }
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.4, child: Image.asset('assets/images/bg_texture.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.black)))),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: PageView(controller: nav.pageController, physics: const NeverScrollableScrollPhysics(), children: const [GeneratorScreen(), MonitorScreen(), LibraryScreen()])),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildGlassNavbar(nav),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _isServerOnline ? const Color(0xFF22C55E) : Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_isServerOnline ? const Color(0xFF22C55E) : Colors.red).withOpacity(0.5), blurRadius: 8, spreadRadius: 2)])),
              const SizedBox(width: 8),
              Text(_isServerOnline ? 'ENGINE READY' : 'CORE DISCONNECTED', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white54)),
              if (!_isServerOnline) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final success = await ApiService.wakeEngine();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? 'Waking up engine...' : 'Bridge not found'), backgroundColor: success ? const Color(0xFF22C55E) : Colors.red));
                  },
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border.all(color: Colors.amber.withOpacity(0.5)), borderRadius: BorderRadius.circular(4)), child: const Text('WAKE UP', style: TextStyle(fontSize: 8, color: Colors.amber, fontWeight: FontWeight.bold))),
                ),
              ],
            ],
          ),
          GestureDetector(onTap: () => _showProfileDialog(context), child: Row(children: [Text(_username.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)), const SizedBox(width: 8), const CircleAvatar(radius: 14, backgroundColor: Colors.white10, child: Icon(Icons.person_outline, size: 16, color: Colors.white))])),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final controller = TextEditingController(text: _username);
    showDialog(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF0F172A), title: const Text('USER PROFILE'), content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'USERNAME', filled: true, fillColor: Colors.white10)), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')), TextButton(onPressed: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setString('username', controller.text); ApiService.userId = controller.text; if (mounted) setState(() => _username = controller.text); Navigator.pop(ctx); }, child: const Text('SAVE', style: TextStyle(color: Color(0xFF22C55E))))]));
  }

  Widget _buildGlassNavbar(NavigationProvider nav) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.8), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: ClipRect(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: NavigationBar(selectedIndex: nav.selectedIndex, onDestinationSelected: nav.setIndex, backgroundColor: Colors.transparent, elevation: 0, indicatorColor: const Color(0xFF22C55E).withOpacity(0.2), labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected, destinations: const [NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'CREATE'), NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'HISTORY'), NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'GALLERY')]))),
    );
  }
}

// --- Generator Screen ---
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});
  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _pulseController;
  bool _showAdvanced = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gen = Provider.of<GeneratorProvider>(context, listen: false);
      _promptController.text = gen.prompt;
      if (gen.seed != null) _seedController.text = gen.seed.toString();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _promptController.dispose();
    _seedController.dispose();
    super.dispose();
  }

  final List<String> _samplers = ['res_multistep', 'euler', 'euler_ancestral', 'dpmpp_2m', 'k_dpm_2_ancestral'];
  final Map<String, Size> _aspectRatios = {'1:1': const Size(1024, 1024), '2:3': const Size(832, 1216), '3:2': const Size(1216, 832)};
  final List<String> _subjects = ["A cyberpunk metropolis", "A floating crystal island", "A samurai robot", "A Victorian clockwork owl", "An ancient underwater temple", "A cosmic nebula dragon", "A tiny mouse wizard", "A futuristic space station", "A surreal desert with melting clocks", "A mystical forest with glowing fungi", "A steampunk airship", "A polar bear in a suit", "A high-tech laboratory", "A medieval alchemist's study", "A rainy Tokyo street", "A crystalline unicorn", "A marble statue of a digital deity", "A hidden oasis in space"];
  final List<String> _styles = ["Studio Ghibli animation style", "Unreal Engine 5 render", "Cyberpunk 2077 aesthetic", "Oil painting by Van Gogh", "Hyper-realistic photography", "Minimalist 3D render", "Dark fantasy illustration", "Retro-wave vaporwave style", "Ukiyo-e woodblock print", "Cinematic lighting", "Pencil sketch", "Neon noir atmosphere", "Art Nouveau", "Futuristic bioluminescence", "National Geographic macro photography"];
  final List<String> _details = ["highly detailed, 8k resolution", "volumetric lighting, soft shadows", "intricate patterns, masterpiece", "vivid colors, sharp focus", "ethereal atmosphere, cinematic fog", "extreme close-up, bokeh effect", "concept art, gold leaf accents", "symmetry, ultra-detailed textures"];

  void _surpriseMe(GeneratorProvider gen) {
    final random = Random();
    final p = "${_subjects[random.nextInt(_subjects.length)]}, ${_styles[random.nextInt(_styles.length)]}, ${_details[random.nextInt(_details.length)]}";
    _promptController.text = p;
    gen.setPrompt(p);
    HapticFeedback.lightImpact();
  }

  void _submit(GeneratorProvider gen) async {
    final pr = _promptController.text.trim();
    if (pr.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final size = _aspectRatios[gen.aspectRatio]!;
      final pid = await ApiService.generateImage(pr, steps: gen.steps.toInt(), cfg: gen.cfg, seed: gen.randomSeed ? null : int.tryParse(_seedController.text), sampler: gen.sampler, batchSize: gen.batchSize.toInt(), width: size.width.toInt(), height: size.height.toInt());
      if (pid != null && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synthesis started...'), backgroundColor: Color(0xFF22C55E)));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connection error: $e'))); }
    finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<GeneratorProvider>(context);
    if (_promptController.text != gen.prompt) _promptController.text = gen.prompt;
    if (!gen.randomSeed && gen.seed != null && _seedController.text != gen.seed.toString()) _seedController.text = gen.seed.toString();
    else if (gen.randomSeed) _seedController.clear();

    return Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedBuilder(animation: _pulseController, builder: (context, child) => Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.1 + (_pulseController.value * 0.15)), blurRadius: 30 + (_pulseController.value * 20), spreadRadius: 2)]), child: Image.asset('assets/images/app_icon.png'))),
      const SizedBox(height: 32),
      Column(children: [Text('COMFY PRO MAX', style: GoogleFonts.archivo(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.white)), const SizedBox(height: 4), Text('AI CREATIVE ENGINE', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 4, color: const Color(0xFF22C55E).withOpacity(0.8)))]),
      const SizedBox(height: 48),
      Container(decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))), child: Column(children: [TextField(controller: _promptController, maxLines: 4, onChanged: gen.setPrompt, style: GoogleFonts.spaceGrotesk(fontSize: 16, color: Colors.white), decoration: InputDecoration(hintText: 'Describe your imagination...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)), contentPadding: const EdgeInsets.all(24), border: InputBorder.none)), Padding(padding: const EdgeInsets.only(right: 12, bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [IconButton(onPressed: () => _surpriseMe(gen), icon: const Icon(Icons.lightbulb_outline, color: Colors.amber), tooltip: 'INSPIRATION')]))])),
      const SizedBox(height: 16),
      GestureDetector(onTap: () => setState(() => _showAdvanced = !_showAdvanced), child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_showAdvanced ? 'HIDE OPTIONS' : 'ADVANCED OPTIONS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1)), Icon(_showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white30, size: 16)]))),
      if (_showAdvanced) _buildAdvancedControls(gen),
      const SizedBox(height: 32),
      GestureDetector(onTap: _isSubmitting ? null : () => _submit(gen), child: Container(height: 64, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFF22C55E), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]), child: Center(child: _isSubmitting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text('SYNTHESIZE', style: GoogleFonts.archivo(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.white))))),
    ])));
  }

  Widget _buildAdvancedControls(GeneratorProvider gen) {
    return Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sliderRow('STEPS', gen.steps, 1, 50, gen.setSteps), const SizedBox(height: 16),
      _sliderRow('GUIDANCE (CFG)', gen.cfg, 1, 20, gen.setCfg), const SizedBox(height: 16),
      _sliderRow('BATCH SIZE', gen.batchSize, 1, 4, gen.setBatchSize, divisions: 3), const SizedBox(height: 24),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('ASPECT RATIO'), const SizedBox(height: 8), DropdownButtonFormField<String>(value: gen.aspectRatio, dropdownColor: const Color(0xFF1E293B), style: GoogleFonts.spaceGrotesk(color: Colors.white), items: _aspectRatios.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => gen.setAspectRatio(v!), decoration: _inputDeco())])),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('SAMPLER'), const SizedBox(height: 8), DropdownButtonFormField<String>(value: gen.sampler, dropdownColor: const Color(0xFF1E293B), style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12), isExpanded: true, items: _samplers.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(), onChanged: (v) => gen.setSampler(v!), decoration: _inputDeco())])),
      ]),
      const SizedBox(height: 16), _label('SEED'),
      Row(children: [Expanded(child: TextField(controller: _seedController, enabled: !gen.randomSeed, keyboardType: TextInputType.number, onChanged: (v) => gen.setSeed(int.tryParse(v)), style: const TextStyle(color: Colors.white), decoration: _inputDeco().copyWith(hintText: 'Random'))), const SizedBox(width: 12), FilterChip(label: const Text('Random'), selected: gen.randomSeed, onSelected: gen.setRandomSeed, checkmarkColor: Colors.white, selectedColor: const Color(0xFF22C55E))]),
    ]));
  }

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged, {int? divisions}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_label(label), Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white70))]), SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: const Color(0xFF22C55E), inactiveTrackColor: Colors.white10, thumbColor: Colors.white, overlayColor: const Color(0xFF22C55E).withOpacity(0.2)), child: Slider(value: value, min: min, max: max, divisions: divisions ?? (max - min).toInt(), onChanged: onChanged))]);
  }

  Widget _label(String text) => Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1));
  InputDecoration _inputDeco() => InputDecoration(filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
}

// --- Monitor Screen (Timeline Style) ---
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});
  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> with AutomaticKeepAliveClientMixin {
  Map<String, List<AiTask>> _groupedTasks = {};
  Timer? _pollTimer;
  Timer? _tickTimer;
  Map<String, double> _progress = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _groupedTasks.values.any((list) => list.any((t) => t.status != 'completed' && t.status != 'cancelled'))) setState(() {});
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); _tickTimer?.cancel(); super.dispose(); }

  Future<void> _refresh() async {
    final list = await ApiService.getJobs();
    if (!mounted) return;
    list.sort((a, b) {
      if (a.status == 'running' || a.status == 'pending') return -1;
      if (b.status == 'running' || b.status == 'pending') return 1;
      return (b.completedAt ?? b.timestamp).compareTo(a.completedAt ?? a.timestamp);
    });
    final Map<String, List<AiTask>> groups = {};
    for (var t in list) {
      final dateStr = (t.status == 'running' || t.status == 'pending' || t.status == 'queued') ? "ACTIVE TASKS" : DateFormat('yyyy年MM月dd日').format(t.completedAt ?? t.timestamp);
      groups.putIfAbsent(dateStr, () => []).add(t);
    }
    setState(() => _groupedTasks = groups);
    for (final t in list) {
      if (t.status == 'running' || t.status == 'pending' || t.status == 'queued') {
        final data = await ApiService.checkStatus(t.promptId);
        if (data != null && mounted && data['status'] == 'running') setState(() => _progress[t.promptId] = (data['progress'] as num?)?.toDouble() ?? 0.5);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final keys = _groupedTasks.keys.toList();
    return Scaffold(backgroundColor: Colors.transparent, body: CustomScrollView(slivers: [
      SliverAppBar(floating: true, backgroundColor: Colors.transparent, title: Text('TASK HISTORY', style: GoogleFonts.archivo(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)), centerTitle: true, automaticallyImplyLeading: false),
      if (keys.isEmpty) SliverFillRemaining(child: Center(child: Text('NO TASKS YET', style: TextStyle(color: Colors.white.withOpacity(0.1), letterSpacing: 2))))
      else for (var date in keys) ...[
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), child: Text(date, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1, color: date == "ACTIVE TASKS" ? const Color(0xFF22C55E) : Colors.white38)))),
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 24), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildBentoCard(_groupedTasks[date]![index]), childCount: _groupedTasks[date]!.length))),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]));
  }

  Widget _buildBentoCard(AiTask task) {
    final isRunning = task.status == 'running';
    return Container(margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.4), borderRadius: BorderRadius.circular(20), border: Border.all(color: isRunning ? const Color(0xFF22C55E).withOpacity(0.3) : Colors.white.withOpacity(0.05))), child: Theme(data: ThemeData.dark().copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: _buildStatusPulse(task.status, _progress[task.promptId] ?? 0.0),
      title: Text(task.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [_statusBadge(task.status), const SizedBox(width: 12), const Icon(Icons.timer_outlined, size: 10, color: Colors.white24), const SizedBox(width: 4), Text(task.durationString, style: const TextStyle(fontSize: 10, color: Colors.white24)), const SizedBox(width: 12), Text('${task.width}x${task.height} • ${task.steps}S', style: const TextStyle(fontSize: 10, color: Colors.white24))])),
      children: [Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(color: Colors.white10), const SizedBox(height: 12), _meta('TECHNICAL SPECS', 'CFG: ${task.cfg} • Sampler: ${task.sampler} • Seed: ${task.seed ?? "Auto"}'),
        if (task.status == 'completed' && task.resultImageUrl != null) Padding(padding: const EdgeInsets.only(top: 16), child: GestureDetector(onTap: () => FullScreenGallery.show(context, [task], 0), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(task.resultImageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover)))),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(onPressed: () { Provider.of<GeneratorProvider>(context, listen: false).updateFromTask(task); Provider.of<NavigationProvider>(context, listen: false).setIndex(0); }, icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF22C55E)), label: const Text('EVOLVE', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold))),
          if (isRunning) TextButton.icon(onPressed: () => ApiService.cancelTask(task.promptId).then((_) => _refresh()), icon: const Icon(Icons.close, size: 16), label: const Text('ABORT')),
        ]),
      ]))],
    )));
  }

  Widget _statusBadge(String status) {
    Color c = status == 'completed' ? const Color(0xFF22C55E) : (status == 'running' ? Colors.amber : (status == 'cancelled' ? Colors.red : Colors.grey));
    return Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)));
  }

  Widget _buildStatusPulse(String status, double progress) {
    Color c = status == 'completed' ? const Color(0xFF22C55E) : (status == 'running' ? Colors.amber : Colors.grey);
    IconData i = status == 'completed' ? Icons.check_circle_outline : (status == 'running' ? Icons.sync : Icons.access_time);
    return Stack(alignment: Alignment.center, children: [if (status == 'running') SizedBox(width: 32, height: 32, child: CircularProgressIndicator(value: progress, strokeWidth: 1.5, color: c)), Icon(i, color: c, size: 18)]);
  }

  Widget _meta(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1.5)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70))]);
}

// --- Library Screen (iOS Style) ---
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with AutomaticKeepAliveClientMixin {
  Map<String, List<AiTask>> _groupedImages = {};
  List<AiTask> _flatList = [];
  Timer? _sync;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() { super.initState(); _fetch(); _sync = Timer.periodic(const Duration(seconds: 5), (_) => _fetch()); }

  @override
  void dispose() { _sync?.cancel(); super.dispose(); }

  Future<void> _fetch() async {
    final list = await ApiService.getJobs();
    if (!mounted) return;
    final completed = list.where((t) => t.status == 'completed' && t.resultImageUrl != null).toList();
    final Map<String, List<AiTask>> groups = {};
    for (var task in completed) { final dateStr = DateFormat('yyyy年MM月dd日').format(task.completedAt ?? task.timestamp); groups.putIfAbsent(dateStr, () => []).add(task); }
    setState(() { _groupedImages = groups; _flatList = completed; });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final keys = _groupedImages.keys.toList();
    return Scaffold(backgroundColor: Colors.transparent, body: CustomScrollView(slivers: [
      SliverAppBar(floating: true, backgroundColor: Colors.transparent, title: Text('CREATION VAULT', style: GoogleFonts.archivo(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)), centerTitle: true),
      if (keys.isEmpty) SliverFillRemaining(child: Center(child: Text('VAULT EMPTY', style: TextStyle(color: Colors.white.withOpacity(0.1), letterSpacing: 2))))
      else for (var date in keys) ...[
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), child: Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)))),
        SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 24), sliver: SliverGrid(gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8), delegate: SliverChildBuilderDelegate((context, index) { final t = _groupedImages[date]![index]; return GestureDetector(onTap: () => FullScreenGallery.show(context, _flatList, _flatList.indexOf(t)), child: Hero(tag: 'img_${t.promptId}', child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: NetworkImage(t.resultImageUrl!), fit: BoxFit.cover))))); }, childCount: _groupedImages[date]!.length))),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 100)),
    ]));
  }
}

// --- Full Screen Gallery Viewer (Improved for Windows) ---
class FullScreenGallery extends StatefulWidget {
  final List<AiTask> images;
  final int initialIndex;
  const FullScreenGallery({super.key, required this.images, required this.initialIndex});
  static void show(BuildContext context, List<AiTask> images, int index) => Navigator.push(context, PageRouteBuilder(opaque: false, barrierColor: Colors.black, pageBuilder: (context, _, __) => FullScreenGallery(images: images, initialIndex: index)));
  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = false;
  double _dragOffset = 0;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() { super.initState(); _currentIndex = widget.initialIndex; _pageController = PageController(initialPage: widget.initialIndex); }

  @override
  void dispose() { _pageController.dispose(); _transformationController.dispose(); super.dispose(); }

  void _toggleUI() => setState(() => _showUI = !_showUI);

  Future<void> _dl() async {
    try {
      final r = await http.get(Uri.parse(widget.images[_currentIndex].resultImageUrl!));
      final d = await getApplicationDocumentsDirectory();
      final f = File('${d.path}/comfy_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(r.bodyBytes);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery'), backgroundColor: Color(0xFF22C55E)));
    } catch (_) {}
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.5);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(max(0, 1 - (_dragOffset.abs() / 300))),
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight) _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            else if (event.logicalKey == LogicalKeyboardKey.escape) Navigator.pop(context);
          }
        },
        child: GestureDetector(
          onTap: _toggleUI,
          onDoubleTap: _handleDoubleTap,
          onVerticalDragUpdate: (details) {
            // 只有在未放大时允许下拉退出
            if (_transformationController.value.getMaxScaleOnAxis() <= 1.0) setState(() => _dragOffset += details.delta.dy);
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset.abs() > 150) Navigator.pop(context);
            else setState(() => _dragOffset = 0);
          },
          child: Stack(children: [
            Transform.translate(
              offset: Offset(0, _dragOffset),
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.images.length,
                onPageChanged: (idx) { setState(() => _currentIndex = idx); _transformationController.value = Matrix4.identity(); },
                itemBuilder: (context, index) => Hero(
                  tag: 'img_${widget.images[index].promptId}',
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(child: Image.network(widget.images[index].resultImageUrl!, fit: BoxFit.contain, loadingBuilder: (context, child, event) => event == null ? child : const Center(child: CircularProgressIndicator()))),
                  ),
                ),
              ),
            ),
            if (_showUI) ...[
              Positioned(top: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.fromLTRB(16, 48, 16, 16), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.7), Colors.transparent])), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white)),
                Column(children: [Text('SYNTHESIS', style: GoogleFonts.archivo(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 2)), Text(DateFormat('jm').format(widget.images[_currentIndex].timestamp), style: const TextStyle(fontSize: 10, color: Colors.white54))]),
                IconButton(onPressed: () { showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: Colors.black, title: const Text('SPECS'), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Steps: ${widget.images[_currentIndex].steps}'), Text('CFG: ${widget.images[_currentIndex].cfg}'), Text('Sampler: ${widget.images[_currentIndex].sampler}'), Text('Seed: ${widget.images[_currentIndex].seed}')]))); }, icon: const Icon(Icons.info_outline, color: Colors.white)),
              ]))),
              Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.fromLTRB(24, 32, 24, 48), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent])), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.images[_currentIndex].prompt, style: const TextStyle(fontSize: 13, height: 1.4), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _action(Icons.file_download_outlined, 'EXPORT', _dl),
                  _action(Icons.refresh, 'EVOLVE', () { Navigator.pop(context); Provider.of<GeneratorProvider>(context, listen: false).updateFromTask(widget.images[_currentIndex]); Provider.of<NavigationProvider>(context, listen: false).setIndex(0); }),
                ]),
              ]))),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback ontap) => InkWell(onTap: ontap, child: Column(children: [Icon(icon, size: 24, color: const Color(0xFF22C55E)), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF22C55E)))]));
}
