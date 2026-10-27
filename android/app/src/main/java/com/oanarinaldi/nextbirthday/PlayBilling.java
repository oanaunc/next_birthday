package com.oanarinaldi.nextbirthday;

import android.app.Activity;
import com.android.billingclient.api.*;
import java.util.*;

/** One BillingClient connection, actual Play prices/offers, pending-safe grants and restoration. */
final class PlayBilling implements PurchasesUpdatedListener {
  static final String PREFIX = "nextbirthday.pro.";
  static final Set<String> IDS = Set.of(PREFIX + "monthly", PREFIX + "yearly");

  record Plan(
      String id,
      String title,
      String price,
      String note,
      String offer,
      ProductDetails details,
      boolean trial) {}

  final Activity activity;
  final Entitlements prefs;
  final Runnable changed;
  final java.util.function.Consumer<String> error;
  final BillingClient client;
  final Map<String, Plan> plans = new LinkedHashMap<>();
  boolean loading = true, busy = false;
  private int refreshGeneration = 0;

  PlayBilling(
      Activity a, Entitlements p, Runnable changed, java.util.function.Consumer<String> error) {
    activity = a;
    prefs = p;
    this.changed = changed;
    this.error = error;
    client =
        BillingClient.newBuilder(a)
            .setListener(this)
            .enablePendingPurchases(
                PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection()
            .build();
  }

  void start() {
    if (client.isReady()) {
      load();
      refresh(false);
      return;
    }
    client.startConnection(
        new BillingClientStateListener() {
          public void onBillingSetupFinished(BillingResult r) {
            loading = false;
            if (ok(r)) {
              load();
              refresh(false);
            } else changed.run();
          }

          public void onBillingServiceDisconnected() {
            loading = false;
            changed.run();
          }
        });
  }

  void load() {
    loading = true;
    plans.clear();
    queryProducts(BillingClient.ProductType.SUBS, List.of(PREFIX + "monthly", PREFIX + "yearly"), () -> { loading = false; changed.run(); });
  }

  private void queryProducts(String type, List<String> ids, Runnable done) {
    List<QueryProductDetailsParams.Product> products = new ArrayList<>();
    for (String id : ids)
      products.add(
          QueryProductDetailsParams.Product.newBuilder()
              .setProductId(id)
              .setProductType(type)
              .build());
    client.queryProductDetailsAsync(
        QueryProductDetailsParams.newBuilder().setProductList(products).build(),
        (r, result) -> {
          if (ok(r))
            for (ProductDetails d : result.getProductDetailsList()) {
              String id = d.getProductId(),
                  title =
                      id.endsWith("yearly")
                          ? "Yearly"
                          : id.endsWith("monthly") ? "Monthly" : "Lifetime";
              if (type.equals(BillingClient.ProductType.INAPP)) {
                var offer = d.getOneTimePurchaseOfferDetails();
                if (offer != null)
                  plans.put(
                      id,
                      new Plan(
                          id,
                          title,
                          offer.getFormattedPrice(),
                          "Pay once, yours forever",
                          null,
                          d,
                          false));
              } else {
                var offers = d.getSubscriptionOfferDetails();
                if (offers == null || offers.isEmpty()) continue;
                // ProductDetails only returns offers this Play account is eligible to purchase.
                ProductDetails.SubscriptionOfferDetails offer =
                    offers.stream()
                        .filter(
                            o ->
                                o.getPricingPhases().getPricingPhaseList().stream()
                                    .anyMatch(p -> p.getPriceAmountMicros() == 0))
                        .findFirst()
                        .orElse(offers.get(0));
                var phases = offer.getPricingPhases().getPricingPhaseList();
                var recurring = phases.get(phases.size() - 1);
                boolean trial = phases.get(0).getPriceAmountMicros() == 0;
                String period = recurring.getBillingPeriod(),
                    suffix =
                        period.equals("P1Y")
                            ? " / year"
                            : period.equals("P1M") ? " / month" : " / " + period;
                String note =
                    trial
                        ? trialText(phases.get(0).getBillingPeriod())
                            + ", then "
                            + recurring.getFormattedPrice()
                            + suffix
                        : "Cancel anytime";
                plans.put(
                    id,
                    new Plan(
                        id,
                        title,
                        recurring.getFormattedPrice() + suffix,
                        note,
                        offer.getOfferToken(),
                        d,
                        trial));
              }
            }
          done.run();
        });
  }

  static String trialText(String period) {
    return switch (period) {
      case "P7D", "P1W" -> "7 days free";
      case "P1M" -> "1 month free";
      case "P3D" -> "3 days free";
      default -> "Free trial (" + period + ")";
    };
  }

  void buy(String id) {
    Plan plan = plans.get(id);
    if (plan == null || busy) return;
    busy = true;
    changed.run();
    var item =
        BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(plan.details());
    if (plan.offer() != null) item.setOfferToken(plan.offer());
    BillingResult r =
        client.launchBillingFlow(
            activity,
            BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(List.of(item.build()))
                .build());
    if (!ok(r)) {
      busy = false;
      error.accept("Google Play couldn't open the purchase. Please try again.");
      changed.run();
    }
  }

  public void onPurchasesUpdated(BillingResult r, List<Purchase> purchases) {
    busy = false;
    if (ok(r) && purchases != null) {
      if (purchases.stream().anyMatch(p -> p.getPurchaseState() == Purchase.PurchaseState.PENDING))
        error.accept("Your purchase is pending. Pro unlocks when Google Play confirms payment.");
      for (Purchase p : purchases) acknowledge(p);
      refresh(false);
    } else if (r.getResponseCode() == BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED)
      refresh(true);
    else if (r.getResponseCode() != BillingClient.BillingResponseCode.USER_CANCELED)
      error.accept("The purchase didn't finish. Please try again in Google Play.");
    changed.run();
  }

  static boolean eligible(Purchase p) {
    return p.getPurchaseState() == Purchase.PurchaseState.PURCHASED
        && p.getProducts().stream().anyMatch(IDS::contains);
  }

  private void acknowledge(Purchase p) {
    if (!eligible(p) || p.isAcknowledged()) return;
    client.acknowledgePurchase(
        AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.getPurchaseToken()).build(),
        r -> {
          if (ok(r)) refresh(false);
          else
            error.accept(
                "Google Play is still confirming your purchase. Use Restore purchases to retry.");
        });
  }

