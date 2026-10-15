import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Play Billing for Smart Printer Pro.
///
/// Active, expired, and canceled subscriptions are decided by the store.
/// A canceled purchase is never treated as a successful buy.
class BillingService extends ChangeNotifier with WidgetsBindingObserver {
  BillingService._internal();

  static final BillingService instance = BillingService._internal();

  /// Play Console subscription. Base plans live under this product.
  static const String subscriptionId = 'printer_premium';
  static const String weeklyId = 'days-7-plan';
  static const String monthlyId = 'monthly-plan';
  static const String yearlyId = 'yearly-plan';
  static const List<String> basePlanIds = [weeklyId, monthlyId, yearlyId];

  static const String _proKey = 'is_pro_user';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Completer<void>? _restoreCompleter;
  final Completer<void> _cached = Completer<void>();
  final Completer<void> _ready = Completer<void>();

  bool _initialized = false;
  bool _observing = false;
  bool _syncInProgress = false;
  bool _restoreFoundActive = false;

  bool storeChecked = false;
  bool storeAvailable = false;
  bool isLoadingProducts = false;
  bool isPurchasePending = false;
  bool isPro = false;
  String? lastError;
  String? statusMessage;
  List<ProductDetails> products = const [];

  /// Completes after the saved Pro flag is read.
  Future<void> get whenCached => _cached.future;

  /// Completes after the first store entitlement check, or if the store is down.
  Future<void> get whenReady => _ready.future;

  Future<void> initialize() async {
    if (_initialized) {
      if (!storeAvailable) {
        await refreshFromStore();
      }
      return;
    }
    _initialized = true;

    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }

    final prefs = await SharedPreferences.getInstance();
    isPro = prefs.getBool(_proKey) ?? false;
    _complete(_cached);
    notifyListeners();

