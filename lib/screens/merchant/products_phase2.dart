// lib/screens/merchant/products_phase2.dart
// PHASE 2 — Upgrade, Renew, Analytics, History screens

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

// ══════════════════════════════════════════════════════════════════════
// UPGRADE STANDARD → PREMIUM PAGE
// ══════════════════════════════════════════════════════════════════════
class UpgradeProductPage extends StatefulWidget {
  final String token;
  final Map<String,dynamic> product;
  const UpgradeProductPage({super.key, required this.token, required this.product});
  @override State<UpgradeProductPage> createState() => _UpgradeProductPageState();
}
class _UpgradeProductPageState extends State<UpgradeProductPage> {
  final _daysC        = TextEditingController(text: "30");
  final _discountCtrl = TextEditingController();
  bool _loading       = false;
  bool _pricingLoaded = false;
  String _msg         = "";
  String _discountMsg = "";
  bool _discountApplied = false;
  double _discountAmt = 0;
  Map<String,dynamic>? _pendingOrder;
  DateTime _fromDate  = DateTime.now();
  late Razorpay _razorpay;

  double _pricePerDay = 0;
  double _gstPct      = 0;

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();
  int    get _days => int.tryParse(_daysC.text.trim()) ?? 0;
  DateTime get _endDate => _fromDate.add(Duration(days: _days));

  double get _base  => _pricePerDay * _days;
  double get _gstAmt => _base * _gstPct / 100;
  double get _subtotal => _base + _gstAmt;
  double get _total => (_subtotal - _discountAmt).clamp(0, double.infinity);

  String _fmtDate(DateTime dt) =>
    "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";
  String _apiDate(DateTime dt) =>
    "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";
  String _fmtAmt(double v) => v == v.truncate() ? "₹${v.toInt()}" : "₹${v.toStringAsFixed(2)}";

  @override void initState() {
    super.initState();
    _daysC.addListener(() => setState((){}));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    _fetchPricing();
  }
  @override void dispose() { _daysC.dispose(); _discountCtrl.dispose(); _razorpay.clear(); super.dispose(); }

