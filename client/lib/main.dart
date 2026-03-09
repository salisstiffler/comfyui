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
import 'package:file_picker/file_picker.dart';
import 'services/api_service.dart';
import 'models/task_model.dart';
import 'providers/player_provider.dart';

// --- Theme Config ---
const accentEmerald = Color(0xFF22C55E);
const bgSpace = Color(0xFF0F172A);
const glassColor = Color(0x0DFFFFFF);

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

  // I2I Fields
  bool isI2I = false;
  Uint8List? inputImageBytes;
  String? inputImageFilename;
  String? serverImageName;
  double denoise = 1.0;

  void setI2I(bool v) { isI2I = v; notifyListeners(); }
  void setInputImage(Uint8List? bytes, String? filename) {
    inputImageBytes = bytes;
    inputImageFilename = filename;
    serverImageName = null;
    notifyListeners();
  }
  void setDenoise(double v) { denoise = v; notifyListeners(); }
  void setPrompt(String p) { prompt = p; notifyListeners(); }
  void setSteps(double s) { steps = s; notifyListeners(); }
  void setCfg(double c) { cfg = c; notifyListeners(); }
  void setSampler(String s) { sampler = s; notifyListeners(); }
  void setBatchSize(double b) { batchSize = b; notifyListeners(); }
  void setAspectRatio(String a) { aspectRatio = a; notifyListeners(); }
  void setSeed(int? s) { seed = s; notifyListeners(); }
  void setRandomSeed(bool r) { randomSeed = r; notifyListeners(); }

  void updateFromTask(AiTask task) {
    prompt = task.prompt;
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

  TaskProvider() { startPolling(); }
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
  void dispose() { _timer?.cancel(); super.dispose(); }
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

  void setPrompt(String p) { prompt = p; notifyListeners(); }
  void setIsSimpleMode(bool s) { isSimpleMode = s; notifyListeners(); }
  void setTags(String t) { tags = t; notifyListeners(); }
  void setLyrics(String l) { lyrics = l; notifyListeners(); }
  void setBpm(double b) { bpm = b.toInt(); notifyListeners(); }
  void setDuration(double d) { duration = d.toInt(); notifyListeners(); }
  void setCfg(double c) { cfg = c; notifyListeners(); }
  void setSeed(int? s) { seed = s; notifyListeners(); }
  void setRandomSeed(bool r) { randomSeed = r; notifyListeners(); }
}

