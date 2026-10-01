Local subscription entitlement regression test

Run scripts/test-subscriptions.sh (optional first argument: Xcode destination).
A separate signed development test host loads the two production product IDs into Apple's local StoreKit test service. Test-only development entitlements are confined to this host. The test compiles the real SubscriptionStore source directly, without changing the release app or faking isPro.

Scope: initially free, two products, external monthly purchase, verified entitlement, renewal disabled and expiration, external yearly purchase, entitlement after relaunch, refund/revocation. SKTestSession.buyProduct creates local verified transactions. The test polls the same entitlement refresh used when the release app becomes active.

This does NOT test the paywall purchase button, AppStore.sync restore dialog, pending approval, cancellation, or real sandbox billing. These remain device checks. The real app separately loaded both Apple-configured production product IDs and prices on October 1, 2026; the captured paywall is in Release-2.0/Screenshots/. On this machine Product.purchase with Xcode 27 + iOS 26.5 hit Apple's local decoding error for missing original-transaction-id; the iOS 27 attempt prompted for Apple Account login. No purchase-button pass is claimed.