  Future<void> _fetchPricing() async {
    try {
      final p = await Api.getProductPricing(widget.token);
      if (mounted) setState(() {
        _pricePerDay = (p["price_per_day"] as num?)?.toDouble() ?? 10;
        _gstPct      = (p["gst_pct"] as num?)?.toDouble() ?? 0;
        _pricingLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() { _pricePerDay = 10; _gstPct = 0; _pricingLoaded = true; });
    }
  }

  Future<void> _applyDiscount() async {
    final code = _discountCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _discountMsg = "Checking…"; _discountApplied = false; _discountAmt = 0; });
    try {
      final res = await Api.validateDiscountCode(widget.token, code);
      final val = (res["value"] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() {
        _discountAmt     = val;
        _discountApplied = true;
        _discountMsg     = res["message"]?.toString() ?? "Discount applied!";
      });
    } catch (e) {
      if (mounted) setState(() {
        _discountMsg = e.toString().replaceAll("Exception: ", "");
        _discountApplied = false; _discountAmt = 0;
      });
    }
  }

  Future<void> _proceed() async {
    if (_days < 1) { setState(() => _msg = "Enter a valid number of days"); return; }
    // Show summary BEFORE API call using Flutter-calculated values
    final confirmed = await _showProductSummaryDialog(
      from: _fromDate, to: _endDate,
      note: "Razorpay opens. Product goes live after admin approval.",
    );
    if (!confirmed || !mounted) return;

    setState(() { _loading = true; _msg = ""; });
    try {
      final order = await Api.upgradeProductOrder(widget.token, _pid, {
        "days":      _days,
        "from_date": _apiDate(_fromDate),
        if (_discountApplied) "discount_code": _discountCtrl.text.trim().toUpperCase(),
      });
      if (!mounted) return;
      final rzpKey     = order["key"]?.toString() ?? "";
      final rzpOrderId = order["order_id"]?.toString() ?? "";
      final amtRupees  = (order["amount"] as num?)?.toDouble() ?? 0;
      final paise      = (amtRupees * 100).toInt();

      if (rzpKey.isNotEmpty && rzpOrderId.isNotEmpty && paise > 0) {
        _pendingOrder = Map<String,dynamic>.from(order);
        _razorpay.open({
          "key":         rzpKey,
          "amount":      paise,
          "name":        "OFFRO",
          "description": "Product Upgrade – $_days Days",
          "order_id":    rzpOrderId,
          "prefill":     {"contact": "", "email": ""},
          "theme":       {"color": "#3E5F55"},
        });
        return;
      } else if (paise == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Upgrade submitted for approval!"),
            backgroundColor: Color(0xFF1a6640)));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) setState(() => _msg = "Payment gateway not configured. Contact support.");
      }
    } catch (e) {
      if (mounted) setState(() => _msg = e.toString().replaceAll("Exception: ", ""));
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Summary dialog — same format as "New Product" ────────────────────
  Future<bool> _showProductSummaryDialog({
    required DateTime from,
    required DateTime to,
    String note = "",
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Product Order Summary",
          style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dRow("Title",  widget.product["title"]?.toString() ?? ""),
          _dRow("Offer",  widget.product["offer_text"]?.toString() ?? ""),
          _dRow("Duration", "$_days Days"),
          _dRow("Period",   "${_fmtDateFull(from)} → ${_fmtDateFull(to)}"),
          _dRow("Rate",     "₹$_pricePerDay/day"),
          const Divider(),
          _dRow("Base",   "₹${_base.toStringAsFixed(1)}"),
          if (_discountApplied && _discountAmt > 0)
            _dRow("Discount", "−₹${_discountAmt.toStringAsFixed(1)}", color: const Color(0xFF1a6640)),
          _dRow("GST (${_gstPct.toStringAsFixed(1)}%)", "₹${_gstAmt.toStringAsFixed(1)}"),
          _dRow("Total",  "₹${_total.toStringAsFixed(1)}", bold: true),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kLight.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(8)),
            child: Text(note,
              style: const TextStyle(fontSize: 12, color: kPrimary))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: kMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Pay ₹${_total.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    return result == true;
  }

  Widget _dRow(String k, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(k, style: const TextStyle(color: kMuted, fontSize: 13))),
      Text(v, style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        color: color ?? (bold ? kPrimary : kText))),
    ]));

  String _fmtDateFull(DateTime dt) {
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}";
  }

  void _onPaySuccess(PaymentSuccessResponse res) async {
    if (_pendingOrder == null || !mounted) return;
    final order = _pendingOrder!; _pendingOrder = null;
    try {
      final result = await Api.verifyUpgradePayment(widget.token, _pid, {
        "order_id":            order["order_id"],
        "razorpay_payment_id": res.paymentId ?? "",
        "razorpay_order_id":   res.orderId   ?? "",
        "razorpay_signature":  res.signature  ?? "",
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result["message"] ?? "Upgraded!"),
          backgroundColor: const Color(0xFF1a6640)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() { _msg = e.toString().replaceAll("Exception: ", ""); _loading = false; });
    }
  }
  void _onPayError(PaymentFailureResponse res) {
    if (mounted) setState(() { _msg = "Payment failed: ${res.message}"; _loading = false; });
  }

  @override Widget build(BuildContext context) {
    final hasDays = _days > 0 && _pricingLoaded;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("Upgrade to Premium", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white, foregroundColor: kText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Benefits banner ──
          _UpgradeInfoCard(),
          const SizedBox(height: 16),

          // ── Duration & Start Date ──
          _CheckoutCard(
            title: "Duration & Start Date",
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                // Days input
                Expanded(child: _DateBox(
                  icon: Icons.calendar_month_rounded,
                  label: "Number of Da…",
                  child: TextField(
                    controller: _daysC, keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kText),
                    decoration: const InputDecoration(
                      border: InputBorder.none, isDense: true,
                      contentPadding: EdgeInsets.zero),
                  ),
                )),
                const SizedBox(width: 12),
                // From date
                GestureDetector(
                  onTap: () async {
                    final p = await showDatePicker(context: context,
                      initialDate: _fromDate, firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
                        child: child!));
                    if (p != null) setState(() => _fromDate = p);
                  },
                  child: _DateBox(
                    icon: Icons.calendar_today_rounded,
                    label: "From Date",
                    child: Text(_fmtDate(_fromDate),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kText)),
                  ),
                ),
              ]),
              if (hasDays) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Active period:", style: TextStyle(color: kMuted, fontSize: 13)),
                    Text("${_fmtDate(_fromDate)} → ${_fmtDate(_endDate)}",
                      style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 8),
                Text("${_fmtAmt(_pricePerDay)}/day × $_days days",
                  style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          // ── Pricing breakdown ──
          if (hasDays)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFe8f4ef),
                borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _PriceRow("Base Price", _fmtAmt(_base)),
                _PriceRow("GST (${_gstPct.toInt()}%)", _fmtAmt(_gstAmt)),
                if (_discountApplied && _discountAmt > 0)
                  _PriceRow("Discount", "− ${_fmtAmt(_discountAmt)}", color: const Color(0xFF1a6640)),
                const Divider(height: 20, color: Color(0xFFB0CFC0)),
                _PriceRow("Total", _fmtAmt(_total), bold: true),
              ]),
            ),
          const SizedBox(height: 14),

          // ── Discount Code ──
          _CheckoutCard(
            title: "Discount Code",
            subtitle: "Have a promo code? Enter it below.",
            child: Row(children: [
              Expanded(child: TextField(
                controller: _discountCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2),
                decoration: InputDecoration(
                  hintText: "e.g. OFFRO20",
                  hintStyle: const TextStyle(color: kMuted, fontWeight: FontWeight.normal, letterSpacing: 0),
                  prefixIcon: const Icon(Icons.local_offer_outlined, color: kMuted, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true, fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                ),
              )),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: kText,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: kBorder))),
                onPressed: _applyDiscount,
                child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          if (_discountMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(_discountMsg,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _discountApplied ? const Color(0xFF1a6640) : Colors.red))),

          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
          const SizedBox(height: 24),

          // ── Proceed to Checkout ──
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (_loading || !_pricingLoaded) ? null : _proceed,
            child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.arrow_forward_rounded, size: 20),
                  SizedBox(width: 10),
                  Text("Proceed to Checkout",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// RENEW PREMIUM PAGE
// ══════════════════════════════════════════════════════════════════════
class RenewProductPage extends StatefulWidget {
  final String token;
  final Map<String,dynamic> product;
  const RenewProductPage({super.key, required this.token, required this.product});
  @override State<RenewProductPage> createState() => _RenewProductPageState();
}
class _RenewProductPageState extends State<RenewProductPage> {
  final _daysC        = TextEditingController(text: "30");
  final _discountCtrl = TextEditingController();
  bool _loading       = false;
  bool _pricingLoaded = false;
  String _msg         = "";
  String _discountMsg = "";
  bool _discountApplied = false;
  double _discountAmt = 0;
  Map<String,dynamic>? _pendingOrder;
  late Razorpay _razorpay;

  double _pricePerDay = 0;
  double _gstPct      = 0;

  String get _pid  => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();
  int    get _days => int.tryParse(_daysC.text.trim()) ?? 0;

  double get _base     => _pricePerDay * _days;
  double get _gstAmt   => _base * _gstPct / 100;
  double get _subtotal => _base + _gstAmt;
  double get _total    => (_subtotal - _discountAmt).clamp(0, double.infinity);

  String _fmtDate(DateTime dt) =>
    "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";
  String _fmtAmt(double v) => v == v.truncate() ? "₹${v.toInt()}" : "₹${v.toStringAsFixed(2)}";

  // Parses ISO "2026-07-04" OR "04 Jul 2026" OR "04-07-2026" → DateTime
  DateTime? _parseAnyDate(String raw) {
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw); } catch (_) {}
    try {
      final parts = raw.trim().split(RegExp(r'[\s\-/]+'));
      if (parts.length >= 3) {
        const months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                        "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
        final mon = months[parts[1].toLowerCase().substring(0, 3)];
        if (mon != null) {
          final day = int.tryParse(parts[0]);
          final yr  = int.tryParse(parts[2]);
          if (day != null && yr != null) return DateTime(yr, mon, day);
        }
      }
    } catch (_) {}
    return null;
  }

  String get _curEnd {
    final raw = widget.product["end_date"]?.toString() ?? "";
    if (raw.isEmpty) return "—";
    final dt = _parseAnyDate(raw);
    return dt != null ? _fmtDate(dt) : raw;
  }

  DateTime get _renewFrom {
    final raw = widget.product["end_date"]?.toString() ?? "";
    if (raw.isEmpty) return DateTime.now();
    final dt = _parseAnyDate(raw);
    if (dt == null) return DateTime.now();
    // If current listing hasn't expired yet, renewal starts the day AFTER
    return dt.isAfter(DateTime.now()) ? dt.add(const Duration(days: 1)) : DateTime.now();
  }

  DateTime get _newEnd => _renewFrom.add(Duration(days: _days));

  @override void initState() {
    super.initState();
    _daysC.addListener(() => setState((){}));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    _fetchPricing();
  }
  @override void dispose() { _daysC.dispose(); _discountCtrl.dispose(); _razorpay.clear(); super.dispose(); }

  Future<void> _fetchPricing() async {
    try {
      final p = await Api.getProductPricing(widget.token);
      if (mounted) setState(() {
        _pricePerDay = (p["price_per_day"] as num?)?.toDouble() ?? 10;
        _gstPct      = (p["gst_pct"] as num?)?.toDouble() ?? 0;
        _pricingLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() { _pricePerDay = 10; _gstPct = 0; _pricingLoaded = true; });
    }
  }

  Future<void> _applyDiscount() async {
    final code = _discountCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _discountMsg = "Checking…"; _discountApplied = false; _discountAmt = 0; });
    try {
      final res = await Api.validateDiscountCode(widget.token, code);
      final val = (res["value"] as num?)?.toDouble() ?? 0;
      if (mounted) setState(() {
        _discountAmt     = val;
        _discountApplied = true;
        _discountMsg     = res["message"]?.toString() ?? "Discount applied!";
      });
    } catch (e) {
      if (mounted) setState(() {
        _discountMsg = e.toString().replaceAll("Exception: ", "");
        _discountApplied = false; _discountAmt = 0;
      });
    }
  }

  Future<void> _proceed() async {
    if (_days < 1) { setState(() => _msg = "Enter a valid number of days"); return; }
    // Show summary BEFORE API call using Flutter-calculated values
    final confirmed = await _showProductSummaryDialog(
      from: _renewFrom, to: _newEnd,
      note: "Razorpay opens. Listing renewed after payment.",
    );
    if (!confirmed || !mounted) return;

    setState(() { _loading = true; _msg = ""; });
    try {
      final order = await Api.renewProductOrder(widget.token, _pid, {
        "days": _days,
        if (_discountApplied) "discount_code": _discountCtrl.text.trim().toUpperCase(),
      });
      if (!mounted) return;
      final rzpKey     = order["key"]?.toString() ?? "";
      final rzpOrderId = order["order_id"]?.toString() ?? "";
      final amtRupees  = (order["amount"] as num?)?.toDouble() ?? 0;
      final paise      = (amtRupees * 100).toInt();

      if (rzpKey.isNotEmpty && rzpOrderId.isNotEmpty && paise > 0) {
        _pendingOrder = Map<String,dynamic>.from(order);
        _razorpay.open({
          "key":         rzpKey,
          "amount":      paise,
          "name":        "OFFRO",
          "description": "Premium Renewal – $_days Days",
          "order_id":    rzpOrderId,
          "prefill":     {"contact": "", "email": ""},
          "theme":       {"color": "#3E5F55"},
        });
        return;
      } else if (paise == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Renewed successfully!"),
            backgroundColor: Color(0xFF1a6640)));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) setState(() => _msg = "Payment gateway not configured. Contact support.");
      }
    } catch(e) {
      if (mounted) setState(() => _msg = e.toString().replaceAll("Exception: ", ""));
    }
    if (mounted) setState(() => _loading = false);
  }

  // ── Summary dialog — same format as "New Product" ────────────────────
  Future<bool> _showProductSummaryDialog({
    required DateTime from,
    required DateTime to,
    String note = "",
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Product Order Summary",
          style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dRow("Title",  widget.product["title"]?.toString() ?? ""),
          _dRow("Offer",  widget.product["offer_text"]?.toString() ?? ""),
          _dRow("Duration", "$_days Days"),
          _dRow("Period",   "${_fmtDateFull(from)} → ${_fmtDateFull(to)}"),
          _dRow("Rate",     "₹$_pricePerDay/day"),
          const Divider(),
          _dRow("Base",   "₹${_base.toStringAsFixed(1)}"),
          if (_discountApplied && _discountAmt > 0)
            _dRow("Discount", "−₹${_discountAmt.toStringAsFixed(1)}", color: const Color(0xFF1a6640)),
          _dRow("GST (${_gstPct.toStringAsFixed(1)}%)", "₹${_gstAmt.toStringAsFixed(1)}"),
          _dRow("Total",  "₹${_total.toStringAsFixed(1)}", bold: true),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kLight.withValues(alpha: .4),
              borderRadius: BorderRadius.circular(8)),
            child: Text(note,
              style: const TextStyle(fontSize: 12, color: kPrimary))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: kMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            onPressed: () => Navigator.pop(context, true),
            child: Text("Pay ₹${_total.toStringAsFixed(1)}",
              style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    return result == true;
  }

  Widget _dRow(String k, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(k, style: const TextStyle(color: kMuted, fontSize: 13))),
      Text(v, style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        color: color ?? (bold ? kPrimary : kText))),
    ]));

  String _fmtDateFull(DateTime dt) {
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}";
  }

  // keep for back-compat (unused now but referenced by old summary path)
  Future<bool?> _showSummary(Map order, {required bool free}) =>
    showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text("Renew Premium Listing", style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SummaryRow("Extend by",  "$_days days"),
        _SummaryRow("New End Date", order["new_end_date"]?.toString() ?? ""),
        if (!free) ...[
          const Divider(),
          _SummaryRow("Base Price",   "₹${order['base_price']}"),
          _SummaryRow("GST (${order['gst_percent']}%)", "₹${order['gst_amount']}"),
          _SummaryRow("Total",        "₹${order['total']}", bold: true),
        ],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
          onPressed: () => Navigator.pop(context, true),
          child: Text(free ? "Renew Now" : "Pay ₹${order['total']}", style: const TextStyle(color: Colors.white))),
      ],
    ));

  void _onPaySuccess(PaymentSuccessResponse res) async {
    if (_pendingOrder == null || !mounted) return;
    final order = _pendingOrder!; _pendingOrder = null;
    try {
      final result = await Api.verifyRenewalPayment(widget.token, _pid, {
        "order_id":            order["order_id"],
        "razorpay_payment_id": res.paymentId ?? "",
        "razorpay_order_id":   res.orderId   ?? "",
        "razorpay_signature":  res.signature  ?? "",
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result["message"] ?? "Renewed!"),
          backgroundColor: const Color(0xFF1a6640)));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() { _msg = e.toString().replaceAll("Exception: ", ""); _loading = false; });
    }
  }
  void _onPayError(PaymentFailureResponse res) {
    if (mounted) setState(() { _msg = "Payment failed: ${res.message}"; _loading = false; });
  }

  @override Widget build(BuildContext context) {
    final hasDays = _days > 0 && _pricingLoaded;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text("Renew Premium", style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white, foregroundColor: kText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Current listing info ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.shade300)),
            child: Row(children: [
              const Icon(Icons.autorenew_rounded, color: Color(0xFF856404), size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.product["title"]?.toString() ?? "Product",
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kText)),
                Text("Current listing ends: $_curEnd",
                  style: const TextStyle(color: kMuted, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Duration & Start Date ──
          _CheckoutCard(
            title: "Duration & Extension",
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DateBox(
                icon: Icons.calendar_month_rounded,
                label: "Number of Days",
                child: TextField(
                  controller: _daysC, keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: kText),
                  decoration: const InputDecoration(
                    border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ),
              if (hasDays) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Active period:", style: TextStyle(color: kMuted, fontSize: 13)),
                    Text("${_fmtDate(_renewFrom)} → ${_fmtDate(_newEnd)}",
                      style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 8),
                Text("${_fmtAmt(_pricePerDay)}/day × $_days days",
                  style: const TextStyle(color: kMuted, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 14),

          // ── Pricing breakdown ──
          if (hasDays)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFe8f4ef),
                borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _PriceRow("Base Price", _fmtAmt(_base)),
                _PriceRow("GST (${_gstPct.toInt()}%)", _fmtAmt(_gstAmt)),
                if (_discountApplied && _discountAmt > 0)
                  _PriceRow("Discount", "− ${_fmtAmt(_discountAmt)}", color: const Color(0xFF1a6640)),
                const Divider(height: 20, color: Color(0xFFB0CFC0)),
                _PriceRow("Total", _fmtAmt(_total), bold: true),
              ]),
            ),
          const SizedBox(height: 14),

          // ── Discount Code ──
          _CheckoutCard(
            title: "Discount Code",
            subtitle: "Have a promo code? Enter it below.",
            child: Row(children: [
              Expanded(child: TextField(
                controller: _discountCtrl,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 1.2),
                decoration: InputDecoration(
                  hintText: "e.g. OFFRO20",
                  hintStyle: const TextStyle(color: kMuted, fontWeight: FontWeight.normal, letterSpacing: 0),
                  prefixIcon: const Icon(Icons.local_offer_outlined, color: kMuted, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true, fillColor: kBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                ),
              )),
              const SizedBox(width: 10),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, foregroundColor: kText,
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: kBorder))),
                onPressed: _applyDiscount,
                child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          if (_discountMsg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(_discountMsg,
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _discountApplied ? const Color(0xFF1a6640) : Colors.red))),

          if (_msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
          const SizedBox(height: 24),

          // ── Proceed to Checkout ──
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kText,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: (_loading || !_pricingLoaded) ? null : _proceed,
            child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.arrow_forward_rounded, size: 20),
                  SizedBox(width: 10),
                  Text("Proceed to Checkout",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ]),
          )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// PRODUCT ANALYTICS PAGE
