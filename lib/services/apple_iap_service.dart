import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// App Store subscriptions for iOS. Apple requires digital subscriptions
/// bought inside an iOS app to go through in-app purchase, so iOS uses this
/// instead of the Razorpay checkout.
///
/// The garage id is passed as the purchase's application user name, which
/// StoreKit stores as the transaction's appAccountToken. The server checks
/// it so a purchase can only unlock the garage that made it.
class AppleIapService {
  AppleIapService._();
  static final AppleIapService instance = AppleIapService._();

  /// True on iOS, where subscriptions must be bought through Apple.
  static bool get isSupported => !kIsWeb && Platform.isIOS;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  /// Sends a transaction id to the server for verification. Set by the
  /// billing screen before purchasing.
  Future<void> Function(String transactionId)? onVerify;

  /// Reports the outcome of each purchase or restore to the UI.
  final ValueNotifier<IapEvent?> events = ValueNotifier(null);

  /// Starts listening to StoreKit. Safe to call more than once. Transactions
  /// left unfinished by an earlier session are re-delivered here.
  void start() {
    if (!isSupported || _sub != null) return;
    _sub = _iap.purchaseStream.listen(_handle, onError: (Object e) {
      events.value = IapEvent.error('The App Store reported an error.');
    });
  }

  Future<List<ProductDetails>> loadProducts(Set<String> ids) async {
    if (!await _iap.isAvailable()) {
      throw StateError('The App Store is not available on this device.');
    }
    final res = await _iap.queryProductDetails(ids);
    if (res.error != null) throw StateError(res.error!.message);
    return res.productDetails;
  }

  Future<void> buy(ProductDetails product, {required String garageId}) {
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: garageId,
      ),
    );
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _handle(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          events.value = const IapEvent.pending();
        case PurchaseStatus.canceled:
          events.value = const IapEvent.cancelled();
        case PurchaseStatus.error:
          events.value = IapEvent.error(
              p.error?.message ?? 'The purchase could not be completed.');
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final id = p.purchaseID;
          final verify = onVerify;
          if (id == null || verify == null) break;
          try {
            await verify(id);
            events.value = p.status == PurchaseStatus.restored
                ? const IapEvent.restored()
                : const IapEvent.purchased();
          } catch (e) {
            events.value = IapEvent.error(
                'Payment received but activation failed. Tap Restore purchases to retry.');
            // Leave the transaction unfinished so StoreKit re-delivers it.
            continue;
          }
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }
}

enum IapEventKind { pending, purchased, restored, cancelled, error }

class IapEvent {
  const IapEvent._(this.kind, [this.message]);
  const IapEvent.pending() : this._(IapEventKind.pending);
  const IapEvent.purchased() : this._(IapEventKind.purchased);
  const IapEvent.restored() : this._(IapEventKind.restored);
  const IapEvent.cancelled() : this._(IapEventKind.cancelled);
  const IapEvent.error(String message) : this._(IapEventKind.error, message);

  final IapEventKind kind;
  final String? message;
}
