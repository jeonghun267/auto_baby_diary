import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// A reusable timer widget for feeding and sleep tracking.
/// Shows elapsed time in MM:SS format with Start/Pause/Stop buttons.
class TimerWidget extends StatefulWidget {
  /// The type of record: 'feeding' or 'sleep'
  final String recordType;

  /// Called when the timer is stopped with the elapsed duration
  final void Function(Duration elapsed) onStop;

  /// Called when the user cancels without saving
  final VoidCallback onCancel;

  const TimerWidget({
    super.key,
    required this.recordType,
    required this.onStop,
    required this.onCancel,
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isRunning = false;

  Color get _accentColor =>
      widget.recordType == 'feeding' ? Colors.orange : Colors.indigo;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed = _stopwatch.elapsed;
      });
    });
    setState(() => _isRunning = true);
  }

  void _pause() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _stop() {
    _stopwatch.stop();
    _timer?.cancel();
    final elapsed = _stopwatch.elapsed;
    _stopwatch.reset();
    widget.onStop(elapsed);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.recordType == 'feeding' ? '🍼 수유 타이머' : '😴 수면 타이머',
            style: AppTextStyles.labelLarge.copyWith(color: _accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            _formatDuration(_elapsed),
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w700,
              color: _accentColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel button
              IconButton(
                onPressed: () {
                  _timer?.cancel();
                  _stopwatch.stop();
                  _stopwatch.reset();
                  widget.onCancel();
                },
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.textHint.withValues(alpha: 0.15),
                  foregroundColor: AppColors.textSecondary,
                  fixedSize: const Size(48, 48),
                ),
              ),
              const SizedBox(width: 16),
              // Start / Pause button
              if (!_isRunning)
                IconButton(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(60, 60),
                  ),
                )
              else
                IconButton(
                  onPressed: _pause,
                  icon: const Icon(Icons.pause, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.white,
                    fixedSize: const Size(60, 60),
                  ),
                ),
              const SizedBox(width: 16),
              // Stop button (only enabled if stopwatch has been started at all)
              IconButton(
                onPressed: _elapsed.inSeconds > 0 ? _stop : null,
                icon: const Icon(Icons.stop),
                style: IconButton.styleFrom(
                  backgroundColor: _elapsed.inSeconds > 0
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.textHint.withValues(alpha: 0.1),
                  foregroundColor: _elapsed.inSeconds > 0
                      ? AppColors.error
                      : AppColors.textHint,
                  fixedSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