// ══════════════════════════════════════════════════════════════════════
class ProductAnalyticsPage extends StatefulWidget {
  final String token;
  final Map<String,dynamic> product;
  const ProductAnalyticsPage({super.key, required this.token, required this.product});
  @override State<ProductAnalyticsPage> createState() => _ProductAnalyticsPageState();
}
class _ProductAnalyticsPageState extends State<ProductAnalyticsPage> {
  Map<String,dynamic> _data = {};
  bool _loading = true;

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await Api.getProductAnalytics(widget.token, _pid);
    if (mounted) setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      title: const Text("Product Analytics", style: TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white, foregroundColor: kText,
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: kPrimary))
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          // Product info card
          Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.local_activity_rounded, color: kPrimary, size: 36),
              title: Text(widget.product["title"]?.toString() ?? "Product",
                style: const TextStyle(fontWeight: FontWeight.bold, color: kText)),
              subtitle: const Text("Premium Listing Analytics",
                style: TextStyle(color: kMuted, fontSize: 12)),
            )),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _AnalyticsStat("👁️ Views",  "${_data['views'] ?? 0}", kPrimary)),
            const SizedBox(width: 12),
            Expanded(child: _AnalyticsStat("🔗 Shares", "${_data['shares'] ?? 0}", const Color(0xFF2563EB))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _AnalyticsStat("🛒 Opens", "${_data['opens'] ?? 0}", const Color(0xFF059669))),
            const SizedBox(width: 12),
            Expanded(child: _AnalyticsStat("📅 Last Seen",
              _data['last_viewed']?.toString().isNotEmpty == true
                ? _data['last_viewed'].toString().substring(0, 10) : "—",
              const Color(0xFF7C3AED))),
          ]),
          const SizedBox(height: 20),
          _ConversionBar(_data),
        ])),
  );
}

