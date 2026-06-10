import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tenun/tenun.dart';

void main() {
  group('ChartAnimationController lifecycle', () {
    testWidgets('disposed controller ignores late operations safely', (
      tester,
    ) async {
      final ctrl = ChartAnimationController(vsync: tester);

      ctrl.dispose();

      expect(ctrl.isDisposed, isTrue);
      expect(ctrl.progress, 1.0);
      expect(ctrl.isCompleted, isTrue);
      expect(() {
        ctrl.addListener(() {});
        ctrl.removeListener(() {});
        ctrl.stop();
        ctrl.reset();
        ctrl.dispose();
      }, returnsNormally);
      await expectLater(ctrl.forward(), completes);
      await expectLater(ctrl.replay(), completes);
    });

    testWidgets('delayed replay becomes a no-op when disposed before delay', (
      tester,
    ) async {
      final ctrl = ChartAnimationController(vsync: tester);
      var tickCount = 0;
      ctrl.addListener(() => tickCount++);

      final replay = ctrl.replay(delay: const Duration(milliseconds: 50));
      ctrl.dispose();

      await tester.pump(const Duration(milliseconds: 50));

      await expectLater(replay, completes);
      expect(ctrl.isDisposed, isTrue);
      expect(tickCount, 0);
    });
  });

  group('ChartAnimationMixin lifecycle', () {
    testWidgets('animation helpers are safe before init and after dispose', (
      tester,
    ) async {
      final key = GlobalKey<_AnimationMixinHarnessState>();

      await tester.pumpWidget(_AnimationMixinHarness(key: key));

      expect(key.currentState!.animProgress, 1.0);
      expect(key.currentState!.chartAnimation.value, 1.0);
      expect(() => key.currentState!.disposeAnimation(), returnsNormally);

      key.currentState!.initAnimation();
      await tester.pump();

      expect(key.currentState!.animProgress, lessThanOrEqualTo(1.0));

      key.currentState!.disposeAnimation();
      expect(key.currentState!.animProgress, 1.0);
      expect(key.currentState!.chartAnimation.value, 1.0);
      expect(() {
        key.currentState!.replayAnimation();
        key.currentState!.disposeAnimation();
      }, returnsNormally);
    });
  });
}

class _AnimationMixinHarness extends StatefulWidget {
  const _AnimationMixinHarness({super.key});

  @override
  State<_AnimationMixinHarness> createState() => _AnimationMixinHarnessState();
}

class _AnimationMixinHarnessState extends State<_AnimationMixinHarness>
    with TickerProviderStateMixin, ChartAnimationMixin<_AnimationMixinHarness> {
  @override
  ChartAnimationPreset get animPreset => ChartAnimationPreset.fade;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  void dispose() {
    disposeAnimation();
    super.dispose();
  }
}
