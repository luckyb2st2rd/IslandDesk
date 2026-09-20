class ProductivitySnapshot {
  const ProductivitySnapshot({
    this.noteText = '',
    this.timerDurationSeconds = 300,
    this.timerRemainingSeconds = 300,
    this.timerEndAt,
    this.timerRunning = false,
  });

  final String noteText;
  final int timerDurationSeconds;
  final int timerRemainingSeconds;
  final DateTime? timerEndAt;
  final bool timerRunning;
}