class _AnalyticsStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AnalyticsStat(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: .25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800)),
    ]),
  );
}

class _ConversionBar extends StatelessWidget {
  final Map<String,dynamic> data;
  const _ConversionBar(this.data);
  @override Widget build(BuildContext context) {
    final views  = (data['views']  as num?)?.toDouble() ?? 0;
    final opens  = (data['opens']  as num?)?.toDouble() ?? 0;
    final pct = views > 0 ? (opens / views * 100).clamp(0, 100).toStringAsFixed(1) : "0";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Conversion Rate", style: TextStyle(fontWeight: FontWeight.w700, color: kText)),
        const SizedBox(height: 4),
        Text("$pct% of viewers tapped Open",
          style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: views > 0 ? opens / views : 0,
          backgroundColor: kLight,
          color: kPrimary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// PRODUCT HISTORY PAGE
// ══════════════════════════════════════════════════════════════════════
class ProductHistoryPage extends StatefulWidget {
  final String token;
  final Map<String,dynamic> product;
  const ProductHistoryPage({super.key, required this.token, required this.product});
  @override State<ProductHistoryPage> createState() => _ProductHistoryPageState();
}
class _ProductHistoryPageState extends State<ProductHistoryPage> {
  List<Map<String,dynamic>> _events = [];
  bool _loading = true;

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    _events = await Api.getProductHistory(widget.token, _pid);
    if (mounted) setState(() => _loading = false);
  }

  IconData _icon(String ev) {
    if (ev.contains("Create"))   return Icons.add_circle_rounded;
    if (ev.contains("Activat"))  return Icons.toggle_on_rounded;
    if (ev.contains("Deactiv"))  return Icons.toggle_off_rounded;
    if (ev.contains("Upgrad"))   return Icons.arrow_upward_rounded;
    if (ev.contains("Renew"))    return Icons.autorenew_rounded;
    if (ev.contains("Extend"))   return Icons.calendar_month_rounded;
    return Icons.history_rounded;
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      title: const Text("Activity History", style: TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white, foregroundColor: kText,
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: kPrimary))
      : _events.isEmpty
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.history_rounded, size: 64, color: kAccent),
            SizedBox(height: 12),
            Text("No activity yet", style: TextStyle(color: kMuted, fontSize: 16)),
          ]))
        : ListView.separated(
            padding: const EdgeInsets.all(14),
            itemCount: _events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = _events[i];
              final ts = e["created_at"]?.toString() ?? "";
              return Card(elevation: 1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: kPrimary.withValues(alpha: .12),
                    child: Icon(_icon(e["event"]?.toString() ?? ""), color: kPrimary, size: 20)),
                  title: Text(e["event"]?.toString() ?? "",
                    style: const TextStyle(fontWeight: FontWeight.w700, color: kText, fontSize: 14)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ((e["details"]?.toString() ?? "").isNotEmpty)
                      Text(e["details"].toString(),
                        style: const TextStyle(color: kMuted, fontSize: 12)),
                    Text(ts.length >= 10 ? ts.substring(0, 10) : ts,
                      style: const TextStyle(color: kAccent, fontSize: 11)),
                  ]),
                ));
            }),
  );
}

