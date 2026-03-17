import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../models/task_model.dart';
import '../providers/generator_provider.dart';
import '../providers/task_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/full_screen_gallery.dart';
import '../widgets/camera_control.dart';

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
    if (gen.mode == GeneratorMode.textToImage) {
      if (_simplePromptCtrl.text.isEmpty) return;
    } else {
      if (gen.inputImageBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a base image first')),
        );
        return;
      }
    }

    setState(() => _isSub = true);
    try {
      String? pid;
      if (gen.mode == GeneratorMode.textToImage) {
        pid = await ApiService.generateImage(
          _simplePromptCtrl.text,
          steps: gen.steps.toInt(),
          cfg: gen.cfg,
          seed: gen.randomSeed ? null : int.tryParse(_seedCtrl.text),
          sampler: gen.sampler,
          width: gen.width,
          height: gen.height,
        );
      } else {
        String? sName = gen.serverImageName;
        sName ??= await ApiService.uploadImage(
          gen.inputImageBytes!,
          gen.inputImageFilename!,
        );
        if (sName != null) {
          gen.serverImageName = sName;
          if (gen.mode == GeneratorMode.imageEdit) {
            pid = await ApiService.generateEdit(
              prompt: _advancedPromptCtrl.text,
              image: sName,
              denoise: gen.denoise,
              seed: gen.randomSeed ? null : int.tryParse(_seedCtrl.text),
              steps: gen.steps.toInt(),
            );
          } else if (gen.mode == GeneratorMode.multiAngle) {
            pid = await ApiService.generateMultiAngle(
              image: sName,
              horizontalAngle: gen.horizontalAngle,
              verticalAngle: gen.verticalAngle,
              zoom: gen.zoom,
            );
          }
        }
      }

      if (pid != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing...'),
            backgroundColor: accentEmerald,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSub = false);
    }
  }

  void _generateRandomPrompt(GeneratorProvider gen) {
    const prompts = [
      "A futuristic city with floating gardens and neon lights at sunset, cinematic lighting, 8k resolution, highly detailed",
      "Cyberpunk street market in the rain, neon signs reflecting in puddles, intricate details, volumetric lighting",
      "Ancient forest with glowing mushrooms and mystical creatures, ethereal atmosphere, fantasy art style",
      "Minimalist architectural masterpiece in the desert, sharp lines, dramatic shadows, sand dunes in background",
      "Close-up portrait of a robot with human-like expressions, exposed circuitry, metallic textures, professional bokeh",
      "Space station orbiting a purple gas giant, asteroid belt, cosmic dust, epic scale, sci-fi concept art",
      "A cozy library with books flying around, magical dust, warm sunlight through stained glass, whimsical atmosphere",
      "Steampunk airship fleet sailing through a sea of clouds at dawn, brass details, billowing smoke",
      "An underwater city with bioluminescent structures, giant jellyfish, schools of glowing fish, deep sea atmosphere, cinematic",
      "A mystical mountain temple surrounded by cherry blossoms and fog, traditional Japanese architecture, peaceful, 8k",
      "Hyper-realistic portrait of an explorer in a dense jungle, sweat on skin, detailed gear, dappled sunlight through canopy",
      "A surreal landscape with floating islands, cascading waterfalls, and giant crystal formations, vibrant colors",
      "Vintage 1950s diner on Mars, red dust outside windows, classic cars with thrusters, retro-futurism style",
      "A magical potion shop with colorful liquids in ornate bottles, mysterious ingredients, soft candlelight, whimsical",
      "Post-apocalyptic city reclaimed by nature, skyscrapers covered in vines, wild animals roaming streets, dramatic lighting",
      "A futuristic laboratory with holographic displays, scientists in clean suits, advanced technology, sterile atmosphere",
      "Viking village in a snowy fjord under northern lights, wooden longhouses, flickering torches, epic atmosphere",
      "An enchanted garden with giant flowers, hummingbirds with iridescent feathers, soft morning dew, fantasy aesthetic",
      "Retro-style travel poster of a colony on the moon, domed cities, earth in the background, flat vector art style",
      "A majestic dragon perched on a volcanic peak, flowing lava, dark clouds, epic scale, high-fantasy illustration",
      "Symmetry portrait of a galactic goddess, stars and nebulae in hair, cosmic energy, ethereal glow, masterpiece",
      "A solarpunk city with lush greenery on every building, wind turbines, clean canals, bright sunny day, optimistic future",
      "Noir detective office in a rainy city, venetian blind shadows, cigarette smoke, classic 1940s aesthetic, black and white",
      "A giant robotic guardian standing in a desert of blue sand, ancient ruins, two suns in the sky, sci-fi concept art",
      "Whimsical treehouse village in a giant redwood forest, rope bridges, lanterns, cozy atmosphere, storybook style",
    ];
    final r = (DateTime.now().millisecondsSinceEpoch % prompts.length).toInt();
    final p = prompts[r];
    _simplePromptCtrl.text = p;
    gen.setSimplePrompt(p);
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
          _fadeIn(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: accentEmerald.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _modeBtn('文生图', gen.mode == GeneratorMode.textToImage, () => gen.setMode(GeneratorMode.textToImage)),
                  _modeBtn('图片编辑', gen.mode == GeneratorMode.imageEdit, () => gen.setMode(GeneratorMode.imageEdit)),
                  _modeBtn('多角度', gen.mode == GeneratorMode.multiAngle, () => gen.setMode(GeneratorMode.multiAngle)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (gen.mode != GeneratorMode.textToImage) ...[
            _fadeIn(delay: 1, child: _sectionLabel("基础图片")),
            const SizedBox(height: 8),
            _fadeIn(delay: 2, child: _buildI2IPicker(gen)),
            const SizedBox(height: 24),
          ],

          if (gen.mode == GeneratorMode.multiAngle) ...[
            _fadeIn(delay: 3, child: _sectionLabel("相机控制 (360° 无死角)")),
            const SizedBox(height: 12),
            _fadeIn(delay: 4, child: CameraControl(
              horizontalAngle: gen.horizontalAngle,
              verticalAngle: gen.verticalAngle,
              zoom: gen.zoom,
              onHorizontalChanged: (h) => gen.setMultiAngle(h, gen.verticalAngle, gen.zoom),
              onVerticalChanged: (v) => gen.setMultiAngle(gen.horizontalAngle, v, gen.zoom),
              onZoomChanged: (z) => gen.setMultiAngle(gen.horizontalAngle, gen.verticalAngle, z),
            )),
            const SizedBox(height: 24),
          ],

          if (gen.mode != GeneratorMode.multiAngle) ...[
            _fadeIn(delay: 5, child: _sectionLabel(gen.mode == GeneratorMode.imageEdit ? "编辑指令" : "提示词")),
            const SizedBox(height: 8),
            _fadeIn(delay: 6, child: Stack(
              children: [
                gen.mode == GeneratorMode.imageEdit
                    ? _buildAdvancedPromptInput(gen)
                    : _buildSimplePromptInput(gen),
                if (gen.mode == GeneratorMode.textToImage)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: _ScaleButton(
                      onTap: () => _generateRandomPrompt(gen),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentEmerald,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: accentEmerald.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_fix_high, size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'MAGIC',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )),
            const SizedBox(height: 24),
          ],


          if (gen.mode == GeneratorMode.textToImage) ...[
            _fadeIn(delay: 7, child: _sectionLabel("画面比例")),
            const SizedBox(height: 12),
            _fadeIn(delay: 8, child: _buildAspectRatioSelector(gen)),
            const SizedBox(height: 24),
          ],

          if (gen.mode != GeneratorMode.multiAngle) ...[
            _fadeIn(delay: 9, child: GestureDetector(
              onTap: () => setState(() => _showAdv = !_showAdv),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_showAdv ? '隐藏高级选项' : '高级选项', style: const TextStyle(fontSize: 10, color: Colors.white24, fontWeight: FontWeight.bold)),
                  Icon(_showAdv ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: Colors.white24),
                ],
              ),
            )),
            if (_showAdv) _buildAdvPanel(gen),
            const SizedBox(height: 32),
          ],

          _fadeIn(delay: 10, child: _buildGenerateButton(gen)),
          const SizedBox(height: 40),

          _fadeIn(delay: 11, child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("最近创作", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Provider.of<NavigationProvider>(context, listen: false).setIndex(2),
                child: const Text("查看全部", style: TextStyle(color: accentEmerald, fontWeight: FontWeight.bold)),
              ),
            ],
          )),
          const SizedBox(height: 16),
          _fadeIn(delay: 12, child: _buildRecentGrid(displayTasks)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _fadeIn({required Widget child, int delay = 0}) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.0, end: 1.0),
    duration: Duration(milliseconds: 600 + (delay * 100)),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      );
    },
    child: child,
  );

  Widget _modeBtn(String l, bool a, VoidCallback t) => Expanded(
    child: _ScaleButton(
      onTap: t,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: a ? accentEmerald : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: a ? [BoxShadow(color: accentEmerald.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Center(
          child: Text(
            l,
            style: TextStyle(
              fontSize: 12,
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
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white24, letterSpacing: 1.5),
    ),
  );

  Widget _buildI2IPicker(GeneratorProvider gen) => GestureDetector(
    onTap: () async {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
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
        border: Border.all(color: gen.inputImageBytes != null ? accentEmerald.withOpacity(0.5) : accentEmerald.withOpacity(0.1)),
      ),
      child: gen.inputImageBytes != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(gen.inputImageBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                ),
                Positioned(
                  bottom: 12, right: 12,
                  child: GestureDetector(
                    onTap: () => gen.setInputImage(null, null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: accentEmerald.withOpacity(0.5)),
                const SizedBox(height: 8),
                Text('点击上传基础图片', style: TextStyle(fontSize: 10, color: accentEmerald.withOpacity(0.5), fontWeight: FontWeight.bold)),
              ],
            ),
    ),
  );

  Widget _buildSimplePromptInput(GeneratorProvider gen) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: accentEmerald.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: accentEmerald.withOpacity(0.2))),
    child: TextField(
      controller: _simplePromptCtrl,
      maxLines: 5,
      onChanged: (v) => gen.setSimplePrompt(v),
      style: const TextStyle(fontSize: 16, color: Colors.white),
      decoration: const InputDecoration(
        hintText: "描述你想生成的画面...",
        hintStyle: TextStyle(color: Colors.white24, fontSize: 16),
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    ),
  );

  Widget _buildAdvancedPromptInput(GeneratorProvider gen) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: accentEmerald.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: accentEmerald.withOpacity(0.2))),
    child: TextField(
      controller: _advancedPromptCtrl,
      maxLines: 5,
      onChanged: (v) => gen.setAdvancedPrompt(v),
      style: const TextStyle(fontSize: 16, color: Colors.white),
      decoration: const InputDecoration(
        hintText: "描述你想修改的内容...",
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
                border: Border.all(color: isSel ? accentEmerald : accentEmerald.withOpacity(0.2)),
              ),
              child: Text(r, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSel ? Colors.white : Colors.white70)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvPanel(GeneratorProvider gen) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
    child: Column(
      children: [
        if (gen.mode == GeneratorMode.imageEdit)
          _slider('重绘强度', gen.denoise, 0.1, 1.0, (v) => gen.setDenoise(v)),
        _slider('步数', gen.steps, 1, 50, (v) => gen.setSteps(v)),
        if (gen.mode == GeneratorMode.textToImage) _slider('提示词引导', gen.cfg, 1, 20, (v) => gen.setCfg(v)),
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
              const Text('种子值', style: TextStyle(fontSize: 9, color: Colors.white30)),
              TextField(
                controller: _seedCtrl,
                onChanged: (v) => gen.setSeed(int.tryParse(v)),
                keyboardType: TextInputType.number,
                enabled: !gen.randomSeed,
                style: const TextStyle(fontSize: 12, color: accentEmerald),
                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
              ),
            ],
          ),
        ),
        const Text('随机', style: TextStyle(fontSize: 9, color: Colors.white30)),
        Switch(value: gen.randomSeed, onChanged: (v) => gen.setRandomSeed(v), activeThumbColor: accentEmerald),
      ],
    ),
  );

  Widget _slider(String l, double v, double min, double max, Function(double) c) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l, style: const TextStyle(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold)),
          Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 9, color: accentEmerald)),
        ],
      ),
      Slider(value: v, min: min, max: max, onChanged: c, activeColor: accentEmerald),
    ],
  );

  Widget _buildGenerateButton(GeneratorProvider gen) => _ScaleButton(
    onTap: _isSub ? null : () => _submit(gen),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentEmerald,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accentEmerald.withOpacity(0.4),
            blurRadius: _isSub ? 10 : 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSub)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          else ...[
            Icon(gen.mode == GeneratorMode.textToImage ? Icons.auto_awesome : (gen.mode == GeneratorMode.imageEdit ? Icons.edit_note : Icons.camera), color: Colors.white),
            const SizedBox(width: 12),
            Text(
              gen.mode == GeneratorMode.textToImage ? "开始生成" : (gen.mode == GeneratorMode.imageEdit ? "开始编辑" : "生成视角"),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildRecentGrid(List<AiTask> tasks) {
    if (tasks.isEmpty) return Container(height: 200, alignment: Alignment.center, child: const Text("暂无创作", style: TextStyle(color: Colors.white24)));
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16),
      itemCount: tasks.length,
      itemBuilder: (ctx, i) {
        final t = tasks[i];
        return GestureDetector(
          onTap: () => FullScreenGallery.show(ctx, tasks, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(t.resultImageUrl ?? '', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: glassColor)),
          ),
        );
      },
    );
  }
}

class _ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _ScaleButton({required this.child, this.onTap});

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        if (widget.onTap != null) {
          HapticFeedback.lightImpact();
          widget.onTap!();
        }
      },
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
