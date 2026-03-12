import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'services/api_service.dart';
import 'models/task_model.dart';
import 'providers/player_provider.dart';

// --- Theme Config ---
const accentEmerald = Color(0xFF10B77F);
const bgSpace = Color(0xFF10221C);
const glassColor = Color(0x1A10B77F); // primary/10 in dark mode
const glassBorder = Color(0x3310B77F); // primary/20 in dark mode

// --- State Management ---
class GeneratorProvider extends ChangeNotifier {
  // State Management
  String _simplePrompt = "";
  String _advancedPrompt = "";
  double steps = 8;
  double cfg = 1.0;
  String sampler = 'res_multistep';
  double batchSize = 1;
  String aspectRatio = '1:1';
  int? seed;
  bool randomSeed = true;

  // I2I Fields
  bool isI2I = false;
  Uint8List? inputImageBytes;
  String? inputImageFilename;
  String? serverImageName;
  double denoise = 1.0;

  String get simplePrompt => _simplePrompt;
  String get advancedPrompt => _advancedPrompt;
  String get prompt => isI2I ? _advancedPrompt : _simplePrompt;

  void setI2I(bool v) {
    isI2I = v;
    notifyListeners();
  }

  void setInputImage(Uint8List? bytes, String? filename) {
    inputImageBytes = bytes;
    inputImageFilename = filename;
    serverImageName = null;
    notifyListeners();
  }

  void setDenoise(double v) {
    denoise = v;
    notifyListeners();
  }

  void setSimplePrompt(String p) {
    _simplePrompt = p;
    notifyListeners();
  }

  void setAdvancedPrompt(String p) {
    _advancedPrompt = p;
    notifyListeners();
  }