  void refresh(boolean announce) {
    if (!client.isReady()) {
      if (announce) start();
      return;
    }
    int generation = ++refreshGeneration;
    List<Purchase> owned = new ArrayList<>();
    int[] remaining = {1};
    boolean[] success = {true};
    for (String type : List.of(BillingClient.ProductType.SUBS)) {
      client.queryPurchasesAsync(
          QueryPurchasesParams.newBuilder().setProductType(type).build(),
          (r, list) -> {
            if (generation != refreshGeneration) return;
            if (!ok(r)) success[0] = false;
            else {
              owned.addAll(list);
              for (Purchase p : list) acknowledge(p);
            }
            if (--remaining[0] == 0) {
              if (success[0]) {
                String active =
                    owned.stream()
                        .filter(PlayBilling::eligible)
                        .flatMap(p -> p.getProducts().stream())
                        .filter(IDS::contains)
                        .sorted(
                            Comparator.comparingInt(
                                id -> id.endsWith("lifetime") ? 0 : id.endsWith("yearly") ? 1 : 2))
                        .findFirst()
                        .orElse("");
                prefs.entitlement(active);

                if (announce)
                  error.accept(
                      active.isEmpty()
                          ? "No active Pro purchases were found for this Google Play account."
                          : "Your Pro purchases are restored.");
              } else if (announce)
                error.accept(
                    "Couldn't restore purchases. Check your Google Play connection and try again.");
              changed.run();
            }
          });
    }
  }

  static boolean ok(BillingResult r) {
    return r.getResponseCode() == BillingClient.BillingResponseCode.OK;
  }

  void close() {
    client.endConnection();
  }
}
