// lib/core/utils/store_hours.dart
//
// Single source of truth for "is this store open right now" logic.
//
// ROOT CAUSE this file fixes (found 2026-08-12 by direct code inspection,
// not a guess):
//   - store_about_section.dart HARD-CODED the green dot + "Open" text —
//     it never actually compared open/close time to the current time at all.
//   - store_header.dart DID compute a real status, but only checked
//     `now < closeMins`, never checking `now >= openMins`. That is wrong
//     for a store that hasn't opened yet today (e.g. hours 9AM-9PM, current
//     time 3AM would be wrongly reported "Open").
// Because these two widgets used two different (and both incomplete/fake)
// implementations, the same store could show "Closed" in one place and
// "Open" in another on the very same page. This file gives both a single,
// correct implementation so they can never disagree again.
import 'package:flutter/material.dart';

class StoreHoursStatus {
  final bool isOpen;
  final String subLabel; // e.g. "Closes 4:00 PM" or "Opens 2:30 AM"
  const StoreHoursStatus(this.isOpen, this.subLabel);
}

String _fmt(int h, int m) {
  final suffix = h >= 12 ? 'PM' : 'AM';
  final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
  final mStr = m > 0 ? ':${m.toString().padLeft(2, '0')}' : '';
  return '$h12$mStr $suffix';
}

/// Returns null when hours aren't configured (caller should hide the badge).
StoreHoursStatus? computeStoreOpenStatus(String openTimeRaw, String closeTimeRaw) {
  final ot = openTimeRaw.length > 5 ? openTimeRaw.substring(0, 5) : openTimeRaw;
  final ct = closeTimeRaw.length > 5 ? closeTimeRaw.substring(0, 5) : closeTimeRaw;
  if (ct.isEmpty ||
      (ot == '00:00' && ct == '00:00') ||
      (ot.isEmpty && ct == '00:00') ||
      ct == '00:00:00') {
    return null;
  }
  try {
    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;

    final cParts = ct.split(':');
    final cH = int.parse(cParts[0]);
    final cM = cParts.length > 1 ? int.parse(cParts[1]) : 0;
    final closeMins = cH * 60 + cM;

    int openMins = -1;
    if (ot.isNotEmpty) {
      final oParts = ot.split(':');
      final oH = int.parse(oParts[0]);
      final oM = oParts.length > 1 ? int.parse(oParts[1]) : 0;
      openMins = oH * 60 + oM;
    }

    bool isOpen;
    if (openMins < 0) {
      // No open_time configured — fall back to legacy "before close" check.
      isOpen = nowMins < closeMins;
    } else if (openMins <= closeMins) {
      // Normal same-day window, e.g. 09:00 - 21:00.
      isOpen = nowMins >= openMins && nowMins < closeMins;
    } else {
      // Overnight window, e.g. 22:00 - 02:00.
      isOpen = nowMins >= openMins || nowMins < closeMins;
    }

    String sub;
    if (isOpen) {
      sub = 'Closes ${_fmt(cH, cM)}';
    } else if (openMins >= 0) {
      sub = 'Opens ${_fmt(openMins ~/ 60, openMins % 60)}';
    } else {
      sub = '';
    }

    return StoreHoursStatus(isOpen, sub);
  } catch (_) {
    return null;
  }
}