  void setPrompt(String p) {
    if (isI2I) {
      _advancedPrompt = p;
    } else {
      _simplePrompt = p;
    }
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

  void updateFromTask(AiTask task) {
    if (task.workflowMode == 'ADVANCED' || task.type == 'image_edit') {
      _advancedPrompt = task.prompt;
    } else {
      _simplePrompt = task.prompt;
    }
    steps = task.steps.toDouble();
    cfg = task.cfg;
    sampler = task.sampler;
    batchSize = task.batchSize.toDouble();
    seed = task.seed;
    randomSeed = task.seed == null;
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

class TaskProvider extends ChangeNotifier {
  List<AiTask> tasks = [];
  Map<String, double> progress = {};
  Timer? _timer;
  bool isLoading = true;

  TaskProvider() {
    startPolling();
  }
  void startPolling() {
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => refresh());
  }

  Future<void> refresh() async {
    final list = await ApiService.getJobs();
    for (final t in list) {
      if (t.status == 'running' || t.status == 'queued') {
        final data = await ApiService.checkStatus(t.promptId);
        if (data != null && data['status'] != t.status) {
          tasks = await ApiService.getJobs();
          notifyListeners();
          return;
        }
      }
    }
    tasks = list;
    isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class MusicGeneratorProvider extends ChangeNotifier {
  String prompt = "";
  String tags = "acoustic ballad, indie pop, soothing melancholy";
  String lyrics = "[intro]\n(Piano intro)\n[verse]\nRain falls softly...";
  bool isSimpleMode = true;
  int bpm = 190;
  int duration = 120;
  double cfg = 2.0;
  int? seed;
  bool randomSeed = true;

  void setPrompt(String p) {
    prompt = p;
    notifyListeners();
  }

  void setIsSimpleMode(bool s) {
    isSimpleMode = s;
    notifyListeners();
  }

  void setTags(String t) {
    tags = t;
    notifyListeners();
  }

  void setLyrics(String l) {
    lyrics = l;
    notifyListeners();
  }

  void setBpm(double b) {
    bpm = b.toInt();
    notifyListeners();
  }

  void setDuration(double d) {
    duration = d.toInt();
    notifyListeners();
  }

  void setCfg(double c) {
    cfg = c;
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

// --- Main App ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeneratorProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => MusicGeneratorProvider()),
        ChangeNotifierProvider(create: (_) => PlaybackProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ComfyProMax',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgSpace,
        primaryColor: accentEmerald,
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accentEmerald,
          brightness: Brightness.dark,
          surface: bgSpace,
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
  bool _isOnline = false;
  String _user = "Guest";

  @override
  void initState() {
    super.initState();
    _load();
    Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  void _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _user = p.getString('username') ?? "Guest";
      ApiService.userId = _user;
    });
    _check();
  }

  void _check() async {
    final alive = await ApiService.checkHealth();
    if (mounted) setState(() => _isOnline = alive);
  }

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
                  const Center(child: Text('Settings Coming Soon')),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _navbar(nav),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white70),
          onPressed: () {},
        ),
        Row(
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
            const SizedBox(width: 8),
            const Text(
              'Comfy Pro Max',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: accentEmerald,
              ),
            ),
          ],
        ),
        Container(
          width: 40,
          height: 40,
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

  Widget _navbar(NavigationProvider nav) => Stack(
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
          onTap: () {},
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

// --- Generator Screen (Images) ---
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});
  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _simplePromptCtrl = TextEditingController();
  final TextEditingController _advancedPromptCtrl = TextEditingController();
  final TextEditingController _seedCtrl = TextEditingController();
  bool _isSub = false;
  bool _showAdv = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final gen = Provider.of<GeneratorProvider>(context, listen: false);
    _simplePromptCtrl.text = gen.simplePrompt;
    _advancedPromptCtrl.text = gen.advancedPrompt;
    if (gen.seed != null) {
      _seedCtrl.text = gen.seed.toString();
    }
  }

  @override
  void dispose() {
    _simplePromptCtrl.dispose();
    _advancedPromptCtrl.dispose();
    _seedCtrl.dispose();
    super.dispose();
  }

  void _submit(GeneratorProvider gen) async {
    final activePrompt = gen.isI2I
        ? _advancedPromptCtrl.text
        : _simplePromptCtrl.text;
    if (activePrompt.isEmpty) return;
    if (gen.isI2I && gen.inputImageBytes == null) return;
    setState(() => _isSub = true);
    try {
      String? pid;
      if (gen.isI2I) {
        String? sName = gen.serverImageName;
        if (sName == null) {
          sName = await ApiService.uploadImage(
            gen.inputImageBytes!,
            gen.inputImageFilename!,
          );
        }
        if (sName != null) {
          gen.serverImageName = sName;
          pid = await ApiService.generateEdit(
            prompt: _advancedPromptCtrl.text,
            image: sName,
            denoise: gen.denoise,
            seed: gen.randomSeed ? null : int.tryParse(_seedCtrl.text),
            steps: gen.steps.toInt(),
          );
        }
      } else {
        pid = await ApiService.generateImage(
          _simplePromptCtrl.text,
          steps: gen.steps.toInt(),
          cfg: gen.cfg,
          seed: gen.randomSeed ? null : int.tryParse(_seedCtrl.text),
          sampler: gen.sampler,
        );
      }
      if (pid != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing...'),
            backgroundColor: accentEmerald,
          ),
        );
      }
    } finally {
      setState(() => _isSub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<GeneratorProvider>(context);
    final taskProv = Provider.of<TaskProvider>(context);
    final recentTasks = taskProv.tasks
        .where((t) => t.status == 'completed' && !t.isMusic)
        .toList();
    recentTasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final displayTasks = recentTasks.take(4).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentEmerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _modeBtn('SIMPLE', !gen.isI2I, () => gen.setI2I(false)),
                _modeBtn('ADVANCED', gen.isI2I, () => gen.setI2I(true)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (gen.isI2I) ...[
            _sectionLabel("Base Image"),
            const SizedBox(height: 8),
            _buildI2IPicker(gen),
            const SizedBox(height: 16),
          ],
          _sectionLabel(gen.isI2I ? "Edit Instructions" : "Prompt"),
          const SizedBox(height: 8),
          gen.isI2I
              ? _buildAdvancedPromptInput(gen)
              : _buildSimplePromptInput(gen),
          const SizedBox(height: 24),
          if (!gen.isI2I) ...[
            _sectionLabel("Aspect Ratio"),
            const SizedBox(height: 12),
            _buildAspectRatioSelector(gen),
            const SizedBox(height: 24),
          ],
          GestureDetector(
            onTap: () => setState(() => _showAdv = !_showAdv),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showAdv ? 'HIDE OPTIONS' : 'ADVANCED OPTIONS',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _showAdv
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 14,
                  color: Colors.white24,
                ),
              ],
            ),
          ),
          if (_showAdv) _buildAdvPanel(gen),
          const SizedBox(height: 32),
          _buildGenerateButton(gen),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent Creations",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  Provider.of<NavigationProvider>(
                    context,
                    listen: false,
                  ).setIndex(3);
                },
                child: const Text(
                  "View All",
                  style: TextStyle(
                    color: accentEmerald,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRecentGrid(displayTasks),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _modeBtn(String l, bool a, VoidCallback t) => Expanded(
    child: GestureDetector(
      onTap: t,
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

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: Colors.white24,
        letterSpacing: 1.5,
      ),
    ),
  );

  Widget _buildI2IPicker(GeneratorProvider gen) => GestureDetector(
    onTap: () async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (res != null) {
        gen.setInputImage(res.files.first.bytes, res.files.first.name);
      }
    },
    child: Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentEmerald.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gen.inputImageBytes != null
              ? accentEmerald.withOpacity(0.5)
              : accentEmerald.withOpacity(0.1),
        ),
      ),
      child: gen.inputImageBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(gen.inputImageBytes!, fit: BoxFit.cover),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  color: accentEmerald.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'UPLOAD BASE IMAGE',
                  style: TextStyle(
                    fontSize: 10,
                    color: accentEmerald.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _buildSimplePromptInput(GeneratorProvider gen) => Container(
    key: const ValueKey('simple_prompt'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accentEmerald.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accentEmerald.withOpacity(0.2)),
    ),
    child: TextField(
      controller: _simplePromptCtrl,
      maxLines: 5,
      onChanged: (v) => gen.setSimplePrompt(v),
      style: const TextStyle(fontSize: 16, color: Colors.white),
      decoration: const InputDecoration(
        hintText:
            "A futuristic city with floating gardens and neon lights at sunset, cinematic lighting, 8k resolution...",
        hintStyle: TextStyle(color: Colors.white24, fontSize: 16),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _buildAdvancedPromptInput(GeneratorProvider gen) => Container(
    key: const ValueKey('advanced_prompt'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accentEmerald.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: accentEmerald.withOpacity(0.2)),
    ),
    child: TextField(
      controller: _advancedPromptCtrl,
      maxLines: 5,
      onChanged: (v) => gen.setAdvancedPrompt(v),
      style: const TextStyle(fontSize: 16, color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Describe what you want to change in the image...",
        hintStyle: TextStyle(color: Colors.white24, fontSize: 16),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _buildAspectRatioSelector(GeneratorProvider gen) {
    final ratios = ["1:1 Square", "16:9 Wide", "9:16 Story", "4:3 Photo"];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: ratios.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final r = ratios[i];
          final isSel = gen.aspectRatio == r.split(' ').first;
          return GestureDetector(
            onTap: () => gen.setAspectRatio(r.split(' ').first),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSel ? accentEmerald : accentEmerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? accentEmerald : accentEmerald.withOpacity(0.2),
                ),
              ),
              child: Text(
                r,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isSel ? Colors.white : Colors.white70,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvPanel(GeneratorProvider gen) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        if (gen.isI2I)
          _slider('DENOISE', gen.denoise, 0.1, 1.0, (v) => gen.setDenoise(v)),
        _slider('STEPS', gen.steps, 1, 50, (v) => gen.setSteps(v)),
        if (!gen.isI2I) _slider('CFG', gen.cfg, 1, 20, (v) => gen.setCfg(v)),
        _buildSeedInput(gen),
      ],
    ),
  );

  Widget _buildSeedInput(GeneratorProvider gen) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SEED',
                style: TextStyle(fontSize: 9, color: Colors.white30),
              ),
              TextField(
                controller: _seedCtrl,
                onChanged: (v) => gen.setSeed(int.tryParse(v)),
                keyboardType: TextInputType.number,
                enabled: !gen.randomSeed,
                style: const TextStyle(fontSize: 12, color: accentEmerald),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        const Text(
          'RANDOM',
          style: TextStyle(fontSize: 9, color: Colors.white30),
        ),
        Switch(
          value: gen.randomSeed,
          onChanged: (v) => gen.setRandomSeed(v),
          activeColor: accentEmerald,
        ),
      ],
    ),
  );

  Widget _slider(
    String l,
    double v,
    double min,
    double max,
    Function(double) c,
  ) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white30,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            v.toStringAsFixed(1),
            style: const TextStyle(fontSize: 9, color: accentEmerald),
          ),
        ],
      ),
      Slider(
        value: v,
        min: min,
        max: max,
        onChanged: c,
        activeColor: accentEmerald,
      ),
    ],
  );

  Widget _buildGenerateButton(GeneratorProvider gen) => GestureDetector(
    onTap: _isSub ? null : () => _submit(gen),
    child: Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentEmerald,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentEmerald.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSub)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else ...[
            Icon(
              gen.isI2I ? Icons.edit_note : Icons.auto_awesome,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              gen.isI2I ? "Apply Edits" : "Generate Image",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildRecentGrid(List<AiTask> tasks) {
    if (tasks.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text(
          "No recent creations",
          style: TextStyle(color: Colors.white24),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) {
        final t = tasks[i];
        return GestureDetector(
          onTap: () => FullScreenGallery.show(ctx, tasks, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              t.resultImageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: glassColor),
            ),
          ),
        );
      },
    );
  }
}

