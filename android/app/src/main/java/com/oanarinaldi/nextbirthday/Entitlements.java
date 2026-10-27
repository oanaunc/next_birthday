package com.oanarinaldi.nextbirthday;

import android.content.Context;
import android.content.SharedPreferences;

/** Kept outside editable checklist data and excluded from Android backup. */
final class Entitlements {
  private final SharedPreferences prefs;

  Entitlements(Context context) {
    prefs = context.getSharedPreferences("play_entitlement", Context.MODE_PRIVATE);
  }

  void entitlement(String plan) {
    prefs.edit().putString("plan", plan).putLong("checkedAt", System.currentTimeMillis()).apply();
  }

  void reviewAccess() {
    prefs.edit().putLong("reviewUntil", System.currentTimeMillis() + 30L * 86400000).apply();
  }

  String plan() {
    if (prefs.getLong("reviewUntil", 0) > System.currentTimeMillis()) return "review";
    long age = System.currentTimeMillis() - prefs.getLong("checkedAt", 0);
    return age >= 0 && age < 7L * 86400000 ? prefs.getString("plan", "") : "";
  }

  boolean isPro() {
    return !plan().isEmpty();
  }
}
