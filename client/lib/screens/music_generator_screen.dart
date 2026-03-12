import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/music_provider.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Composing...'),
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