// --- Music Generator ---
class MusicGeneratorScreen extends StatefulWidget {
  const MusicGeneratorScreen({super.key});
  @override
  State<MusicGeneratorScreen> createState() => _MusicGeneratorScreenState();
}

class _MusicGeneratorScreenState extends State<MusicGeneratorScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _tagsCtrl = TextEditingController();
  final TextEditingController _lyricsCtrl = TextEditingController();
  bool _isSub = false;
  bool _showMixer = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final gen = Provider.of<MusicGeneratorProvider>(context, listen: false);
    _promptCtrl.text = gen.prompt;
    _tagsCtrl.text = gen.tags;
    _lyricsCtrl.text = gen.lyrics;
  }

  void _submit(MusicGeneratorProvider gen) async {
    setState(() => _isSub = true);
    try {
      await ApiService.generateMusic(
        prompt: gen.isSimpleMode ? _promptCtrl.text : null,
        tags: gen.isSimpleMode ? null : _tagsCtrl.text,
        lyrics: gen.isSimpleMode ? null : _lyricsCtrl.text,
        bpm: gen.bpm,
        duration: gen.duration,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Composing...'),
          backgroundColor: accentEmerald,
        ),
      );
    } finally {
      setState(() => _isSub = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<MusicGeneratorProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: accentEmerald.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _mBtn(
                  'SIMPLE',
                  gen.isSimpleMode,
                  () => gen.setIsSimpleMode(true),
                ),
                _mBtn(
                  'ADVANCED',
                  !gen.isSimpleMode,
                  () => gen.setIsSimpleMode(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (gen.isSimpleMode)
            _in('WHAT KIND OF MUSIC?', _promptCtrl, 5, (v) => gen.setPrompt(v))
          else ...[
            _in('TAGS', _tagsCtrl, 2, (v) => gen.setTags(v)),
            const SizedBox(height: 16),
            _in('LYRICS', _lyricsCtrl, 8, (v) => gen.setLyrics(v)),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() => _showMixer = !_showMixer),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _showMixer ? 'HIDE MIXER' : 'OPEN MIXER',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _showMixer
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 14,
                  color: Colors.white24,
                ),
              ],
            ),
          ),
          if (_showMixer) _mixerPanel(gen),
          const SizedBox(height: 32),
          _buildComposeButton(gen),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildComposeButton(MusicGeneratorProvider gen) => GestureDetector(
    onTap: _isSub ? null : () => _submit(gen),
    child: Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentEmerald,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentEmerald.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _isSub
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                "COMPOSE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
      ),
    ),
  );

  Widget _mBtn(String l, bool a, VoidCallback t) => Expanded(
    child: GestureDetector(
      onTap: t,
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
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: a ? Colors.white : Colors.white30,
            ),
          ),
        ),
      ),
    ),
  );
  Widget _in(String l, TextEditingController c, int n, Function(String) o) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: c,
              maxLines: n,
              onChanged: o,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(16),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      );
  Widget _mixerPanel(MusicGeneratorProvider gen) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.black12,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        _sRow('BPM', gen.bpm.toDouble(), 40, 200, (v) => gen.setBpm(v)),
        _sRow(
          'DURATION',
          gen.duration.toDouble(),
          10,
          300,
          (v) => gen.setDuration(v),
        ),
      ],
    ),
  );
  Widget _sRow(
    String l,
    double v,
    double min,
    double max,
    Function(double) c,
  ) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 9, color: Colors.white30)),
          Text(
            v.toInt().toString(),
            style: const TextStyle(fontSize: 9, color: accentEmerald),
          ),
        ],
      ),
      Slider(
        value: v,
        min: min,
        max: max,
        onChanged: c,
        activeColor: accentEmerald,
      ),
    ],
  );
}

