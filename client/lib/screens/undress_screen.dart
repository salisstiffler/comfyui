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

class UndressScreen extends StatefulWidget {
  const UndressScreen({super.key});
  @override
  State<UndressScreen> createState() => _UndressScreenState();
}

class _UndressScreenState extends State<UndressScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isSub = false;

  @override
  bool get wantKeepAlive => true;

  void _submit(GeneratorProvider gen) async {
    if (gen.inputImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先上传一张图片'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isSub = true);
    try {
      String? sName = gen.serverImageName;
      sName ??= await ApiService.uploadImage(
        gen.inputImageBytes!,
        gen.inputImageFilename!,
      );
      if (sName != null) {
        gen.serverImageName = sName;
        final pid = await ApiService.generateUndress(image: sName);
        if (pid != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('一键脱衣任务已提交，请在库中查看结果'),
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
    final undressTasks = taskProv.tasks
        .where((t) => t.status == 'completed' && t.workflowMode == 'UNDRESS')
        .toList();
    undressTasks.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "一键脱衣",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "上传底图，AI 将根据预设工作流进行处理",
            style: TextStyle(fontSize: 14, color: Colors.white54),
          ),
          const SizedBox(height: 32),
          _buildPicker(gen),
          const SizedBox(height: 32),
          _buildActionButton(gen),
          const SizedBox(height: 48),
          const Text(
            "历史记录",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildHistoryGrid(undressTasks),
        ],
      ),
    );
  }

  Widget _buildPicker(GeneratorProvider gen) => GestureDetector(
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
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: accentEmerald.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: gen.inputImageBytes != null
              ? accentEmerald.withOpacity(0.5)
              : accentEmerald.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: gen.inputImageBytes != null
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.memory(
                    gen.inputImageBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () => gen.setInputImage(null, null),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: accentEmerald.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '点击上传底图',
                  style: TextStyle(
                    fontSize: 16,
                    color: accentEmerald.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _buildActionButton(GeneratorProvider gen) => GestureDetector(
    onTap: _isSub ? null : () => _submit(gen),
    child: Container(
      height: 64,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurple, Colors.purpleAccent],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: _isSub
            ? const CircularProgressIndicator(color: Colors.white)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_fix_high, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    "一键脱衣",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _buildHistoryGrid(List<AiTask> tasks) {
    if (tasks.isEmpty) {
      return Container(
        height: 150,
        alignment: Alignment.center,
        child: const Text(
          "暂无记录",
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
