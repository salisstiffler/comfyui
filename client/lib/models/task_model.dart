class AiTask {
  final String promptId;
  final String prompt;
  final String status;
  final String? resultImageUrl;
  final DateTime timestamp; // Submission Time
  final DateTime? completedAt; // Completion Time

  AiTask({
    required this.promptId,
    required this.prompt,
    required this.status,
    this.resultImageUrl,
    required this.timestamp,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'promptId': promptId,
      'prompt': prompt,
      'status': status,
      'resultImageUrl': resultImageUrl,
      'timestamp': timestamp.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory AiTask.fromMap(Map<String, dynamic> map) {
    return AiTask(
      promptId: map['promptId'],
      prompt: map['prompt'],
      status: map['status'],
      resultImageUrl: map['resultImageUrl'],
      timestamp: DateTime.parse(map['timestamp']),
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
    );
  }

  AiTask copyWith({
    String? status,
    String? resultImageUrl,
    DateTime? completedAt,
  }) {
    return AiTask(
      promptId: promptId,
      prompt: prompt,
      status: status ?? this.status,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      timestamp: timestamp,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get durationString {
    // If we have a recorded completion time, use it.
    if (completedAt != null) {
      final diff = completedAt!.difference(timestamp);
      return _formatDuration(diff);
    }

    // If the task is in a terminal state but missing completedAt (e.g. from version upgrade),
    // stop ticking to avoid confusion.
    if (status == 'completed' || status == 'cancelled') {
      return '...'; // Or a fallback like 'Done'
    }

    // Otherwise, it's still running or pending. Match against current time.
    final diff = DateTime.now().difference(timestamp);
    return _formatDuration(diff);
  }

  String _formatDuration(Duration d) {
    String m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inMinutes > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}