    _subscription ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object error) {
        lastError = error.toString();
        isPurchasePending = false;
        _completeRestore();
        notifyListeners();
      },
    );

    try {
      storeAvailable = await _iap.isAvailable();
    } catch (_) {
      storeAvailable = false;
    }
    storeChecked = true;

    try {
      if (storeAvailable) {
        await loadProducts();
        await refreshFromStore();
      } else {
        notifyListeners();
      }
    } finally {
      _complete(_ready);
    }
  }

  Future<void> refreshFromStore() async {
    final available = await _iap.isAvailable().catchError((_) => false);
    storeAvailable = available;
    storeChecked = true;
    if (!available || _syncInProgress) {
      notifyListeners();
      return;
    }

    _syncInProgress = true;
    try {
      final hasActivePro = await _resolveActiveProFromStore();
      await _setPro(hasActivePro);
    } finally {
      _syncInProgress = false;
      notifyListeners();
    }
  }

  Future<bool> _resolveActiveProFromStore() async {
    if (Platform.isAndroid) {
      return _queryActiveProAndroid();
    }

    _restoreFoundActive = false;
    _restoreCompleter = Completer<void>();
    try {
      await _iap.restorePurchases();
    } catch (_) {
      return isPro;
    }
    await _restoreCompleter!.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {},
    );
    return _restoreFoundActive;
  }

  Future<bool> _queryActiveProAndroid() async {
    final addition =
        _iap.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) {
      if (kDebugMode) {
        debugPrint(
          'BillingService: queryPastPurchases failed — keeping current Pro state',
        );
      }
      return isPro;
    }
    return response.pastPurchases.any(_isActiveProPurchase);
  }

  bool _isActiveProPurchase(PurchaseDetails purchase) {
    if (purchase.productID != subscriptionId) return false;
    if (purchase.status == PurchaseStatus.pending) return false;
    if (purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled) {
      return false;
    }
    if (Platform.isAndroid && purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.purchaseState ==
          PurchaseStateWrapper.purchased;
    }
    return purchase.status == PurchaseStatus.purchased ||
        purchase.status == PurchaseStatus.restored;
  }

  Future<void> loadProducts() async {
    if (!storeAvailable) return;
    isLoadingProducts = true;
    lastError = null;
    notifyListeners();
    try {
      final response = await _iap.queryProductDetails({subscriptionId});
      if (response.error != null) {
        lastError = response.error!.message;
        debugPrint('BillingService: product query error: ${response.error!.message}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('BillingService: products not found: ${response.notFoundIDs}');
      }
      products = response.productDetails;
      debugPrint(
        'BillingService: loaded ${products.length} offers for $subscriptionId',
      );
      for (final product in products) {
        if (product is! GooglePlayProductDetails) continue;
        final offer = _offerFor(product);
        debugPrint(
          'BillingService: base plan ${offer?.basePlanId} '
          'price ${priceLabel(product)}',
        );
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('BillingService: product query failed: $e');
    } finally {
      isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// The offer to sell for one base plan, not a free-trial or intro offer.
  ProductDetails? productFor(String basePlanId) {
    final matches = products.where((product) {
      if (product is GooglePlayProductDetails) {
        return _offerFor(product)?.basePlanId == basePlanId;
      }
      return product.id == basePlanId;
    }).toList();
    if (matches.isEmpty) return null;

    GooglePlayProductDetails? basePlan;
    GooglePlayProductDetails? paidOffer;
    for (final product in matches) {
      if (product is! GooglePlayProductDetails) continue;
      final offer = _offerFor(product);
      if (offer == null) {
        if (product.rawPrice > 0) return product;
        continue;
      }
      if (!_hasPaidPhase(offer)) continue;
      if (offer.offerId == null) {
        basePlan = product;
        break;
      }
      paidOffer ??= product;
    }
    if (basePlan != null) return basePlan;
    if (paidOffer != null) return paidOffer;
    for (final product in matches) {
      if (product.rawPrice > 0) return product;
    }
    return matches.first;
  }

  /// Store price the user will actually be charged on renewal.
  String priceLabel(ProductDetails? product) {
    if (product == null) return '';
    final recurring = _recurringPhase(product);
    final raw = recurring != null && recurring.formattedPrice.isNotEmpty
        ? recurring.formattedPrice
        : product.price;
    return raw.replaceAll(RegExp(r'\.00(?!\d)'), '');
  }

  double rawRecurringPrice(ProductDetails product) {
    final recurring = _recurringPhase(product);
    if (recurring != null && recurring.priceAmountMicros > 0) {
      return recurring.priceAmountMicros / 1000000.0;
    }
    return product.rawPrice;
  }

  SubscriptionOfferDetailsWrapper? _offerFor(GooglePlayProductDetails product) {
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index];
  }

  bool _hasPaidPhase(SubscriptionOfferDetailsWrapper offer) {
    return offer.pricingPhases.any((phase) => phase.priceAmountMicros > 0);
  }

  PricingPhaseWrapper? _recurringPhase(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return null;
    final offer = _offerFor(product);
    if (offer == null) return null;
    PricingPhaseWrapper? paid;
    for (final phase in offer.pricingPhases) {
      if (phase.priceAmountMicros > 0) paid = phase;
    }
    return paid;
  }

  Future<void> buy(ProductDetails product) async {
    lastError = null;
    statusMessage = null;
    isPurchasePending = true;
    notifyListeners();
    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      isPurchasePending = false;
      lastError = 'purchase_start_failed';
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    lastError = null;
    statusMessage = null;
    try {
      await refreshFromStore();
      statusMessage = isPro ? 'pro_restored' : 'pro_none_found';
      notifyListeners();
    } catch (e) {
      lastError = 'restore_failed';
      notifyListeners();
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != subscriptionId) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          isPurchasePending = true;
          break;
        case PurchaseStatus.canceled:
          isPurchasePending = false;
          statusMessage = 'purchase_canceled';
          break;
        case PurchaseStatus.error:
          isPurchasePending = false;
          lastError = purchase.error?.message ?? 'purchase_failed';
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          isPurchasePending = false;
          if (_isActiveProPurchase(purchase)) {
            if (_syncInProgress) {
              _restoreFoundActive = true;
            } else {
              await _setPro(true);
            }
          }
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
    _completeRestore();
    notifyListeners();
  }

  Future<void> _setPro(bool value) async {
    if (isPro == value) return;
    isPro = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, value);
    if (kDebugMode) {
      debugPrint(
        value
            ? 'BillingService: Pro active — ads off'
            : 'BillingService: Pro inactive — ads on',
      );
    }
    notifyListeners();
  }

  void _complete(Completer<void> completer) {
    if (!completer.isCompleted) completer.complete();
  }

  void _completeRestore() {
    if (_restoreCompleter != null && !_restoreCompleter!.isCompleted) {
      _restoreCompleter!.complete();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(refreshFromStore());
    }
  }

  @override
  void dispose() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _subscription?.cancel();
    super.dispose();
  }
}
