import XCTest
import StoreKit
import StoreKitTest
final class ProTests: XCTestCase {
 @MainActor func waitFor(_ store: SubscriptionStore, pro: Bool) async throws {
  for _ in 0..<50 {
   await store.refreshEntitlements()
   if store.isPro == pro { return }
   try await Task.sleep(for: .milliseconds(200))
  }
  XCTAssertEqual(store.isPro, pro, store.message ?? "Entitlement update timed out")
 }
 @MainActor func testLifecycle() async throws {
  let url = try XCTUnwrap(Bundle(for: ProTests.self).url(forResource: "NextBirthdayPro", withExtension: "storekit"))
  let session = try SKTestSession(contentsOf: url)
  session.disableDialogs = true
  session.clearTransactions()
  defer { session.clearTransactions() }
  let store = SubscriptionStore()
  await store.start()
  XCTAssertEqual(store.products.count, 2)
  XCTAssertFalse(store.isPro)
  let monthly = try XCTUnwrap(store.products.first { $0.id.hasSuffix("monthly") })
  let purchased = try await session.buyProduct(identifier: monthly.id)
  XCTAssertEqual(purchased.productID, monthly.id)
  await store.refreshEntitlements()
  try await waitFor(store, pro: true)
  let transaction = try XCTUnwrap(session.allTransactions().last { $0.productIdentifier == monthly.id })
  try session.disableAutoRenewForTransaction(identifier: transaction.identifier)
  try session.expireSubscription(productIdentifier: monthly.id)
  await store.refreshEntitlements()
  try await waitFor(store, pro: false)
  let yearly = try XCTUnwrap(store.products.first { $0.id.hasSuffix("yearly") })
  _ = try await session.buyProduct(identifier: yearly.id)
  try await waitFor(store, pro: true)
  let relaunchedStore = SubscriptionStore()
  await relaunchedStore.refreshEntitlements()
  XCTAssertTrue(relaunchedStore.isPro, "Existing verified entitlement must survive relaunch")
  let yearlyTransaction = try XCTUnwrap(session.allTransactions().last { $0.productIdentifier == yearly.id })
  try session.refundTransaction(identifier: yearlyTransaction.identifier)
  try await waitFor(store, pro: false)
 }
}
