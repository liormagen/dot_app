import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

const _kProductId = 'com.dotstory.fullaccess';

class PurchaseService {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _available = false;
  bool _isPurchased = false;
  ProductDetails? _product;

  bool get isPurchased => _isPurchased;
  bool get available => _available;

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (_) {},
    );

    await _loadProduct();
  }

  Future<void> _loadProduct() async {
    try {
      final response = await _iap.queryProductDetails({_kProductId});
      if (response.productDetails.isNotEmpty) {
        _product = response.productDetails.first;
      }
    } catch (_) {}
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == _kProductId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          _isPurchased = true;
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase).catchError((_) {});
          }
        }
      }
    }
  }

  Future<bool> buyFullAccess() async {
    if (!_available || _product == null) return false;
    try {
      final purchaseParam = PurchaseParam(productDetails: _product!);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (_) {
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) return;
    try {
      await _iap.restorePurchases();
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final purchaseServiceProvider = Provider<PurchaseService>(
  (_) => throw UnimplementedError('Override purchaseServiceProvider'),
);
