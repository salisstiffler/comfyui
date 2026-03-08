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
import 'providers/player_provider.dart';

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

    if (task.width == 1024 && task.height == 1024)
      aspectRatio = '1:1';
    else if (task.width == 832 && task.height == 1216)
      aspectRatio = '2:3';
    else if (task.width == 1216 && task.height == 832)
      aspectRatio = '3:2';

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

class MusicGeneratorProvider extends ChangeNotifier {
  String tags = "acoustic ballad, indie pop, soothing melancholy";
  String lyrics =
      "[intro]\n(Piano intro)\n[verse]\nRain falls softly on the glass...";
  int bpm = 190;
  int duration = 120;
  double cfg = 2.0;
  int? seed;
  bool randomSeed = true;

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GeneratorProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => MusicGeneratorProvider()),
        ChangeNotifierProvider(create: (_) => PlaybackProvider()),
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
        textTheme: GoogleFonts.spaceGroteskTextTheme(
          ThemeData.dark().textTheme,
        ),
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
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkHealth(),
    );
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
      if (mounted && _isServerOnline != isAlive)
        setState(() => _isServerOnline = isAlive);
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
                    children: [
                      const GeneratorScreen(),
                      const MusicGeneratorScreen(),
                      const MonitorScreen(),
                      const LibraryScreen(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Global Mini Circle Player
          const GlobalMiniCirclePlayer(),
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
                  color: _isServerOnline ? const Color(0xFF22C55E) : Colors.red,
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
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'Waking up engine...'
                                : 'Bridge not found',
                          ),
                          backgroundColor: success
                              ? const Color(0xFF22C55E)
                              : Colors.red,
                        ),
                      );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'WAKE UP',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
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
                  child: Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Colors.white,
                  ),
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
      builder: (ctx) => AlertDialog(
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
              if (mounted) setState(() => _username = controller.text);
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
                label: 'IMAGES',
              ),
              NavigationDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note),
                label: 'MUSIC',
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

// --- Music Generator Screen ---
class MusicGeneratorScreen extends StatefulWidget {
  const MusicGeneratorScreen({super.key});
  @override
  State<MusicGeneratorScreen> createState() => _MusicGeneratorScreenState();
}

