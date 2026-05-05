import 'dart:async';

class HintController {
  HintController({required this.delaySeconds});

  final int delaySeconds;
  Timer? _timer;
  void Function(int dotId)? onHintActivate;

  void startHintTimer(int dotId) {
    _timer?.cancel();
    _timer = Timer(Duration(seconds: delaySeconds), () {
      onHintActivate?.call(dotId);
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    cancel();
  }
}