// --- Monitor Screen (Bento Timeline) ---
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
                  ...groups[keys[idx]]!
                      .map((t) => _buildBentoCard(ctx, t, prov))
                      .toList(),
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
        subtitle: Row(
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
                      onPressed: () => Provider.of<PlaybackProvider>(
                        context,
                        listen: false,
                      ).setPlaylist([task]),
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

// --- Library Screen (Timeline Gallery) ---
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
        Provider.of<PlaybackProvider>(context, listen: false).setPlaylist([t]);
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
                    child: const Icon(Icons.music_note, color: accentEmerald),
                  )
                : Image.network(t.resultImageUrl!, fit: BoxFit.cover),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
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

// --- Full Screen Gallery ---
class FullScreenGallery extends StatelessWidget {
  final List<AiTask> images;
  final int initialIndex;
  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });
  static void show(BuildContext context, List<AiTask> list, int idx) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenGallery(images: list, initialIndex: idx),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: PageView.builder(
        itemCount: images.length,
        controller: PageController(initialPage: initialIndex),
        itemBuilder: (ctx, i) => InteractiveViewer(
          child: Center(child: Image.network(images[i].resultImageUrl!)),
        ),
      ),
    );
  }
}

// --- Player Overlay ---
class GlobalMiniCirclePlayer extends StatelessWidget {
  const GlobalMiniCirclePlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<PlaybackProvider>(context);
    if (p.currentTask == null) return const SizedBox.shrink();
    return Positioned(
      bottom: 100,
      right: 20,
      child: FloatingActionButton(
        onPressed: p.togglePlay,
        backgroundColor: accentEmerald,
        child: Icon(
          p.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.white,
        ),
      ),
    );
  }
}