class _MusicGeneratorScreenState extends State<MusicGeneratorScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _lyricsController = TextEditingController();
  final TextEditingController _seedController = TextEditingController();
  bool _isSubmitting = false;
  bool _showAdvanced = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final gen = Provider.of<MusicGeneratorProvider>(context, listen: false);
      _tagsController.text = gen.tags;
      _lyricsController.text = gen.lyrics;
      if (gen.seed != null) _seedController.text = gen.seed.toString();
    });
  }

  void _submit(MusicGeneratorProvider gen) async {
    if (_tagsController.text.trim().isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final pid = await ApiService.generateMusic(
        tags: _tagsController.text.trim(),
        lyrics: _lyricsController.text.trim(),
        bpm: gen.bpm,
        duration: gen.duration,
        steps: 8,
        cfg: gen.cfg,
        seed: gen.randomSeed ? null : int.tryParse(_seedController.text),
      );
      if (pid != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Composing your masterpiece...'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Composition failed: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<MusicGeneratorProvider>(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Column(
              children: [
                Text(
                  'MUSIC STUDIO',
                  style: GoogleFonts.archivo(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI AUDITORY ENGINE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                    color: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildGlassInput(
              'TAGS (GENRE / VIBE)',
              _tagsController,
              2,
              'lo-fi, chill, melancholic piano...',
            ),
            const SizedBox(height: 16),
            _buildGlassInput(
              'LYRICS',
              _lyricsController,
              6,
              '[verse]\nEnter lyrics...',
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => setState(() => _showAdvanced = !_showAdvanced),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showAdvanced ? 'HIDE MIXER' : 'OPEN MIXER',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white30,
                      letterSpacing: 1,
                    ),
                  ),
                  Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white30,
                    size: 16,
                  ),
                ],
              ),
            ),
            if (_showAdvanced) _buildMixer(gen),
            const SizedBox(height: 32),
            _buildSynthButton(gen),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassInput(
    String label,
    TextEditingController controller,
    int lines,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: TextField(
            controller: controller,
            maxLines: lines,
            style: GoogleFonts.spaceGrotesk(),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
              contentPadding: const EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMixer(MusicGeneratorProvider gen) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _sliderRow(
            'BPM',
            gen.bpm.toDouble(),
            40,
            200,
            gen.setBpm,
            labelSuffix: ' BPM',
          ),
          const SizedBox(height: 16),
          _sliderRow(
            'DURATION',
            gen.duration.toDouble(),
            10,
            300,
            gen.setDuration,
            labelSuffix: 's',
          ),
          const SizedBox(height: 16),
          _sliderRow(
            'GUIDANCE (CFG)',
            gen.cfg,
            0,
            5,
            gen.setCfg,
            divisions: 50,
          ),
          const SizedBox(height: 16),
          _seedRow(gen),
        ],
      ),
    );
  }

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    Function(double) onChanged, {
    String labelSuffix = "",
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            Text(
              labelSuffix.isEmpty
                  ? value.toStringAsFixed(1)
                  : '${value.toInt()}$labelSuffix',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFF22C55E),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            activeTrackColor: const Color(0xFF22C55E),
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _seedRow(MusicGeneratorProvider gen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SEED',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white54,
              ),
            ),
            Row(
              children: [
                const Text(
                  'RANDOM',
                  style: TextStyle(fontSize: 10, color: Colors.white30),
                ),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: gen.randomSeed,
                    onChanged: gen.setRandomSeed,
                    activeColor: const Color(0xFF22C55E),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!gen.randomSeed)
          TextField(
            controller: _seedController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Enter Seed',
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSynthButton(MusicGeneratorProvider gen) {
    return GestureDetector(
      onTap: _isSubmitting ? null : () => _submit(gen),
      child: Container(
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: _isSubmitting
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                )
              : Text(
                  'COMPOSE',
                  style: GoogleFonts.archivo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}

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
  final List<String> _subjects = [
    "A cyberpunk metropolis",
    "A floating crystal island",
    "A samurai robot",
    "A Victorian clockwork owl",
    "An ancient underwater temple",
    "A cosmic nebula dragon",
    "A tiny mouse wizard",
    "A futuristic space station",
    "A surreal desert with melting clocks",
    "A mystical forest with glowing fungi",
    "A steampunk airship",
    "A polar bear in a suit",
    "A high-tech laboratory",
    "A medieval alchemist's study",
    "A rainy Tokyo street",
    "A crystalline unicorn",
    "A marble statue of a digital deity",
    "A hidden oasis in space",
  ];
  final List<String> _styles = [
    "Studio Ghibli animation style",
    "Unreal Engine 5 render",
    "Cyberpunk 2077 aesthetic",
    "Oil painting by Van Gogh",
    "Hyper-realistic photography",
    "Minimalist 3D render",
    "Dark fantasy illustration",
    "Retro-wave vaporwave style",
    "Ukiyo-e woodblock print",
    "Cinematic lighting",
    "Pencil sketch",
    "Neon noir atmosphere",
    "Art Nouveau",
    "Futuristic bioluminescence",
    "National Geographic macro photography",
  ];
  final List<String> _details = [
    "highly detailed, 8k resolution",
    "volumetric lighting, soft shadows",
    "intricate patterns, masterpiece",
    "vivid colors, sharp focus",
    "ethereal atmosphere, cinematic fog",
    "extreme close-up, bokeh effect",
    "concept art, gold leaf accents",
    "symmetry, ultra-detailed textures",
  ];

  void _surpriseMe(GeneratorProvider gen) {
    final random = Random();
    final p =
        "${_subjects[random.nextInt(_subjects.length)]}, ${_styles[random.nextInt(_styles.length)]}, ${_details[random.nextInt(_details.length)]}";
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
      final pid = await ApiService.generateImage(
        pr,
        steps: gen.steps.toInt(),
        cfg: gen.cfg,
        seed: gen.randomSeed ? null : int.tryParse(_seedController.text),
        sampler: gen.sampler,
        batchSize: gen.batchSize.toInt(),
        width: size.width.toInt(),
        height: size.height.toInt(),
      );
      if (pid != null && mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synthesis started...'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Connection error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<GeneratorProvider>(context);
    if (_promptController.text != gen.prompt)
      _promptController.text = gen.prompt;
    if (!gen.randomSeed &&
        gen.seed != null &&
        _seedController.text != gen.seed.toString())
      _seedController.text = gen.seed.toString();
    else if (gen.randomSeed)
      _seedController.clear();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) => Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(
                        0xFF22C55E,
                      ).withOpacity(0.1 + (_pulseController.value * 0.15)),
                      blurRadius: 30 + (_pulseController.value * 20),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset('assets/images/app_icon.png'),
              ),
            ),
            const SizedBox(height: 32),
            Column(
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
            ),
            const SizedBox(height: 48),
            Container(
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
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Describe your imagination...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                      ),
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
                          icon: const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.amber,
                          ),
                          tooltip: 'INSPIRATION',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
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
                      _showAdvanced
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white30,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            if (_showAdvanced) _buildAdvancedControls(gen),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _isSubmitting ? null : () => _submit(gen),
              child: Container(
                height: 64,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'SYNTHESIZE',
                          style: GoogleFonts.archivo(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
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
                      items: _aspectRatios.keys
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
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
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      isExpanded: true,
                      items: _samplers
                          .map(
                            (k) => DropdownMenuItem(value: k, child: Text(k)),
                          )
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

  Widget _sliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    int? divisions,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _label(label),
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white70),
            ),
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

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white30,
      letterSpacing: 1,
    ),
  );
  InputDecoration _inputDeco() => InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

