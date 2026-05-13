import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/purchase_service.dart';

const _kRed    = Color(0xFFE82D2D);
const _kYellow = Color(0xFFF5C800);
const _kGreen  = Color(0xFF2DB84B);
const _kInk    = Color(0xFF1A1A2E);

List<Shadow> _inkOutline(double w) => [
  Shadow(color: _kInk, blurRadius: 0, offset: Offset(-w, -w)),
  Shadow(color: _kInk, blurRadius: 0, offset: Offset(w, -w)),
  Shadow(color: _kInk, blurRadius: 0, offset: Offset(-w, w)),
  Shadow(color: _kInk, blurRadius: 0, offset: Offset(w, w)),
];

class PurchaseSheet extends ConsumerStatefulWidget {
  const PurchaseSheet({super.key});

  @override
  ConsumerState<PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends ConsumerState<PurchaseSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF8E7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: _kInk, width: 4),
          left: BorderSide(color: _kInk, width: 4),
          right: BorderSide(color: _kInk, width: 4),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          28, 28, 28, 28 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: _kInk,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Unlock All Stories',
            style: TextStyle(
              fontFamily: 'Boogaloo',
              fontSize: 36,
              color: _kYellow,
              height: 1.0,
              shadows: _inkOutline(3),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '20 magical adventures, one tap away',
            style: TextStyle(
              fontFamily: 'Boogaloo',
              fontSize: 17,
              color: _kInk,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 24),

          // Benefits list
          ...[
            (Icons.auto_stories_rounded, 'All 20 stories — new ones added free'),
            (Icons.brush_rounded,        'Every drawing, every reveal, every chapter'),
            (Icons.child_care_rounded,   'No subscriptions. Pay once, yours forever'),
          ].map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kInk, width: 2.5),
                  ),
                  child: Icon(item.$1, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.$2,
                    style: const TextStyle(
                      fontFamily: 'Boogaloo',
                      fontSize: 16,
                      color: _kInk,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 20),

          // Buy button
          GestureDetector(
            onTap: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    final ok =
                        await ref.read(purchaseServiceProvider).buyFullAccess();
                    if (mounted) {
                      setState(() => _loading = false);
                      if (ok) {
                        Navigator.of(context).pop();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Purchase unavailable. Please try again.'),
                          ),
                        );
                      }
                    }
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _loading ? _kInk.withValues(alpha: 0.4) : _kRed,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kInk, width: 4),
                boxShadow: _loading
                    ? const []
                    : const [
                        BoxShadow(
                            color: _kInk, blurRadius: 0, offset: Offset(5, 5))
                      ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Text(
                        'Unlock Now',
                        style: TextStyle(
                          fontFamily: 'Boogaloo',
                          fontSize: 24,
                          color: Colors.white,
                          height: 1.0,
                          shadows: _inkOutline(2),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Restore purchase
          GestureDetector(
            onTap: _loading
                ? null
                : () async {
                    setState(() => _loading = true);
                    await ref.read(purchaseServiceProvider).restorePurchases();
                    if (mounted) {
                      setState(() => _loading = false);
                      Navigator.of(context).pop();
                    }
                  },
            child: const Text(
              'Restore Purchase',
              style: TextStyle(
                fontFamily: 'Boogaloo',
                fontSize: 15,
                color: _kInk,
                decoration: TextDecoration.underline,
                decorationColor: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
