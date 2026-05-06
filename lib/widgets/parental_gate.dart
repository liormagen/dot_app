import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';

class ParentalGate {
  static DateTime? _unlockedUntil;

  /// Returns true if already unlocked within the 60-second window.
  static bool get isUnlocked {
    final until = _unlockedUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Shows the parental gate dialog.
  /// Returns true if the parent answered correctly (or was already unlocked).
  static Future<bool> show(BuildContext context) async {
    if (isUnlocked) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ParentalGateDialog(),
    );

    if (result == true) {
      _unlockedUntil = DateTime.now().add(const Duration(seconds: 60));
      return true;
    }
    return false;
  }
}

class _ParentalGateDialog extends StatefulWidget {
  const _ParentalGateDialog();

  @override
  State<_ParentalGateDialog> createState() => _ParentalGateDialogState();
}

class _ParentalGateDialogState extends State<_ParentalGateDialog> {
  late int _a;
  late int _b;
  late String _op;
  late int _answer;
  final TextEditingController _controller = TextEditingController();
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _generateQuestion();
  }

  void _generateQuestion() {
    final rand = Random();
    _a = rand.nextInt(9) + 1;
    _b = rand.nextInt(9) + 1;
    // Keep it simple: only addition and subtraction (ensure positive)
    final ops = ['+', '-', 'x'];
    _op = ops[rand.nextInt(ops.length)];
    if (_op == '-' && _b > _a) {
      final tmp = _a;
      _a = _b;
      _b = tmp;
    }
    switch (_op) {
      case '+':
        _answer = _a + _b;
        break;
      case '-':
        _answer = _a - _b;
        break;
      case 'x':
        _answer = _a * _b;
        break;
      default:
        _answer = _a + _b;
    }
  }

  void _checkAnswer() {
    final input = int.tryParse(_controller.text.trim());
    if (input == _answer) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _showError = true;
        _controller.clear();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayOp = _op == 'x' ? '×' : _op;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        l10n.parentalGateTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.parentalGateInstruction,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'What is $_a $displayOp $_b?',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              hintText: '?',
            ),
            onSubmitted: (_) => _checkAnswer(),
          ),
          if (_showError) ...[
            const SizedBox(height: 8),
            Text(
              l10n.parentalGateWrong,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancelButton),
        ),
        ElevatedButton(
          onPressed: _checkAnswer,
          child: Text(l10n.submitButton),
        ),
      ],
    );
  }
}
