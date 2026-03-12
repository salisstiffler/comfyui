class AiTask {
  final String promptId;
  final String prompt;
  final String status;
  final String? resultImageUrl;
  final String? resultAudioUrl;
  final String? resultFilename;
  final double? musicDuration; // Planned song length in seconds
  final DateTime timestamp; // Submission Time
  final DateTime? completedAt; // Completion Time
  final String type; // 'image' or 'music'

  // Advanced Params
  final int steps;
  final double cfg;
  final int? seed;
  final String sampler;
  final int batchSize;
  final int width;
  final int height;
  final String? workflowMode; // 'SIMPLE' or 'ADVANCED'
  final double progress;

  AiTask({
    required this.promptId,
    required this.prompt,
    required this.status,
    this.resultImageUrl,
    this.resultAudioUrl,
    this.resultFilename,
    this.musicDuration,
    required this.timestamp,
    this.completedAt,
    this.type = 'image',
    this.steps = 8,
    this.cfg = 1.0,
    this.seed,
    this.sampler = 'res_multistep',
    this.batchSize = 1,
    this.width = 1024,
    this.height = 1024,
    this.workflowMode,
    this.progress = 0.0,
  });

  bool get isMusic => type == 'music';

  Map<String, dynamic> toMap() {
    return {
      'promptId': promptId,
      'prompt': prompt,
      'status': status,
      'resultImageUrl': resultImageUrl,
      'resultAudioUrl': resultAudioUrl,
      'resultFilename': resultFilename,
      'musicDuration': musicDuration,
      'timestamp': timestamp.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'type': type,
      'steps': steps,
      'cfg': cfg,
      'seed': seed,
      'sampler': sampler,
      'batchSize': batchSize,
      'width': width,
      'height': height,
      'progress': progress,
    };
  }

  factory AiTask.fromMap(Map<String, dynamic> map) {
    return AiTask(
      promptId: map['prompt_id'] ?? map['promptId'] ?? '',
      prompt: map['prompt'] ?? '',
      status: map['status'] ?? 'queued',
      resultImageUrl: map['resultImageUrl'],
      resultAudioUrl: map['resultAudioUrl'],
      resultFilename: map['resultFilename'],
      musicDuration: (map['musicDuration'] as num?)?.toDouble(),
      timestamp: map['timestamp'] is String 
        ? DateTime.parse(map['timestamp']) 
        : DateTime.fromMillisecondsSinceEpoch(((map['timestamp'] as num?) ?? 0).toInt() * 1000),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      type: map['type'] ?? 'image',
      steps: map['steps'] ?? 8,
      cfg: (map['cfg'] as num?)?.toDouble() ?? 1.0,
      seed: map['seed'],
      sampler: map['sampler'] ?? 'res_multistep',
      batchSize: map['batchSize'] ?? 1,
      width: map['width'] ?? 1024,
      height: map['height'] ?? 1024,
      progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }

  AiTask copyWith({
    String? status,
    String? resultImageUrl,
    String? resultAudioUrl,
    DateTime? completedAt,
    double? progress,
  }) {
    return AiTask(
      promptId: promptId,
      prompt: prompt,
      status: status ?? this.status,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      resultAudioUrl: resultAudioUrl ?? this.resultAudioUrl,
      resultFilename: resultFilename,
      musicDuration: musicDuration,
      timestamp: timestamp,
      completedAt: completedAt ?? this.completedAt,
      type: type,
      steps: steps,
      cfg: cfg,
      seed: seed,
      sampler: sampler,
      batchSize: batchSize,
      width: width,
      height: height,
      workflowMode: workflowMode,
      progress: progress ?? this.progress,
    );
  }

  String get durationString {
    if (completedAt != null) {
      final diff = completedAt!.difference(timestamp);
      return _formatDuration(diff);
    }
    if (status == 'completed' || status == 'cancelled') return 'FIN';
    final diff = DateTime.now().difference(timestamp);
    return _formatDuration(diff);
  }

  String _formatDuration(Duration d) {
    int m = d.inMinutes.remainder(60);
    int s = d.inSeconds.remainder(60);
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
