import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'models/task_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Pro Max Design System Tokens
    const primarySlate = Color(0xFF1E293B);
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
          secondary: primarySlate,
          surface: const Color(0xFF1E293B),
          background: bgSpace,
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
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Global Silk Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: Image.asset(
                'assets/images/bg_texture.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              GeneratorScreen(),
              MonitorScreen(),
              LibraryScreen(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildGlassNavbar(),
    );
  }

  Widget _buildGlassNavbar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: const Color(0xFF22C55E).withOpacity(0.2),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.bolt_outlined),
                selectedIcon: Icon(Icons.bolt),
                label: 'Ignite',
              ),
              NavigationDestination(
                icon: Icon(Icons.terminal_outlined),
                selectedIcon: Icon(Icons.terminal),
                label: 'Engine',
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view),
                label: 'Vault',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Generator Screen (Pro Max Edition) ---
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TextEditingController _promptController = TextEditingController();
  bool _isSubmitting = false;
  late AnimationController _pulseController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _submit() async {
    final pr = _promptController.text.trim();
    if (pr.isEmpty) return;
    setState(() => _isSubmitting = true);
    try {
      final pid = await ApiService.generateImage(pr);
      if (pid != null) {
        await StorageService.saveTask(
          AiTask(
            promptId: pid,
            prompt: pr,
            status: 'pending',
            timestamp: DateTime.now(),
          ),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('COMMAND RECEIVED BY ENGINE'),
              backgroundColor: Color(0xFF22C55E),
            ),
          );
          _promptController.clear();
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('LINK ERROR: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPrismIcon(),
              const SizedBox(height: 48),
              _buildTitle(),
              const SizedBox(height: 64),
              _buildBentoInput(),
              const SizedBox(height: 48),
              _buildIgniteButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrismIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 140,
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF22C55E,
                ).withOpacity(0.1 + (_pulseController.value * 0.15)),
                blurRadius: 40 + (_pulseController.value * 20),
                spreadRadius: 10,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Image.asset('assets/images/app_icon.png'),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'COMFY PRO MAX',
          style: GoogleFonts.archivo(
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'QUANTUM IMAGE SYNTHESIZER',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 6,
            color: const Color(0xFF22C55E).withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: TextField(
            controller: _promptController,
            maxLines: 4,
            style: GoogleFonts.spaceGrotesk(fontSize: 18, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Transmit your vision...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
              contentPadding: const EdgeInsets.all(32),
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIgniteButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submit,
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF22C55E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF22C55E).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Center(
          child: _isSubmitting
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  'IGNITE ENGINE',
                  style: GoogleFonts.archivo(
                    fontSize: 18,
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

// --- Monitor Screen (Bento Style) ---
class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen>
    with AutomaticKeepAliveClientMixin {
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
      if (mounted &&
          _tasks.any((t) => t.status == 'pending' || t.status == 'running')) {
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
    final list = await StorageService.getTasks();
    if (!mounted) return;
    setState(() => _tasks = list);

    for (int i = 0; i < _tasks.length; i++) {
      final t = _tasks[i];
      if (t.status == 'pending' || t.status == 'running') {
        final data = await ApiService.checkStatus(t.promptId);
        if (data != null && mounted) {
          final s = data['status'];
          final p = (data['progress'] as num?)?.toDouble() ?? 0.0;
          if (s != t.status) {
            String? url;
            DateTime? comp;
            if (s == 'completed') {
              comp = DateTime.now();
              if (data['images'] != null)
                url = ApiService.getImageUrl(data['images'].first);
            } else if (s == 'cancelled') {
              comp = DateTime.now();
            }
            await StorageService.updateTaskStatus(
              t.promptId,
              s,
              imageUrl: url,
              completedAt: comp,
            );
            setState(
              () => _tasks[i] = t.copyWith(
                status: s,
                resultImageUrl: url,
                completedAt: comp,
              ),
            );
          }
          setState(() => _progress[t.promptId] = p);
        }
      }
    }
  }

  void _relaunch(String prompt) async {
    try {
      final pid = await ApiService.generateImage(prompt);
      if (pid != null) {
        await StorageService.saveTask(
          AiTask(
            promptId: pid,
            prompt: prompt,
            status: 'pending',
            timestamp: DateTime.now(),
          ),
        );
        _refresh();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'LOGBOOK',
          style: GoogleFonts.archivo(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Text(
                'EMPTY REGISTRY',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.1),
                  letterSpacing: 4,
                ),
              ),
            )
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
    final isCancelled = task.status == 'cancelled';
    final isRunning = task.status == 'running';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF22C55E).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Theme(
        data: ThemeData.dark().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          leading: _buildStatusPulse(task.status, p),
          title: Text(
            task.prompt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(task.status),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.timer_outlined,
                  size: 12,
                  color: Colors.white24,
                ),
                const SizedBox(width: 4),
                Text(
                  task.durationString,
                  style: const TextStyle(fontSize: 10, color: Colors.white24),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  _meta('ENGINE_ID', task.promptId),
                  _meta(
                    'TIMESTAMP',
                    task.timestamp.toString().substring(11, 19),
                  ),
                  if (task.completedAt != null)
                    _meta(
                      'COMPLETED',
                      task.completedAt.toString().substring(11, 19),
                    ),
                  _meta('INPUT_PROMPT', task.prompt),
                  if (isDone && task.resultImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: GestureDetector(
                        onTap: () => ResultDialog.show(
                          context,
                          task.resultImageUrl!,
                          task.prompt,
                        ),
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
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isDone || isCancelled)
                        TextButton.icon(
                          onPressed: () => _relaunch(task.prompt),
                          icon: const Icon(
                            Icons.refresh,
                            size: 16,
                            color: Color(0xFF22C55E),
                          ),
                          label: const Text(
                            'REGENERATE',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      if (isRunning || task.status == 'pending')
                        TextButton.icon(
                          onPressed: () async {
                            await ApiService.cancelTask(task.promptId);
                            await StorageService.updateTaskStatus(
                              task.promptId,
                              'cancelled',
                              completedAt: DateTime.now(),
                            );
                            _refresh();
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('HALT'),
                        )
                      else
                        TextButton.icon(
                          onPressed: () async {
                            await StorageService.deleteTask(task.promptId);
                            _refresh();
                          },
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'PURGE',
                            style: TextStyle(color: Colors.redAccent),
                          ),
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

  Widget _buildStatusPulse(String status, double progress) {
    final color = _getStatusColor(status);
    return Stack(
      alignment: Alignment.center,
      children: [
        if (status == 'running')
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: color,
            ),
          ),
        Icon(_getStatusIcon(status), color: color, size: 18),
      ],
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.white24,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String s) {
    if (s == 'completed') return const Color(0xFF22C55E);
    if (s == 'cancelled') return Colors.redAccent;
    if (s == 'running') return const Color(0xFF22C55E);
    if (s == 'pending') return Colors.amber;
    return Colors.grey;
  }

  IconData _getStatusIcon(String s) {
    if (s == 'completed') return Icons.verified_user;
    if (s == 'cancelled') return Icons.error_outline;
    if (s == 'running') return Icons.bolt;
    return Icons.access_time;
  }
}

// --- Library Screen (Bento Grid) ---
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
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
    final list = await StorageService.getTasks();
    if (mounted) {
      final res = list.where((t) => t.status == 'completed').toList();
      if (res.length != _images.length) setState(() => _images = res);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'IMAGE VAULT',
          style: GoogleFonts.archivo(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: _images.isEmpty
          ? Center(
              child: Text(
                'VAULT SEALED',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.1),
                  letterSpacing: 4,
                ),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: _images.length,
              itemBuilder: (context, idx) {
                final t = _images[idx];
                return GestureDetector(
                  onTap: () =>
                      ResultDialog.show(context, t.resultImageUrl!, t.prompt),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            t.resultImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(color: Colors.white10),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.9),
                                  ],
                                ),
                              ),
                              child: Text(
                                t.prompt,
                                maxLines: 2,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
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

// --- Common Components ---
class ResultDialog extends StatelessWidget {
  final String imageUrl;
  final String prompt;
  const ResultDialog({super.key, required this.imageUrl, required this.prompt});

  static void show(BuildContext context, String url, String pr) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) =>
          ResultDialog(imageUrl: url, prompt: pr),
      transitionBuilder: (context, anim1, anim2, child) => FadeTransition(
        opacity: anim1,
        child: ScaleTransition(scale: anim1, child: child),
      ),
    );
  }

  Future<void> _dl(BuildContext context) async {
    try {
      final r = await http.get(Uri.parse(imageUrl));
      final d = await getApplicationDocumentsDirectory();
      final f = File(
        '${d.path}/comfy_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await f.writeAsBytes(r.bodyBytes);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('IMAGE STORED IN VAULT'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
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
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: InteractiveViewer(child: Image.network(imageUrl)),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  prompt,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('SAVE IMAGE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white10,
                      ),
                    ),
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