// --- Monitor Screen (Timeline Style) ---
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});
  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with AutomaticKeepAliveClientMixin {
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
      if (mounted &&
          _groupedTasks.values.any(
            (list) => list.any(
              (t) => t.status != 'completed' && t.status != 'cancelled',
            ),
          ))
        setState(() {});
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
    list.sort((a, b) {
      if (a.status == 'running' || a.status == 'pending') return -1;
      if (b.status == 'running' || b.status == 'pending') return 1;
      return (b.completedAt ?? b.timestamp).compareTo(
        a.completedAt ?? a.timestamp,
      );
    });
    final Map<String, List<AiTask>> groups = {};
    for (var t in list) {
      final dateStr =
          (t.status == 'running' ||
              t.status == 'pending' ||
              t.status == 'queued')
          ? "ACTIVE TASKS"
          : DateFormat('yyyy年MM月dd日').format(t.completedAt ?? t.timestamp);
      groups.putIfAbsent(dateStr, () => []).add(t);
    }
    setState(() => _groupedTasks = groups);
    for (final t in list) {
      if (t.status == 'running' ||
          t.status == 'pending' ||
          t.status == 'queued') {
        final data = await ApiService.checkStatus(t.promptId);
        if (data != null && mounted && data['status'] == 'running')
          setState(
            () => _progress[t.promptId] =
                (data['progress'] as num?)?.toDouble() ?? 0.5,
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final keys = _groupedTasks.keys.toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.transparent,
            title: Text(
              'TASK HISTORY',
              style: GoogleFonts.archivo(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            centerTitle: true,
            automaticallyImplyLeading: false,
          ),
          if (keys.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'NO TASKS YET',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.1),
                    letterSpacing: 2,
                  ),
                ),
              ),
            )
          else
            for (var date in keys) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text(
                    date,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1,
                      color: date == "ACTIVE TASKS"
                          ? const Color(0xFF22C55E)
                          : Colors.white38,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildBentoCard(_groupedTasks[date]![index]),
                    childCount: _groupedTasks[date]!.length,
                  ),
                ),
              ),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildBentoCard(AiTask task) {
    final isRunning = task.status == 'running';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF22C55E).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: _buildStatusPulse(
            task.status,
            _progress[task.promptId] ?? 0.0,
          ),
          title: Text(
            task.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _statusBadge(task.status),
                const SizedBox(width: 12),
                Icon(
                  task.isMusic ? Icons.music_note : Icons.timer_outlined,
                  size: 10,
                  color: Colors.white24,
                ),
                const SizedBox(width: 4),
                Text(
                  task.isMusic ? 'AUDIO COMPOSITION' : task.durationString,
                  style: const TextStyle(fontSize: 10, color: Colors.white24),
                ),
                if (!task.isMusic) ...[
                  const SizedBox(width: 12),
                  Text(
                    '${task.width}x${task.height} • ${task.steps}S',
                    style: const TextStyle(fontSize: 10, color: Colors.white24),
                  ),
                ],
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
                  _meta(
                    'TECHNICAL SPECS',
                    'CFG: ${task.cfg} • Sampler: ${task.sampler} • Seed: ${task.seed ?? "Auto"}',
                  ),
                  if (task.status == 'completed') ...[
                    if (!task.isMusic && task.resultImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: GestureDetector(
                          onTap: () =>
                              FullScreenGallery.show(context, [task], 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              task.resultImageUrl!,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      )
                    else if (task.isMusic && task.resultAudioUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: GestureDetector(
                          onTap: () {
                            final player = Provider.of<PlaybackProvider>(
                              context,
                              listen: false,
                            );
                            player.setPlaylist([task]);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF22C55E).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Color(0xFF22C55E),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'PLAY GENERATED MUSIC',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF22C55E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Provider.of<GeneratorProvider>(
                            context,
                            listen: false,
                          ).updateFromTask(task);
                          Provider.of<NavigationProvider>(
                            context,
                            listen: false,
                          ).setIndex(0);
                        },
                        icon: const Icon(
                          Icons.refresh,
                          size: 16,
                          color: Color(0xFF22C55E),
                        ),
                        label: const Text(
                          'EVOLVE',
                          style: TextStyle(
                            color: Color(0xFF22C55E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isRunning)
                        TextButton.icon(
                          onPressed: () => ApiService.cancelTask(
                            task.promptId,
                          ).then((_) => _refresh()),
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
    Color c = status == 'completed'
        ? const Color(0xFF22C55E)
        : (status == 'running'
              ? Colors.amber
              : (status == 'cancelled' ? Colors.red : Colors.grey));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: c,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildStatusPulse(String status, double progress) {
    Color c = status == 'completed'
        ? const Color(0xFF22C55E)
        : (status == 'running' ? Colors.amber : Colors.grey);
    IconData i = status == 'completed'
        ? Icons.check_circle_outline
        : (status == 'running' ? Icons.sync : Icons.access_time);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (status == 'running')
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 1.5,
              color: c,
            ),
          ),
        Icon(i, color: c, size: 18),
      ],
    );
  }

  Widget _meta(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 8,
          color: Colors.white24,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70)),
    ],
  );
}