// --- Main App ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => GeneratorProvider()),
      ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ChangeNotifierProvider(create: (_) => MusicGeneratorProvider()),
      ChangeNotifierProvider(create: (_) => PlaybackProvider()),
      ChangeNotifierProvider(create: (_) => TaskProvider()),
    ],
    child: const MyApp(),
  ));
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
        textTheme: GoogleFonts.spaceGroteskTextTheme(ThemeData.dark().textTheme),
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
    setState(() { _user = p.getString('username') ?? "Guest"; ApiService.userId = _user; });
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
      body: Stack(children: [
        Positioned.fill(child: Opacity(opacity: 0.4, child: Image.asset('assets/images/bg_texture.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container()))),
        SafeArea(child: Column(children: [
          _header(),
          Expanded(child: PageView(controller: nav.pageController, physics: const NeverScrollableScrollPhysics(), children: [const GeneratorScreen(), const MusicGeneratorScreen(), const MonitorScreen(), const LibraryScreen()])),
        ])),
        const GlobalMiniCirclePlayer(),
      ]),
      bottomNavigationBar: _navbar(nav),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: _isOnline ? accentEmerald : Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: (_isOnline ? accentEmerald : Colors.red).withOpacity(0.5), blurRadius: 8, spreadRadius: 2)])),
        const SizedBox(width: 8),
        Text(_isOnline ? 'ENGINE READY' : 'CORE OFFLINE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white54)),
      ]),
      Text(_user.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70)),
    ]),
  );

  Widget _navbar(NavigationProvider nav) => Container(
    decoration: BoxDecoration(color: bgSpace.withOpacity(0.8), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
    child: NavigationBar(
      selectedIndex: nav.selectedIndex, onDestinationSelected: nav.setIndex,
      backgroundColor: Colors.transparent, indicatorColor: accentEmerald.withOpacity(0.1),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'IMAGES'),
        NavigationDestination(icon: Icon(Icons.music_note_outlined), selectedIcon: Icon(Icons.music_note), label: 'MUSIC'),
        NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'HISTORY'),
        NavigationDestination(icon: Icon(Icons.photo_library_outlined), selectedIcon: Icon(Icons.photo_library), label: 'GALLERY'),
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

class _GeneratorScreenState extends State<GeneratorScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _promptCtrl = TextEditingController();
  final TextEditingController _seedCtrl = TextEditingController();
  bool _isSub = false;
  bool _showAdv = false;
  late AnimationController _pulse;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    final gen = Provider.of<GeneratorProvider>(context, listen: false);
    _promptCtrl.text = gen.prompt;
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  void _submit(GeneratorProvider gen) async {
    if (_promptCtrl.text.isEmpty) return;
    if (gen.isI2I && gen.inputImageBytes == null) return;
    setState(() => _isSub = true);
    try {
      String? pid;
      if (gen.isI2I) {
        String? sName = gen.serverImageName;
        if (sName == null) sName = await ApiService.uploadImage(gen.inputImageBytes!, gen.inputImageFilename!);
        if (sName != null) { gen.serverImageName = sName; pid = await ApiService.generateEdit(prompt: _promptCtrl.text, image: sName, denoise: gen.denoise, seed: gen.randomSeed ? null : int.tryParse(_seedCtrl.text)); }
      } else {
        pid = await ApiService.generateImage(_promptCtrl.text, steps: gen.steps.toInt(), cfg: gen.cfg, seed: gen.randomSeed ? null : int.tryParse(_seedCtrl.text));
      }
      if (pid != null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing...'), backgroundColor: accentEmerald));
    } finally { setState(() => _isSub = false); }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<GeneratorProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        AnimatedBuilder(animation: _pulse, builder: (ctx, child) => Container(width: 80, height: 80, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: accentEmerald.withOpacity(0.1 + (_pulse.value * 0.15)), blurRadius: 30 + (_pulse.value * 20))]), child: Image.asset('assets/images/app_icon.png'))),
        const SizedBox(height: 24),
        Text('COMFY PRO MAX', style: GoogleFonts.archivo(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 32),
        // Mode Switch
        Container(
          padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _modeBtn('TEXT TO IMAGE', !gen.isI2I, () => gen.setI2I(false)),
            _modeBtn('IMAGE EDIT', gen.isI2I, () => gen.setI2I(true)),
          ]),
        ),
        const SizedBox(height: 24),
        if (gen.isI2I) ...[_buildI2IPicker(gen), const SizedBox(height: 20)],
        _buildGlassIn('Describe imagination...', _promptCtrl, 4, (v) => gen.setPrompt(v)),
        const SizedBox(height: 16),
        GestureDetector(onTap: () => setState(() => _showAdv = !_showAdv), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_showAdv ? 'HIDE OPTIONS' : 'ADVANCED OPTIONS', style: const TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)), Icon(_showAdv ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: Colors.white24)])),
        if (_showAdv) _buildAdvPanel(gen),
        const SizedBox(height: 32),
        _buildSubmit(gen),
      ]),
    );
  }

  Widget _modeBtn(String l, bool a, VoidCallback t) => Expanded(child: GestureDetector(onTap: t, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: a ? accentEmerald : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(l, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: a ? Colors.white : Colors.white30))))));

  Widget _buildI2IPicker(GeneratorProvider gen) => GestureDetector(
    onTap: () async {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res != null) gen.setInputImage(res.files.first.bytes, res.files.first.name);
    },
    child: Container(
      height: 180, width: double.infinity,
      decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: gen.inputImageBytes != null ? accentEmerald.withOpacity(0.5) : Colors.white10)),
      child: gen.inputImageBytes != null
          ? ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(gen.inputImageBytes!, fit: BoxFit.cover))
          : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, color: Colors.white24), SizedBox(height: 8), Text('UPLOAD BASE IMAGE', style: TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold))]),
    ),
  );

  Widget _buildGlassIn(String h, TextEditingController c, int l, Function(String) o) => Container(
    decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.05))),
    child: TextField(controller: c, maxLines: l, onChanged: o, decoration: InputDecoration(hintText: h, contentPadding: const EdgeInsets.all(20), border: InputBorder.none)),
  );

  Widget _buildAdvPanel(GeneratorProvider gen) => Container(
    margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)),
    child: Column(children: [
      if (gen.isI2I) _slider('DENOISE', gen.denoise, 0.1, 1.0, (v) => gen.setDenoise(v)),
      _slider('STEPS', gen.steps, 1, 50, (v) => gen.setSteps(v)),
      _slider('CFG', gen.cfg, 1, 20, (v) => gen.setCfg(v)),
    ]),
  );

  Widget _slider(String l, double v, double min, double max, Function(double) c) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold)), Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9, color: accentEmerald))]),
    Slider(value: v, min: min, max: max, onChanged: c, activeColor: accentEmerald),
  ]);

  Widget _buildSubmit(GeneratorProvider gen) => GestureDetector(
    onTap: _isSub ? null : () => _submit(gen),
    child: Container(height: 64, width: double.infinity, decoration: BoxDecoration(color: accentEmerald, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: accentEmerald.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]), child: Center(child: _isSub ? const CircularProgressIndicator(color: Colors.white) : Text(gen.isI2I ? 'MODIFY' : 'GENERATE', style: GoogleFonts.archivo(fontWeight: FontWeight.w800, letterSpacing: 2)))),
  );
}

