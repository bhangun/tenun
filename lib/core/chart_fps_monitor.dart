import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';

typedef PerformanceDropCallback = void Function(double frameTimeMs, int consecutiveDrops);

class ChartFpsMonitor {
  static const double _targetFrameTime = 16.67; // 60 FPS
  static const int _consecutiveDropThreshold = 5;
  
  static Ticker? _ticker;
  static int _consecutiveDrops = 0;
  static PerformanceDropCallback? _onDrop;

  static void start({PerformanceDropCallback? onDrop}) {
    if (_ticker != null) return;
    _onDrop = onDrop;
    Duration? lastFrameTime;
    
    _ticker = Ticker((elapsed) {
      if (lastFrameTime != null) {
        final delta = elapsed - lastFrameTime!;
        final frameTimeMs = delta.inMicroseconds / 1000.0;
        
        if (frameTimeMs > _targetFrameTime * 1.5) { // Allow 50% tolerance
          _consecutiveDrops++;
          if (_consecutiveDrops >= _consecutiveDropThreshold) {
            _onDrop?.call(frameTimeMs, _consecutiveDrops);
            debugPrint('[Tenun] ⚠️ Performance warning: Dropped frames (${frameTimeMs.toStringAsFixed(2)}ms)');
          }
        } else {
          _consecutiveDrops = 0;
        }
      }
      lastFrameTime = elapsed;
    });
    _ticker!.start();
  }

  static void stop() {
    _ticker?.stop();
    _ticker = null;
  }
}