// --- Library Screen (iOS Style) ---
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  List<AiTask> _tasks = [];
  bool _isLoading = true;
  String _activeTab = "IMAGES";

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final tasks = await ApiService.getJobs();
      if (mounted)
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _tasks.where((t) {
      if (t.status != 'completed') return false;
      if (_activeTab == "IMAGES") {
        return !t.isMusic && t.resultImageUrl != null;
      } else {
        return t.isMusic && t.resultAudioUrl != null;
      }
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [_tabButton("IMAGES"), _tabButton("MUSIC")]),
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
              ? Center(
                  child: Text(
                    'NO ${_activeTab} FOUND',
                    style: const TextStyle(color: Colors.white24),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _activeTab == "IMAGES" ? 2 : 1,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: _activeTab == "IMAGES" ? 200 : 110,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    if (_activeTab == "IMAGES") {
                      return GestureDetector(
                        onTap: () =>
                            FullScreenGallery.show(context, filtered, index),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  task.resultImageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              ),
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
                                    colors: [
                                      Colors.black.withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      task.resultFilename ?? 'UNTITLED',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${task.width} x ${task.height}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      final player = Provider.of<PlaybackProvider>(
                        context,
                        listen: false,
                      );
                      return GestureDetector(
                        onTap: () =>
                            player.setPlaylist(filtered, initialIndex: index),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1B4B),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.music_note_rounded,
                                      color: Color(0xFF22C55E),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          task.resultFilename ?? 'AUDIO_FILE',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${task.musicDuration?.toInt() ?? 120}s',
                                          style: const TextStyle(
                                            color: Color(0xFF22C55E),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white30,
                                    size: 32,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _tabButton(String label) {
    final active = _activeTab == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF22C55E) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : Colors.white30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@override
// --- Full Screen Gallery Viewer (Improved for Windows) ---
class FullScreenGallery extends StatefulWidget {
  final List<AiTask> images;
  final int initialIndex;
  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });
  static void show(BuildContext context, List<AiTask> images, int index) =>
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (context, _, __) =>
              FullScreenGallery(images: images, initialIndex: index),
        ),
      );
  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showUI = false;
  double _dragOffset = 0;
  final TransformationController _transformationController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _toggleUI() => setState(() => _showUI = !_showUI);

  Future<void> _dl() async {
    try {
      final r = await http.get(
        Uri.parse(widget.images[_currentIndex].resultImageUrl!),
      );
      final d = await getApplicationDocumentsDirectory();
      final f = File(
        '${d.path}/comfy_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await f.writeAsBytes(r.bodyBytes);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to Gallery'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
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
      backgroundColor: Colors.black.withOpacity(
        max(0, 1 - (_dragOffset.abs() / 300)),
      ),
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft)
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            else if (event.logicalKey == LogicalKeyboardKey.arrowRight)
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            else if (event.logicalKey == LogicalKeyboardKey.escape)
              Navigator.pop(context);
          }
        },
        child: GestureDetector(
          onTap: _toggleUI,
          onDoubleTap: _handleDoubleTap,
          onVerticalDragUpdate: (details) {
            // 只有在未放大时允许下拉退出
            if (_transformationController.value.getMaxScaleOnAxis() <= 1.0)
              setState(() => _dragOffset += details.delta.dy);
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset.abs() > 150)
              Navigator.pop(context);
            else
              setState(() => _dragOffset = 0);
          },
          child: Stack(
            children: [
              Transform.translate(
                offset: Offset(0, _dragOffset),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (idx) {
                    setState(() => _currentIndex = idx);
                    _transformationController.value = Matrix4.identity();
                  },
                  itemBuilder: (context, index) => Hero(
                    tag: 'img_${widget.images[index].promptId}',
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 5.0,
                      child: Center(
                        child: Image.network(
                          widget.images[index].resultImageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, event) =>
                              event == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_showUI) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              'SYNTHESIS',
                              style: GoogleFonts.archivo(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'jm',
                              ).format(widget.images[_currentIndex].timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: Colors.black,
                                title: const Text('SPECS'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Steps: ${widget.images[_currentIndex].steps}',
                                    ),
                                    Text(
                                      'CFG: ${widget.images[_currentIndex].cfg}',
                                    ),
                                    Text(
                                      'Sampler: ${widget.images[_currentIndex].sampler}',
                                    ),
                                    Text(
                                      'Seed: ${widget.images[_currentIndex].seed}',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.images[_currentIndex].prompt,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _action(
                              Icons.file_download_outlined,
                              'EXPORT',
                              _dl,
                            ),
                            _action(Icons.refresh, 'EVOLVE', () {
                              Navigator.pop(context);
                              Provider.of<GeneratorProvider>(
                                context,
                                listen: false,
                              ).updateFromTask(widget.images[_currentIndex]);
                              Provider.of<NavigationProvider>(
                                context,
                                listen: false,
                              ).setIndex(0);
                            }),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback ontap) => InkWell(
    onTap: ontap,
    child: Column(
      children: [
        Icon(icon, size: 24, color: const Color(0xFF22C55E)),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF22C55E),
          ),
        ),
      ],
    ),
  );
}

// --- Premium Mini Circle Player ---
class GlobalMiniCirclePlayer extends StatefulWidget {
  const GlobalMiniCirclePlayer({super.key});

  @override
  State<GlobalMiniCirclePlayer> createState() => _GlobalMiniCirclePlayerState();
}

class _GlobalMiniCirclePlayerState extends State<GlobalMiniCirclePlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlaybackProvider>(context);
    final task = player.currentTask;

    if (task == null) return const SizedBox.shrink();

    if (player.isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    return Positioned(
      bottom: 100,
      right: 20,
      child: GestureDetector(
        onTap: () => _openStudioPro(context),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Circular Progress Bar
                SizedBox(
                  width: 68,
                  height: 68,
                  child: CustomPaint(
                    painter: CircularProgressPainter(
                      progress: player.duration.inSeconds > 0
                          ? player.position.inSeconds /
                                player.duration.inSeconds
                          : 0.0,
                    ),
                  ),
                ),
                // Inner Disc
                RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10, width: 2),
                      image: task.resultImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(task.resultImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      gradient: task.resultImageUrl == null
                          ? const LinearGradient(
                              colors: [Color(0xFF1E1B4B), Color(0xFF0F0F23)],
                            )
                          : null,
                    ),
                    child: task.resultImageUrl == null
                        ? const Icon(
                            Icons.music_note_rounded,
                            color: Color(0xFF22C55E),
                            size: 28,
                          )
                        : null,
                  ),
                ),
                // Overlay Play/Pause
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      player.togglePlay();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openStudioPro(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "StudioProPlayer",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const StudioProPlayer();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        );
      },
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  CircularProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    canvas.drawCircle(center, radius, paint);

    final progressPaint = Paint()
      ..color = const Color(0xFF22C55E)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// --- Studio Pro Player (Vinyl Aesthetic Redesign) ---
class StudioProPlayer extends StatefulWidget {
  const StudioProPlayer({super.key});

  @override
  State<StudioProPlayer> createState() => _StudioProPlayerState();
}

class _StudioProPlayerState extends State<StudioProPlayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlaybackProvider>(context);
    final task = player.currentTask;

    if (task == null) return const SizedBox.shrink();

    if (player.isPlaying) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    return Scaffold(
      backgroundColor: const Color(
        0xFFF1F5F9,
      ), // Light background for vinyl player
      body: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta! > 10) Navigator.pop(context);
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          children: [
                            const Spacer(),
                            _buildVinylHardware(
                              task,
                              constraints.maxHeight * 0.6,
                            ),
                            const Spacer(),
                            _buildTrackMetadata(task),
                            const SizedBox(height: 12),
                            _buildPlaybackInterface(context, player),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.expand_more_rounded,
                color: Colors.black54,
                size: 32,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            "VINYL PLAYER",
            style: GoogleFonts.spaceGrotesk(
              color: Colors.black87,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              letterSpacing: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVinylHardware(AiTask task, double maxHeight) {
    return Container(
      width: maxHeight,
      height: maxHeight,
      decoration: BoxDecoration(
        color: const Color(0xFFD1D5DB), // Silver hardware
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(-5, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Stack(
        children: [
          // Hardware Texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: CustomPaint(painter: BrushedMetalPainter()),
            ),
          ),
          // Logo/Brand detail
          const Positioned(
            top: 12,
            left: 12,
            child: Icon(Icons.blur_circular, color: Colors.black26, size: 24),
          ),
          // Record Platform
          Center(
            child: Container(
              width: maxHeight * 0.85,
              height: maxHeight * 0.85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.05),
                border: Border.all(color: Colors.black12, width: 2),
              ),
              child: Center(
                child: _buildRotatingRecord(task, maxHeight * 0.78),
              ),
            ),
          ),
          // Tonearm Detail
          Positioned(
            top: 10,
            right: 0,
            child: Transform.rotate(
              angle: 0.1,
              child: Container(
                width: 10,
                height: maxHeight * 0.5,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF9CA3AF), Color(0xFF4B5563)],
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotatingRecord(AiTask task, double diameter) {
    return RotationTransition(
      turns: _rotationController,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Black Vinyl
          Container(
            width: diameter,
            height: diameter,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF111827),
            ),
            child: CustomPaint(painter: VinylGroovesPainter()),
          ),
          // Center Art
          ClipOval(
            child: SizedBox(
              width: diameter * 0.45,
              height: diameter * 0.45,
              child: task.resultImageUrl != null
                  ? Image.network(task.resultImageUrl!, fit: BoxFit.cover)
                  : Container(
                      color: const Color(0xFF1E1B4B),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Color(0xFF22C55E),
                        size: 40,
                      ),
                    ),
            ),
          ),
          // Spindle Hole
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackMetadata(AiTask task) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.resultFilename ?? "STUDIO_COMPOSITION",
                    style: GoogleFonts.righteous(
                      fontSize: 28,
                      color: const Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.prompt,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      color: Colors.black45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.favorite_border_rounded,
              color: Colors.black26,
              size: 28,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildTag("ComfyUI"),
            _buildTag("AI Render"),
            _buildTag("V6"),
          ],
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.black45,
        ),
      ),
    );
  }

  Widget _buildPlaybackInterface(
    BuildContext context,
    PlaybackProvider player,
  ) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: const Color(0xFF1F2937),
            inactiveTrackColor: Colors.black.withOpacity(0.05),
            thumbColor: const Color(0xFF1F2937),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: player.position.inSeconds.toDouble().clamp(
              0,
              max(1, player.duration.inSeconds.toDouble()),
            ),
            max: max(1, player.duration.inSeconds.toDouble()),
            onChanged: (v) => player.seek(Duration(seconds: v.toInt())),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(player.position),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.black38,
              ),
            ),
            Text(
              _formatDuration(player.duration),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.black38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(
                player.mode == PlaybackMode.order
                    ? Icons.trending_flat_rounded
                    : (player.mode == PlaybackMode.single
                          ? Icons.repeat_one_rounded
                          : (player.mode == PlaybackMode.shuffle
                                ? Icons.shuffle_rounded
                                : Icons.repeat_rounded)),
                color: player.mode == PlaybackMode.order
                    ? Colors.black26
                    : const Color(0xFF22C55E),
              ),
              onPressed: player.togglePlaybackMode,
            ),
            IconButton(
              icon: const Icon(
                Icons.skip_previous_rounded,
                size: 40,
                color: Color(0xFF1F2937),
              ),
              onPressed: player.previous,
            ),
            GestureDetector(
              onTap: player.togglePlay,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFF1F2937),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                size: 40,
                color: Color(0xFF1F2937),
              ),
              onPressed: player.next,
            ),
            IconButton(
              icon: const Icon(
                Icons.queue_music_rounded,
                color: Colors.black26,
              ),
              onPressed: () => _showPlaylist(context, player),
            ),
          ],
        ),
      ],
    );
  }

  void _showPlaylist(BuildContext context, PlaybackProvider player) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "PLAYLIST",
              style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: player.playlist.length,
                itemBuilder: (context, index) {
                  final t = player.playlist[index];
                  final isCurrent = index == player.currentIndex;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      t.resultFilename ?? "Composition",
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF22C55E)
                            : Colors.black87,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () {
                      player.playAtIndex(index);
                      Navigator.pop(context);
                    },
                    trailing: isCurrent
                        ? const Icon(
                            Icons.volume_up_rounded,
                            color: Color(0xFF22C55E),
                          )
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }
}

class BrushedMetalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.1)
      ..strokeWidth = 1;
    for (double i = 0; i < size.width; i += 4) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    for (double r = size.width * 0.25; r < size.width * 0.5; r += 4) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