// --- Music Generator ---
class MusicGeneratorScreen extends StatefulWidget {
  const MusicGeneratorScreen({super.key});
  @override
  State<MusicGeneratorScreen> createState() => _MusicGeneratorScreenState();
}

class _MusicGeneratorScreenState extends State<MusicGeneratorScreen> with AutomaticKeepAliveClientMixin {
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
    _promptCtrl.text = gen.prompt; _tagsCtrl.text = gen.tags; _lyricsCtrl.text = gen.lyrics;
  }

  void _submit(MusicGeneratorProvider gen) async {
    setState(() => _isSub = true);
    try {
      await ApiService.generateMusic(
        prompt: gen.isSimpleMode ? _promptCtrl.text : null,
        tags: gen.isSimpleMode ? null : _tagsCtrl.text,
        lyrics: gen.isSimpleMode ? null : _lyricsCtrl.text,
        bpm: gen.bpm, duration: gen.duration,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Composing...'), backgroundColor: accentEmerald));
    } finally { setState(() => _isSub = false); }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final gen = Provider.of<MusicGeneratorProvider>(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text('MUSIC STUDIO', style: GoogleFonts.archivo(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _mBtn('SIMPLE', gen.isSimpleMode, () => gen.setIsSimpleMode(true)),
            _mBtn('ADVANCED', !gen.isSimpleMode, () => gen.setIsSimpleMode(false)),
          ]),
        ),
        const SizedBox(height: 24),
        if (gen.isSimpleMode) _in('WHAT KIND OF MUSIC?', _promptCtrl, 4, (v) => gen.setPrompt(v))
        else ...[_in('TAGS', _tagsCtrl, 2, (v) => gen.setTags(v)), const SizedBox(height: 16), _in('LYRICS', _lyricsCtrl, 6, (v) => gen.setLyrics(v))],
        const SizedBox(height: 16),
        GestureDetector(onTap: () => setState(() => _showMixer = !_showMixer), child: Text(_showMixer ? 'HIDE MIXER' : 'OPEN MIXER', style: const TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold))),
        if (_showMixer) _mixerPanel(gen),
        const SizedBox(height: 32),
        ElevatedButton(onPressed: _isSub ? null : () => _submit(gen), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: accentEmerald, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), child: _isSub ? const CircularProgressIndicator(color: Colors.white) : const Text('COMPOSE')),
      ]),
    );
  }

  Widget _mBtn(String l, bool a, VoidCallback t) => Expanded(child: GestureDetector(onTap: t, child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: a ? accentEmerald : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(l, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: a ? Colors.white : Colors.white30))))));
  Widget _in(String l, TextEditingController c, int n, Function(String) o) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Container(decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(16)), child: TextField(controller: c, maxLines: n, onChanged: o, decoration: const InputDecoration(contentPadding: EdgeInsets.all(16), border: InputBorder.none)))]);
  Widget _mixerPanel(MusicGeneratorProvider gen) => Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(20)), child: Column(children: [_sRow('BPM', gen.bpm.toDouble(), 40, 200, (v) => gen.setBpm(v)), _sRow('DURATION', gen.duration.toDouble(), 10, 300, (v) => gen.setDuration(v))]));
  Widget _sRow(String l, double v, double min, double max, Function(double) c) => Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 9, color: Colors.white30)), Text(v.toInt().toString(), style: const TextStyle(fontSize: 9, color: accentEmerald))]), Slider(value: v, min: min, max: max, onChanged: c, activeColor: accentEmerald)]);
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
      final date = (t.status == 'running' || t.status == 'queued') ? "ACTIVE" : DateFormat('yyyy年MM月dd日').format(t.timestamp);
      groups.putIfAbsent(date, () => []).add(t);
    }
    final keys = groups.keys.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: tasks.isEmpty && !prov.isLoading
          ? const Center(child: Text('EMPTY RECORDS', style: TextStyle(color: Colors.white10, letterSpacing: 2)))
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: keys.length,
              itemBuilder: (ctx, idx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(bottom: 12, top: 12), child: Text(keys[idx], style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: keys[idx] == "ACTIVE" ? accentEmerald : Colors.white24))),
                ...groups[keys[idx]]!.map((t) => _buildBentoCard(ctx, t, prov)).toList(),
              ]),
            ),
    );
  }

  Widget _buildBentoCard(BuildContext context, AiTask task, TaskProvider prov) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: task.status == 'running' ? accentEmerald.withOpacity(0.3) : Colors.white.withOpacity(0.05))),
    child: Theme(data: ThemeData.dark().copyWith(dividerColor: Colors.transparent), child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: _statusPulse(task.status),
      title: Text(task.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Row(children: [
        _badge(task.status, c: task.status == 'completed' ? accentEmerald : (task.status == 'failed' ? Colors.red : Colors.amber)),
        if (task.isMusic && task.workflowMode != null) ...[const SizedBox(width: 8), _badge(task.workflowMode!, c: Colors.blue)],
      ]),
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(color: Colors.white10),
          _meta('SPECIFICATIONS', 'CFG: ${task.cfg} • Sampler: ${task.sampler} • Seed: ${task.seed ?? "Auto"}'),
          const SizedBox(height: 8),
          if (task.resultFilename != null) _meta('FILE NAME', task.resultFilename!.split('/').last),
          if (task.status == 'completed') ...[
            const SizedBox(height: 12),
            if (!task.isMusic && task.resultImageUrl != null) GestureDetector(onTap: () => FullScreenGallery.show(context, [task], 0), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(task.resultImageUrl!, height: 150, width: double.infinity, fit: BoxFit.cover)))
            else if (task.isMusic && task.resultAudioUrl != null) ElevatedButton.icon(onPressed: () => Provider.of<PlaybackProvider>(context, listen: false).setPlaylist([task]), icon: const Icon(Icons.play_arrow), label: const Text('PLAY AUDIO')),
          ],
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: IconButton(onPressed: () => ApiService.cancelTask(task.promptId).then((_) => prov.refresh()), icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white24))),
        ])),
      ],
    )),
  );

  Widget _statusPulse(String s) => Container(width: 12, height: 12, decoration: BoxDecoration(color: s == 'completed' ? accentEmerald : (s == 'running' ? Colors.amber : Colors.white10), shape: BoxShape.circle, boxShadow: [if (s == 'running') BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]));
  Widget _badge(String t, {required Color c}) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(t.toUpperCase(), style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.w900)));
  Widget _meta(String l, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.white24, fontWeight: FontWeight.bold)), Text(v, style: const TextStyle(fontSize: 10, color: Colors.white70))]);
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
    final list = prov.tasks.where((t) => t.status == 'completed' && (_tab == "IMAGES" ? !t.isMusic : t.isMusic)).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final Map<String, List<AiTask>> groups = {};
    for (var t in list) {
      final d = DateFormat('yyyy年MM月dd日').format(t.timestamp);
      groups.putIfAbsent(d, () => []).add(t);
    }
    final keys = groups.keys.toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.all(24), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(12)), child: Row(children: [_tBtn("IMAGES", _tab == "IMAGES"), _tBtn("MUSIC", _tab == "MUSIC")]))),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: keys.length,
        itemBuilder: (ctx, idx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(bottom: 12, top: 12), child: Text(keys[idx], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white24))),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _tab == "IMAGES" ? 2 : 1, crossAxisSpacing: 16, mainAxisSpacing: 16, mainAxisExtent: _tab == "IMAGES" ? 180 : 80),
            itemCount: groups[keys[idx]]!.length,
            itemBuilder: (c, i) => _item(groups[keys[idx]]![i], list),
          ),
        ]),
      )),
    ]);
  }

  Widget _item(AiTask t, List<AiTask> full) => GestureDetector(
    onTap: () { if (t.isMusic) { Provider.of<PlaybackProvider>(context, listen: false).setPlaylist([t]); } else { FullScreenGallery.show(context, full, full.indexOf(t)); } },
    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Stack(children: [
      Positioned.fill(child: t.isMusic ? Container(color: glassColor, child: const Icon(Icons.music_note, color: accentEmerald)) : Image.network(t.resultImageUrl!, fit: BoxFit.cover)),
      Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])), child: Text(t.prompt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)))),
    ])),
  );

  Widget _tBtn(String l, bool a) => Expanded(child: GestureDetector(onTap: () => setState(() => _tab = l), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: a ? accentEmerald : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(l, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: a ? Colors.white : Colors.white30))))));
}

// --- Full Screen Gallery ---
class FullScreenGallery extends StatelessWidget {
  final List<AiTask> images;
  final int initialIndex;
  const FullScreenGallery({super.key, required this.images, required this.initialIndex});
  static void show(BuildContext context, List<AiTask> list, int idx) => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenGallery(images: list, initialIndex: idx)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0), body: PageView.builder(itemCount: images.length, controller: PageController(initialPage: initialIndex), itemBuilder: (ctx, i) => InteractiveViewer(child: Center(child: Image.network(images[i].resultImageUrl!)))));
  }
}

// --- Player Overlay ---
class GlobalMiniCirclePlayer extends StatelessWidget {
  const GlobalMiniCirclePlayer({super.key});
  @override
  Widget build(BuildContext context) {
    final p = Provider.of<PlaybackProvider>(context);
    if (p.currentTask == null) return const SizedBox.shrink();
    return Positioned(bottom: 100, right: 20, child: FloatingActionButton(onPressed: p.togglePlay, backgroundColor: accentEmerald, child: Icon(p.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white)));
  }
}
