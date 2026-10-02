// lib/core/widgets/manual_location_sheet.dart
// OFFRO — Shared mandatory State + City picker.
//
// Shown whenever a User's CURRENT location cannot be established via GPS
// (app-level permission denied, device Location Services off, or GPS/
// reverse-geocode failed) and a location is required to continue. Never
// assigns a default/guessed city (no "Ballari") — the person must
// explicitly pick both State and City.
//
// Originally lived as a private method on _LoginState in
// screens/auth/login_screen.dart (Round 8's "no account city" fallback).
// Extracted to this shared, dependency-neutral file — rather than kept
// private there, or moved into screens/loading/location_loading_screen.dart
// — so BOTH screens can call the exact same sheet without creating a
// circular import: login_screen.dart already imports
// location_loading_screen.dart, so the reverse import is not possible.
// This mirrors the same fix used earlier for kIndiaStates/kIndiaCities
// (see core/constants/india_locations.dart).

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../constants/india_locations.dart';

/// Returns {'state': ..., 'city': ...} once both are picked and the person
/// taps "Save & Continue", or null if they dismiss the sheet without
/// picking both.
Future<Map<String, String>?> requireManualCityState(BuildContext context) {
  String? selState;
  String? selCity;
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
      return Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("We couldn't detect your location",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kPrimary)),
          const SizedBox(height: 6),
          const Text('Please select your State and City to continue.',
            style: TextStyle(fontSize: 12.5, color: kMuted)),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: selState,
            items: kIndiaStates.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setSheetState(() { selState = v; selCity = null; }),
            decoration: InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            hint: const Text('Select state'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: selCity,
            items: (selState == null ? const <String>[] : (kIndiaCities[selState] ?? const <String>[]))
                .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setSheetState(() => selCity = v),
            decoration: InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            hint: const Text('Select city'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (selState != null && selCity != null)
                  ? () => Navigator.pop(ctx, {'state': selState!, 'city': selCity!})
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFc8d8d2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      );
    }),
  );
}