// ══════════════════════════════════════════════════════════════════════
// EXPIRY WARNINGS BANNER WIDGET (used in MerchantProductsPage)
// ══════════════════════════════════════════════════════════════════════
class ExpiryWarningBanner extends StatelessWidget {
  final List<Map<String,dynamic>> expiring;
  final VoidCallback onRenewTap;
  const ExpiryWarningBanner({super.key, required this.expiring, required this.onRenewTap});
  @override Widget build(BuildContext context) {
    if (expiring.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(
          "${expiring.length} product${expiring.length > 1 ? 's' : ''} expiring soon — tap to renew",
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 13))),
        TextButton(
          onPressed: onRenewTap,
          child: const Text("Renew", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SIMILAR PRODUCTS WIDGET (public — used inside ProductDetailsPage)
// ══════════════════════════════════════════════════════════════════════
class SimilarProductsSection extends StatefulWidget {
  final String productId;
  final String token;
  const SimilarProductsSection({super.key, required this.productId, required this.token});
  @override State<SimilarProductsSection> createState() => _SimilarProductsSectionState();
}
class _SimilarProductsSectionState extends State<SimilarProductsSection> {
  List<Map<String,dynamic>> _items = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final list = await Api.getSimilarProducts(widget.productId);
    if (mounted) setState(() { _items = list; _loading = false; });
  }
  @override Widget build(BuildContext context) {
    if (_loading) return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(color: kPrimary)));
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text("Similar Products",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kText))),
      SizedBox(height: 130, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final p = _items[i];
          final logo = p["logo_url"]?.toString() ?? "";
          return GestureDetector(
            child: Container(
              width: 110, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder)),
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 60, width: double.infinity,
                  decoration: BoxDecoration(
                    color: kLight,
                    borderRadius: BorderRadius.circular(8),
                    image: logo.startsWith("http")
                      ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                      : null,
                  ),
                  child: logo.startsWith("http") ? null
                    : const Center(child: Icon(Icons.local_activity, color: kPrimary, size: 24))),
                const SizedBox(height: 6),
                Text(p["title"]?.toString() ?? "", maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText)),
              ]),
            ),
          );
        },
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
// MORE FROM STORE WIDGET
// ══════════════════════════════════════════════════════════════════════
class MoreFromStoreSection extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String currentProductId;
  const MoreFromStoreSection({super.key, required this.storeId,
    required this.storeName, required this.currentProductId});
  @override State<MoreFromStoreSection> createState() => _MoreFromStoreSectionState();
}
class _MoreFromStoreSectionState extends State<MoreFromStoreSection> {
  List<Map<String,dynamic>> _items = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final list = await Api.getMoreFromStore(widget.storeId);
    if (mounted) setState(() {
      _items = list.where((p) =>
        (p["id"]?.toString() ?? "") != widget.currentProductId).toList();
      _loading = false;
    });
  }
  @override Widget build(BuildContext context) {
    if (_loading || _items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text("More from ${widget.storeName.isNotEmpty ? widget.storeName : 'this store'}",
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kText))),
      SizedBox(height: 130, child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _items.take(10).length,
        itemBuilder: (_, i) {
          final p = _items[i];
          final logo = p["logo_url"]?.toString() ?? "";
          return Container(
            width: 110, margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder)),
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 60, width: double.infinity,
                decoration: BoxDecoration(color: kLight,
                  borderRadius: BorderRadius.circular(8),
                  image: logo.startsWith("http")
                    ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                    : null),
                child: logo.startsWith("http") ? null
                  : const Center(child: Icon(Icons.local_activity, color: kPrimary, size: 24))),
              const SizedBox(height: 6),
              Text(p["title"]?.toString() ?? "", maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kText)),
            ]),
          );
        },
      )),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════
