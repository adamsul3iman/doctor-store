# Fix Guest Checkout RLS Error

## Problem
Guest users (unauthenticated) are getting a PostgrestException when trying to checkout:
```
PostgrestException: new row violates row-level security policy for table "orders"
```

This happens because the RLS policy on the `orders` table likely requires a non-null `user_id`, but guest users have `user.id = null`.

## Solution
Add early returns in all checkout methods to skip database saves for guest users.

## Files to Modify
`lib/features/cart/application/cart_manager.dart`

## Changes Required

### 1. checkoutViaWhatsApp method (around line 540)
Add after line 540:
```dart
// ✅ لا نحفف الطلب للزوار (غير مسجلين)
if (user?.id == null) {
  debugPrint('Guest checkout: skipping database save');
  return;
}
```

### 2. checkoutSingleProductViaWhatsApp method (around line 694)
Add after line 694:
```dart
// ✅ لا نحفف الطلب للزوار (غير مسجلين)
if (user?.id == null) {
  debugPrint('Guest quick checkout: skipping database save');
  return;
}
```

### 3. checkoutCustomItemsViaWhatsApp method (around line 834)
Add after line 834:
```dart
// ✅ لا نحفف الطلب للزوار (غير مسجلين)
if (user?.id == null) {
  debugPrint('Guest custom checkout: skipping database save');
  return;
}
```

## Manual Fix Required
Due to encoding issues with PowerShell, please manually add these checks to the file.
