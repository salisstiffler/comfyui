import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/task_model.dart';
import '../providers/generator_provider.dart';
import '../providers/task_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/full_screen_gallery.dart';

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
        sName ??= await ApiService.uploadImage(
            gen.inputImageBytes!,
            gen.inputImageFilename!,
          );
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
          width: gen.width,
          height: gen.height,
        );
      }
      if (pid != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing...'),
              backgroundColor: accentEmerald,
            ),
          );
        }
      }
    } finally {
      setState(() => _isSub = false);
    }
  }

  final List<String> _magicPrompts = [
    "A futuristic city with floating gardens and neon lights at sunset, cinematic lighting, 8k resolution, highly detailed",
    "Cyberpunk street market in the rain, neon signs reflecting in puddles, intricate details, volumetric lighting",
    "Ancient forest with glowing mushrooms and mystical creatures, ethereal atmosphere, fantasy art style",
    "Minimalist architectural masterpiece in the desert, sharp lines, dramatic shadows, sand dunes in background",
    "Close-up portrait of a robot with human-like expressions, exposed circuitry, metallic textures, professional bokeh",
    "Space station orbiting a purple gas giant, asteroid belt, cosmic dust, epic scale, sci-fi concept art",
    "A cozy library with books flying around, magical dust, warm sunlight through stained glass, whimsical atmosphere",
    "Steampunk airship fleet sailing through a sea of clouds at dawn, brass details, billowing smoke",
  ];

  void _generateRandomPrompt(GeneratorProvider gen) {
    final r = (DateTime.now().millisecondsSinceEpoch % _magicPrompts.length).toInt();
    final p = _magicPrompts[r];
    _simplePromptCtrl.text = p;
    gen.setSimplePrompt(p);
  }

  void _submitNsfw(GeneratorProvider gen) async {
    if (gen.inputImageBytes == null) return;
    setState(() => _isSub = true);
    try {
      String? sName = gen.serverImageName;
      sName ??= await ApiService.uploadImage(
        gen.inputImageBytes!,
        gen.inputImageFilename!,
      );
      if (sName != null) {
        gen.serverImageName = sName;
        final pid = await ApiService.generateNsfw(image: sName);
        if (pid != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('一键脱衣任务处理中...'),
              backgroundColor: Colors.deepPurple,
            ),
          );
        }
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel(gen.isI2I ? "Edit Instructions" : "Prompt"),
              if (!gen.isI2I)
                GestureDetector(
                  onTap: () => _generateRandomPrompt(gen),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: accentEmerald.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentEmerald.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_fix_high, size: 12, color: accentEmerald),
                        SizedBox(width: 4),
                        Text(
                          'MAGIC',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: accentEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
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
                  ).setIndex(2);
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
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(
                    gen.inputImageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => gen.setInputImage(null, null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
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
          activeThumbColor: accentEmerald,
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
              t.resultImageUrl ?? '',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: glassColor),
            ),
          ),
        );
      },
    );
  }
}
