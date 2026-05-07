import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dot_story/screens/drawing/hint_controller.dart';

void main() {
  group('HintController', () {
    test('fires onHintActivate with correct dot id after delay', () {
      fakeAsync((fake) {
        int? fired;
        final ctrl = HintController(delaySeconds: 3)
          ..onHintActivate = (id) => fired = id;

        ctrl.startHintTimer(7);
        expect(fired, isNull);

        fake.elapse(const Duration(seconds: 3));
        expect(fired, 7);

        ctrl.dispose();
      });
    });

    test('does not fire before delay elapses', () {
      fakeAsync((fake) {
        int? fired;
        final ctrl = HintController(delaySeconds: 5)
          ..onHintActivate = (id) => fired = id;

        ctrl.startHintTimer(1);
        fake.elapse(const Duration(seconds: 4));
        expect(fired, isNull);

        ctrl.dispose();
      });
    });

    test('cancel() prevents onHintActivate from firing', () {
      fakeAsync((fake) {
        int? fired;
        final ctrl = HintController(delaySeconds: 3)
          ..onHintActivate = (id) => fired = id;

        ctrl.startHintTimer(2);
        fake.elapse(const Duration(seconds: 1));
        ctrl.cancel();
        fake.elapse(const Duration(seconds: 5));

        expect(fired, isNull);
        ctrl.dispose();
      });
    });

    test('starting a new timer replaces the pending one', () {
      fakeAsync((fake) {
        final fired = <int>[];
        final ctrl = HintController(delaySeconds: 3)
          ..onHintActivate = fired.add;

        ctrl.startHintTimer(1);
        fake.elapse(const Duration(seconds: 1));
        ctrl.startHintTimer(2); // replaces timer for dot 1
        fake.elapse(const Duration(seconds: 3));

        // dot 1 timer was cancelled; only dot 2 fires
        expect(fired, [2]);
        ctrl.dispose();
      });
    });

    test('dispose() cancels pending timer without throwing', () {
      fakeAsync((fake) {
        int? fired;
        final ctrl = HintController(delaySeconds: 3)
          ..onHintActivate = (id) => fired = id;

        ctrl.startHintTimer(5);
        ctrl.dispose();
        fake.elapse(const Duration(seconds: 5));

        expect(fired, isNull);
      });
    });

    test('does not crash when onHintActivate is null', () {
      fakeAsync((fake) {
        final ctrl = HintController(delaySeconds: 1);
        ctrl.startHintTimer(3);
        expect(() => fake.elapse(const Duration(seconds: 2)), returnsNormally);
        ctrl.dispose();
      });
    });

    test('cancel() is safe to call when no timer is pending', () {
      final ctrl = HintController(delaySeconds: 3);
      expect(() => ctrl.cancel(), returnsNormally);
      ctrl.dispose();
    });
  });
}
