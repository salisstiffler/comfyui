import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
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

  void setPrompt(String p) {
    prompt = p;
    notifyListeners();
  }

  void setSteps(double s) {
    steps = s;
    notifyListeners();
  }

  void setCfg(double c) {
    cfg = c;
    notifyListeners();
  }

  void setSampler(String s) {
    sampler = s;
    notifyListeners();
  }

  void setBatchSize(double b) {
    batchSize = b;
    notifyListeners();
  }

  void setAspectRatio(String a) {
    aspectRatio = a;
    notifyListeners();
  }

  void setSeed(int? s) {
    seed = s;
    notifyListeners();
  }

  void setRandomSeed(bool r) {
    randomSeed = r;
    notifyListeners();
  }
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
    const textGhost = Color(0xFFF8FAFC);

    return MaterialApp(
      title: 'ComfyProMax',
      debugShowCheckedModeBanner: false,
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
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.dark().textTheme.apply(
            bodyColor: textGhost,
            displayColor: textGhost,
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
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
    _healthCheckTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _checkHealth());
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
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_texture.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: nav.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      GeneratorScreen(),
                      MonitorScreen(),
                      LibraryScreen(),
                    ],
                  ),
                ),
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
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color:
                      _isServerOnline ? const Color(0xFF22C55E) : Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (_isServerOnline
                                  ? const Color(0xFF22C55E)
                                  : Colors.red)
                              .withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isServerOnline ? 'ENGINE READY' : 'CORE DISCONNECTED',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white54,
                ),
              ),
              if (!_isServerOnline) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final success = await ApiService.wakeEngine();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? 'Waking up engine...' : 'Bridge not found'),
                          backgroundColor: success ? const Color(0xFF22C55E) : Colors.red,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'WAKE UP',
                      style: TextStyle(fontSize: 8, color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
          GestureDetector(
            onTap: () => _showProfileDialog(context),
            child: Row(
              children: [
                Text(
                  _username.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white10,
                  child: Icon(Icons.person_outline, size: 16, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final controller = TextEditingController(text: _username);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            title: const Text('USER PROFILE'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'USERNAME',
                filled: true,
                fillColor: Colors.white10,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('CANCEL'),
              ),
              TextButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('username', controller.text);
                  ApiService.userId = controller.text;
                  if (mounted)
                    setState(() {
                      _username = controller.text;
                    });
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'SAVE',
                  style: TextStyle(color: Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildGlassNavbar(NavigationProvider nav) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: NavigationBar(
            selectedIndex: nav.selectedIndex,
            onDestinationSelected: nav.setIndex,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: const Color(0xFF22C55E).withOpacity(0.2),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome),
                label: 'CREATE',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'HISTORY',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: 'GALLERY',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Generator Screen ---
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _pulseController;
  bool _showAdvanced = false;

  final List<String> _samplers = [
    'res_multistep',
    'euler',
    'euler_ancestral',
    'dpmpp_2m',
    'k_dpm_2_ancestral',
  ];

  final Map<String, Size> _aspectRatios = {
    '1:1': const Size(1024, 1024),
    '2:3': const Size(832, 1216),
    '3:2': const Size(1216, 832),
  };

  final List<String> _surprisePrompts = [
    "A futuristic cyberpunk city with neon lights and flying cars",
    "A calm zen garden with cherry blossoms falling",
    "An astronaut playing chess with an alien on Mars",
    "A majestic dragon flying over a medieval castle",
    "A portrait of a robot with human emotions, oil painting style",
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
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

  void _surpriseMe(GeneratorProvider gen) {
    final p = _surprisePrompts[Random().nextInt(_surprisePrompts.length)];
    _promptController.text = p;
    gen.setPrompt(p);
  }

  void _submit(GeneratorProvider gen) async {
    final pr = _promptController.text.trim();
    if (pr.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final size = _aspectRatios[gen.aspectRatio]!;
      int? seedVal;
      if (!gen.randomSeed && _seedController.text.isNotEmpty) {
        seedVal = int.tryParse(_seedController.text);
      }

      final pid = await ApiService.generateImage(
        pr,
        steps: gen.steps.toInt(),
        cfg: gen.cfg,
        seed: seedVal,
        sampler: gen.sampler,
        batchSize: gen.batchSize.toInt(),
        width: size.width.toInt(),
        height: size.height.toInt(),
      );

      if (pid != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synthesis started...'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection error: $e')),
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<GeneratorProvider>(context);
    
    if (_promptController.text != gen.prompt) {
       _promptController.text = gen.prompt;
    }
    if (!gen.randomSeed && gen.seed != null && _seedController.text != gen.seed.toString()) {
       _seedController.text = gen.seed.toString();
    } else if (gen.randomSeed) {
       _seedController.clear();
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPrismIcon(),
            const SizedBox(height: 32),
            _buildTitle(),
            const SizedBox(height: 48),
            _buildPromptInput(gen),
            const SizedBox(height: 16),
            _buildAdvancedToggle(),
            if (_showAdvanced) _buildAdvancedControls(gen),
            const SizedBox(height: 32),
            _buildIgniteButton(gen),
          ],
        ),
      ),
    );
  }

  Widget _buildPrismIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF22C55E).withOpacity(0.1 + (_pulseController.value * 0.15)),
                blurRadius: 30 + (_pulseController.value * 20),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset('assets/images/app_icon.png'),
        );
      },
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'COMFY PRO MAX',
          style: GoogleFonts.archivo(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'AI CREATIVE ENGINE',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 4,
            color: const Color(0xFF22C55E).withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptInput(GeneratorProvider gen) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _promptController,
            maxLines: 4,
            onChanged: gen.setPrompt,
            style: GoogleFonts.spaceGrotesk(fontSize: 16, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Describe your imagination...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              contentPadding: const EdgeInsets.all(24),
              border: InputBorder.none,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _surpriseMe(gen),
                  icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
                  tooltip: 'INSPIRATION',
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAdvancedToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showAdvanced = !_showAdvanced),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _showAdvanced ? 'HIDE OPTIONS' : 'ADVANCED OPTIONS',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white30,
                letterSpacing: 1,
              ),
            ),
            Icon(
              _showAdvanced ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.white30,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedControls(GeneratorProvider gen) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sliderRow('STEPS', gen.steps, 1, 50, gen.setSteps),
          const SizedBox(height: 16),
          _sliderRow('GUIDANCE (CFG)', gen.cfg, 1, 20, gen.setCfg),
          const SizedBox(height: 16),
          _sliderRow(
            'BATCH SIZE',
            gen.batchSize,
            1,
            4,
            gen.setBatchSize,
            divisions: 3,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('ASPECT RATIO'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: gen.aspectRatio,
                      dropdownColor: const Color(0xFF1E293B),
                      style: GoogleFonts.spaceGrotesk(color: Colors.white),
                      items:
                          _aspectRatios.keys
                              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                      onChanged: (v) => gen.setAspectRatio(v!),
                      decoration: _inputDeco(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('SAMPLER'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: gen.sampler,
                      dropdownColor: const Color(0xFF1E293B),
                      style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 12),
                      isExpanded: true,
                      items:
                          _samplers
                              .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                              .toList(),
                      onChanged: (v) => gen.setSampler(v!),
                      decoration: _inputDeco(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _label('SEED'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _seedController,
                  enabled: !gen.randomSeed,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => gen.setSeed(int.tryParse(v)),
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco().copyWith(hintText: 'Random'),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Random'),
                selected: gen.randomSeed,
                onSelected: gen.setRandomSeed,
                checkmarkColor: Colors.white,
                selectedColor: const Color(0xFF22C55E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sliderRow(String label, double value, double min, double max, ValueChanged<double> onChanged, {int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label(label),
            Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.white70)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF22C55E),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF22C55E).withOpacity(0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions ?? (max - min).toInt(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1),
    );
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _buildIgniteButton(GeneratorProvider gen) {
    return GestureDetector(
      onTap: _isSubmitting ? null : () => _submit(gen),
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Center(
          child: _isSubmitting
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(
                  'SYNTHESIZE',
                  style: GoogleFonts.archivo(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2, color: Colors.white),
                ),
        ),
      ),
    );
  }
}

// --- Monitor Screen ---
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> with AutomaticKeepAliveClientMixin {
  List<AiTask> _tasks = [];
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
      if (mounted && _tasks.any((t) => t.status != 'completed' && t.status != 'cancelled')) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final list = await ApiService.getJobs();
    if (!mounted) return;
    setState(() => _tasks = list);

    for (final t in _tasks) {
      if (t.status == 'running' || t.status == 'pending' || t.status == 'queued' || t.status == 'unknown') {
        final data = await ApiService.checkStatus(t.promptId);
        if (data != null && mounted) {
          if (data['status'] == 'running') {
            setState(() {
              _progress[t.promptId] = (data['progress'] as num?)?.toDouble() ?? 0.5;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('TASK HISTORY', style: GoogleFonts.archivo(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: _tasks.isEmpty
          ? Center(child: Text('NO TASKS YET', style: TextStyle(color: Colors.white.withOpacity(0.1), letterSpacing: 2)))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: _tasks.length,
              itemBuilder: (context, idx) => _buildBentoCard(_tasks[idx]),
            ),
    );
  }

  Widget _buildBentoCard(AiTask task) {
    final p = _progress[task.promptId] ?? 0.0;
    final isDone = task.status == 'completed';
    final isRunning = task.status == 'running';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning ? const Color(0xFF22C55E).withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: _buildStatusPulse(task.status, p),
          title: Text(task.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _statusBadge(task.status),
                const SizedBox(width: 12),
                const Icon(Icons.timer_outlined, size: 10, color: Colors.white24),
                const SizedBox(width: 4),
                Text(
                  task.durationString,
                  style: const TextStyle(fontSize: 10, color: Colors.white24),
                ),
                const SizedBox(width: 12),
                Text(
                  '${task.width}x${task.height} • ${task.steps}S',
                  style: const TextStyle(fontSize: 10, color: Colors.white24),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  _meta('TECHNICAL SPECS', 'CFG: ${task.cfg} • Sampler: ${task.sampler} • Seed: ${task.seed ?? "Auto"}'),
                  if (isDone && task.resultImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: GestureDetector(
                        onTap: () => ResultDialog.show(context, task.resultImageUrl!, task),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(task.resultImageUrl!, height: 180, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                           Provider.of<GeneratorProvider>(context, listen: false).updateFromTask(task);
                           Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: Color(0xFF22C55E)),
                        label: const Text('EVOLVE', style: TextStyle(color: Color(0xFF22C55E), fontWeight: FontWeight.bold)),
                      ),
                      if (isRunning)
                        TextButton.icon(
                          onPressed: () => ApiService.cancelTask(task.promptId).then((_) => _refresh()),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('ABORT'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color c = Colors.grey;
    if (status == 'completed') c = const Color(0xFF22C55E);
    if (status == 'running') c = Colors.amber;
    if (status == 'cancelled') c = Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  Widget _buildStatusPulse(String status, double progress) {
    Color c = Colors.grey;
    IconData i = Icons.access_time;
    if (status == 'completed') { c = const Color(0xFF22C55E); i = Icons.check_circle_outline; }
    if (status == 'running') { c = Colors.amber; i = Icons.sync; }
    return Stack(alignment: Alignment.center, children: [
      if (status == 'running') SizedBox(width: 32, height: 32, child: CircularProgressIndicator(value: progress, strokeWidth: 1.5, color: c)),
      Icon(i, color: c, size: 18),
    ]);
  }

  Widget _meta(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ]);
  }
}

// --- Library Screen ---
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with AutomaticKeepAliveClientMixin {
  List<AiTask> _images = [];
  Timer? _sync;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
    _sync = Timer.periodic(const Duration(seconds: 5), (_) => _fetch());
  }

  @override
  void dispose() {
    _sync?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final list = await ApiService.getJobs();
    if (mounted) {
      final res = list.where((t) => t.status == 'completed' && t.resultImageUrl != null).toList();
      setState(() => _images = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('CREATION VAULT', style: GoogleFonts.archivo(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: _images.isEmpty
          ? Center(child: Text('VAULT EMPTY', style: TextStyle(color: Colors.white.withOpacity(0.1), letterSpacing: 2)))
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 0.8),
              itemCount: _images.length,
              itemBuilder: (context, idx) {
                final t = _images[idx];
                return GestureDetector(
                  onTap: () => ResultDialog.show(context, t.resultImageUrl!, t),
                  child: Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(t.resultImageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.white10)),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.9)])),
                              child: Text(t.prompt, maxLines: 2, style: const TextStyle(fontSize: 10, color: Colors.white60), overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// --- Result Dialog ---
class ResultDialog extends StatelessWidget {
  final String imageUrl;
  final AiTask task;
  const ResultDialog({super.key, required this.imageUrl, required this.task});

  static void show(BuildContext context, String url, AiTask t) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => ResultDialog(imageUrl: url, task: t),
      transitionBuilder: (context, anim1, anim2, child) => FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1, child: child)),
    );
  }

  Future<void> _dl(BuildContext context) async {
    try {
      final r = await http.get(Uri.parse(imageUrl));
      final d = await getApplicationDocumentsDirectory();
      final f = File('${d.path}/comfy_${DateTime.now().millisecondsSinceEpoch}.png');
      await f.writeAsBytes(r.bodyBytes);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Gallery'), backgroundColor: Color(0xFF22C55E)));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), child: InteractiveViewer(child: Image.network(imageUrl))),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (c) => AlertDialog(
                            backgroundColor: Colors.black,
                            title: const Text('TECHNICAL SPECS'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Steps: ${task.steps}'),
                                Text('CFG: ${task.cfg}'),
                                Text('Sampler: ${task.sampler}'),
                                Text('Seed: ${task.seed}'),
                                Text('Dimension: ${task.width}x${task.height}'),
                              ],
                            ),
                          ),
                    );
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(task.prompt, style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _dl(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('EXPORT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Provider.of<GeneratorProvider>(context, listen: false).updateFromTask(task);
                        Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
                      },
                      icon: const Icon(Icons.refresh, color: Color(0xFF22C55E)),
                      style: IconButton.styleFrom(backgroundColor: Colors.white10),
                      tooltip: 'EVOLVE',
                    ),
                    const SizedBox(width: 8),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close), style: IconButton.styleFrom(backgroundColor: Colors.white10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