// CHECKOUT UI HELPERS
// ══════════════════════════════════════════════════════════════════════

/// White card with title + optional subtitle + body content
class _CheckoutCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _CheckoutCard({required this.title, this.subtitle, required this.child});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kText)),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle!, style: const TextStyle(color: kMuted, fontSize: 12)),
      ],
      const SizedBox(height: 14),
      child,
    ]),
  );
}

/// Date / number input box with icon and label
class _DateBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _DateBox({required this.icon, required this.label, required this.child});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      border: Border.all(color: kBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: kMuted),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      child,
    ]),
  );
}

/// A single pricing row in the green breakdown card
class _PriceRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _PriceRow(this.label, this.value, {this.bold = false, this.color});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        color: color ?? (bold ? kText : kMuted),
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      Text(value, style: TextStyle(
        color: color ?? (bold ? kText : kText),
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════
// SHARED HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════
class _UpgradeInfoCard extends StatelessWidget {
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF3E5F55), Color(0xFF1a6640)]),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Row(children: [
        Icon(Icons.star_rounded, color: Colors.amber, size: 20),
        SizedBox(width: 8),
        Text("Premium Listing Benefits", style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
      ]),
      SizedBox(height: 10),
      _Benefit("🔍 Featured in Discover Products"),
      _Benefit("📊 Real-time view & share analytics"),
      _Benefit("🔔 Expiry reminders"),
      _Benefit("⭐ Priority placement in search"),
    ]),
  );
}

class _Benefit extends StatelessWidget {
  final String text;
  const _Benefit(this.text);
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)));
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override Widget build(BuildContext context) =>
    Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: kText, fontSize: 15));
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _SummaryRow(this.label, this.value, {this.bold = false});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: kMuted, fontSize: 13)),
      Text(value, style: TextStyle(
        color: kText, fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
    ]),
  );
}
