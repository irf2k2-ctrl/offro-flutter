// lib/screens/merchant/products_phase2.dart
// PHASE 2 — Renew, Analytics, History screens

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/design/offro_tokens.dart' show OffroColors;
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';

// ══════════════════════════════════════════════════════════════════════
// RENEW PRODUCT PAGE
// The merchant picks the new end date. The backend decides - at order time AND
// again on confirmation - whether this renewal is free (a free product slot is
// available) or charged at the configured price per day for the days added.
// ══════════════════════════════════════════════════════════════════════
class RenewProductPage extends StatefulWidget {
  final String token;
  final Map<String,dynamic> product;
  const RenewProductPage({super.key, required this.token, required this.product});
  @override State<RenewProductPage> createState() => _RenewProductPageState();
}
class _RenewProductPageState extends State<RenewProductPage> {
  final _discountCtrl = TextEditingController();
  bool _loading       = false;
  String _msg         = "";
  String _discountMsg = "";
  bool _discountApplied = false;
  Map<String,dynamic>? _slots;           // renewal preview from the backend
  Map<String,dynamic>? _pendingOrder;
  late Razorpay _razorpay;
  late DateTime _newEnd;
  final _addDaysC = TextEditingController(text: "30");

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();
  bool get _isFree => _slots == null ? true : (_slots!["next_is_free"] as bool? ?? true);
  double get _pricePerDay => (_slots?["price_per_day"] as num?)?.toDouble() ?? 0;
  /// Days being added (billable): new end date minus the day the extension starts from.
  int get _addedDays => _newEnd.difference(_renewFrom).inDays;
  // Preview only: price per day × added days. The order response is authoritative.
  double get _price => _addedDays < 1 ? 0 : double.parse((_pricePerDay * _addedDays).toStringAsFixed(2));
  double get _gstPct => (_slots?["gst_pct"] as num?)?.toDouble() ?? 18;
  int get _maxDays => (_slots?["max_validity_days"] as num?)?.toInt() ?? 365;
  double get _gstAmt => double.parse((_price * _gstPct / 100).toStringAsFixed(2));
  double get _total => double.parse((_price + _gstAmt).toStringAsFixed(2));

  String _fmtDate(DateTime dt) {
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${m[dt.month-1]} ${dt.year}";
  }
  String _ymd(DateTime d) => "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
  String _fmtAmt(double v) => v == v.truncate() ? "₹${v.toInt()}" : "₹${v.toStringAsFixed(2)}";

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

  DateTime get _curEnd => _parseAnyDate(widget.product["end_date"]?.toString() ?? "") ?? DateTime.now();
  /// The last day already paid for (same rule as the backend): the current end date while the
  /// product is live, yesterday once it has expired - so added days start the day after.
  DateTime get _renewFrom {
    final t = DateTime.now();
    final yesterday = DateTime(t.year, t.month, t.day).subtract(const Duration(days: 1));
    final cur = DateTime(_curEnd.year, _curEnd.month, _curEnd.day);
    return cur.isAfter(yesterday) ? cur : yesterday;
  }

  @override void initState() {
    super.initState();
    _newEnd = _renewFrom.add(const Duration(days: 30));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    _loadSlots();
  }
  @override void dispose() { _discountCtrl.dispose(); _addDaysC.dispose(); _razorpay.clear(); super.dispose(); }

  void _setAddedDays(String raw) {
    final n = int.tryParse(raw.trim());
    if (n == null || n < 1) return;
    setState(() => _newEnd = _renewFrom.add(Duration(days: n)));
  }

  Future<void> _loadSlots() async {
    final s = await Api.getProductSlots(widget.token, excludeId: _pid);
    if (mounted) setState(() => _slots = s);
  }

  Future<void> _pickEnd() async {
    final first = _renewFrom.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _newEnd.isBefore(first) ? first : _newEnd,
      firstDate: first,
      lastDate: DateTime.now().add(Duration(days: _maxDays - 1)));
    if (picked != null) setState(() { _newEnd = picked; _addDaysC.text = "$_addedDays"; });
  }

  Future<void> _applyDiscount() async {
    final code = _discountCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() { _discountMsg = "Checking…"; _discountApplied = false; });
    try {
      final res = await Api.validateDiscountCode(widget.token, code, scope: "PRODUCTS");
      if (mounted) setState(() {
        _discountApplied = true;
        _discountMsg     = res["message"]?.toString() ?? "Discount applied!";
      });
    } catch (e) {
      if (mounted) setState(() { _discountMsg = friendlyError(e); _discountApplied = false; });
    }
  }

  Future<void> _proceed() async {
    if (!_newEnd.isAfter(_renewFrom)) { setState(() => _msg = "Choose a later end date (add at least 1 day)"); return; }
    setState(() { _loading = true; _msg = ""; });
    try {
      // The backend re-counts slots here - the preview above is only an estimate.
      final order = await Api.renewProductOrder(widget.token, _pid, {
        "end_date": _ymd(_newEnd),
        if (_discountApplied) "discount_code": _discountCtrl.text.trim().toUpperCase(),
      });
      if (!mounted) return;
      final rzpKey     = order["key"]?.toString() ?? "";
      final rzpOrderId = order["order_id"]?.toString() ?? "";
      final amtRupees  = (order["amount"] as num?)?.toDouble() ?? 0;
      final paise      = (amtRupees * 100).round();
      final isFree     = paise <= 0;

      final confirmed = await _showSummaryDialog(order, isFree);
      if (!confirmed || !mounted) { setState(() => _loading = false); return; }

      if (!isFree && rzpKey.isNotEmpty && rzpOrderId.isNotEmpty) {
        _pendingOrder = Map<String,dynamic>.from(order);
        _razorpay.open({
          "key": rzpKey, "amount": paise, "name": "OFFRO",
          "description": "Product renewal",
          "order_id": rzpOrderId,
          "prefill": {"contact": "", "email": ""},
          "theme": {"color": "#3E5F55"},
        });
        return;
      } else if (isFree) {
        final result = await Api.verifyRenewalPayment(widget.token, _pid, {
          "razorpay_order_id": "", "razorpay_payment_id": "", "razorpay_signature": "",
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result["message"]?.toString() ?? "✅ Renewed successfully!"),
            backgroundColor: OffroColors.statusLive));
          Navigator.pop(context, true);
        }
        return;
      } else {
        if (mounted) setState(() => _msg = "Payment gateway not configured. Contact support.");
      }
    } catch (e) {
      if (mounted) setState(() => _msg = friendlyError(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _showSummaryDialog(Map order, bool isFree) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Renewal Summary",
          style: TextStyle(color: kMerchantPrimary, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dRow("Product", widget.product["title"]?.toString() ?? ""),
          _dRow("New end date", order["end_date"]?.toString() ?? _fmtDate(_newEnd)),
          _dRow("Plan", isFree ? "Free renewal" : "Additional product"),
          if (!isFree) ...[
            const Divider(),
            _dRow("Price", "₹${order['base_price']}"),
            if (((order['discount_amount'] as num?) ?? 0) > 0)
              _dRow("Discount", "−₹${order['discount_amount']}", color: OffroColors.statusLive),
            _dRow("GST (${order['gst_percent']}%)", "₹${order['gst_amount']}"),
            _dRow("Total", "₹${order['amount_display']}", bold: true),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: kMerchantMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: kMerchantPrimary),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isFree ? "Renew free" : "Pay ₹${order['amount_display']}",
              style: const TextStyle(color: Colors.white))),
        ],
      ),
    );
    return result == true;
  }

  Widget _dRow(String k, String v, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Expanded(child: Text(k, style: const TextStyle(color: kMerchantMuted, fontSize: 13))),
      Text(v, style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.bold : FontWeight.w500,
        color: color ?? (bold ? kMerchantPrimary : kMerchantText))),
    ]));

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
          backgroundColor: OffroColors.statusLive));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() { _msg = friendlyError(e); _loading = false; });
    }
  }
  void _onPayError(PaymentFailureResponse res) {
    if (mounted) setState(() { _msg = "Payment failed: ${friendlyRazorpayError(res.message)}"; _loading = false; });
  }

  @override Widget build(BuildContext context) {
    final used  = (_slots?["used"] as num?)?.toInt() ?? 0;
    final limit = (_slots?["free_limit"] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: AppBar(title: const Text("Renew Product", style: TextStyle(fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kMerchantBorder)),
            child: Row(children: [
              const Icon(Icons.autorenew_rounded, color: kMerchantPrimary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.product["title"]?.toString() ?? "Product",
                  style: const TextStyle(fontWeight: FontWeight.w700, color: kMerchantText)),
                Text(widget.product["end_date"]?.toString().isNotEmpty == true
                    ? "Current end date: ${_fmtDate(_curEnd)}" : "No end date",
                  style: const TextStyle(color: kMerchantMuted, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 14),

          // Free / paid notice (estimate - backend decides on confirm)
          if (_slots != null) Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: OffroColors.mint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kMerchantBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isFree ? "Free renewal" : "Additional product",
                style: const TextStyle(fontWeight: FontWeight.w800, color: kMerchantText, fontSize: 14)),
              const SizedBox(height: 4),
              Text(_isFree
                  ? "A free product slot is available ($used of $limit in use), so this renewal is free."
                  : "You are using all $limit free product slots. Renewing costs ${_fmtAmt(_pricePerDay)} per day added + GST.",
                style: const TextStyle(color: kMerchantMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 14),

          _CheckoutCard(
            title: "New end date",
            subtitle: "Choose how long the product stays live.",
            child: Column(children: [
              TextField(
                controller: _addDaysC,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _setAddedDays,
                decoration: InputDecoration(
                  labelText: "Days to add",
                  prefixIcon: const Icon(Icons.calendar_month_rounded, color: kMerchantMuted, size: 20),
                  filled: true, fillColor: kMerchantBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14))),
              const SizedBox(height: 10),
              GestureDetector(
              onTap: _pickEnd,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: kMerchantBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kMerchantBorder)),
                child: Row(children: [
                  const Icon(Icons.event_rounded, size: 18, color: kMerchantMuted),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_fmtDate(_newEnd),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kMerchantText))),
                  const Icon(Icons.expand_more_rounded, color: kMerchantMuted),
                ]),
              ),
            ),
            ]),
          ),

          if (_slots != null && !_isFree) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: OffroColors.mint, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                _PriceRow("$_addedDays ${_addedDays == 1 ? 'day' : 'days'} × ${_fmtAmt(_pricePerDay)}/day", _fmtAmt(_price)),
                _PriceRow("GST (${_gstPct.toInt()}%)", _fmtAmt(_gstAmt)),
                const Divider(height: 20),
                _PriceRow("Total", _fmtAmt(_total), bold: true),
              ]),
            ),
            const SizedBox(height: 14),
            _CheckoutCard(
              title: "Discount Code",
              subtitle: "Have a promo code? Enter it below.",
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _discountCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: "e.g. OFFRO20",
                    prefixIcon: const Icon(Icons.local_offer_outlined, color: kMerchantMuted, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    filled: true, fillColor: kMerchantBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
                  ),
                )),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
                  onPressed: _applyDiscount,
                  child: const Text("Apply", style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
            if (_discountMsg.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(_discountMsg,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _discountApplied ? OffroColors.statusLive : Colors.red))),
          ],

          if (_msg.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 12),
              child: Text(_msg, style: const TextStyle(color: Colors.red, fontSize: 12))),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            icon: _loading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.autorenew_rounded),
            label: Text(_slots == null ? "Renew" : (_isFree ? "Renew free" : "Renew · ${_fmtAmt(_total)}")),
            style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _loading ? null : _proceed,
          ),
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
  bool _failed = false; // request failed — show retry, never fake zeros

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();

  // Backend sends plural keys (views/shares/opens) and, for older responses,
  // singular ones (view/share/open).
  int _count(String plural, String singular) {
    final v = _data[plural] ?? _data[singular];
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? "") ?? 0;
  }

  // "16 Oct 2026" in the device's local time (the server sends a UTC ISO
  // timestamp). Falls back to the raw date, or "—" when there is none.
  String get _lastSeen {
    final raw = (_data['last_viewed'] ?? _data['last_seen'] ?? "").toString();
    if (raw.isEmpty) return "—";
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw.length >= 10 ? raw.substring(0, 10) : "—";
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${dt.day} ${m[dt.month - 1]} ${dt.year}";
  }

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _failed = false; });
    final d = await Api.getProductAnalytics(widget.token, _pid);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (d == null) { _failed = true; } else { _data = d; }
    });
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kMerchantBg,
    appBar: AppBar(
      title: const Text("Product Analytics", style: TextStyle(fontWeight: FontWeight.w800)),
       
      actions: [
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: kMerchantPrimary))
      : _failed
      ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, color: kMerchantMuted, size: 44),
          const SizedBox(height: 12),
          const Text("Couldn't load analytics", style: TextStyle(fontWeight: FontWeight.w700, color: kMerchantText, fontSize: 16)),
          const SizedBox(height: 6),
          const Text("Please check your connection and try again.", textAlign: TextAlign.center,
              style: TextStyle(color: kMerchantMuted, fontSize: 13)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Retry"),
            style: ElevatedButton.styleFrom(elevation: 0, shape: const StadiumBorder(), backgroundColor: kMerchantPrimary, foregroundColor: Colors.white),
          ),
        ])))
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          // Product info card
          Card(elevation: 0, color: Colors.white, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: OffroColors.border)),
            child: ListTile(
              leading: const Icon(Icons.local_activity_rounded, color: kMerchantPrimary, size: 36),
              title: Text(widget.product["title"]?.toString() ?? "Product",
                style: const TextStyle(fontWeight: FontWeight.bold, color: kMerchantText)),
              subtitle: const Text("Premium Listing Analytics",
                style: TextStyle(color: kMerchantMuted, fontSize: 12)),
            )),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _AnalyticsStat("👁️ Views",  "${_count('views', 'view')}", kMerchantPrimary)),
            const SizedBox(width: 12),
            Expanded(child: _AnalyticsStat("🔗 Shares", "${_count('shares', 'share')}", const Color(0xFF2563EB))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _AnalyticsStat("🛒 Store Visits", "${_count('opens', 'open')}", const Color(0xFF059669))),
            const SizedBox(width: 12),
            Expanded(child: _AnalyticsStat("📅 Last Seen", _lastSeen, const Color(0xFF7C3AED), valueSize: 17)),
          ]),
          const SizedBox(height: 8),
          const Text("Store Visits: customers who visited the store",
            style: TextStyle(color: kMerchantMuted, fontSize: 11)),
          const SizedBox(height: 14),
          _ConversionBar(_data),
        ])),
  );
}

class _AnalyticsStat extends StatelessWidget {
  final String label, value;
  final Color color;
  /// Counts use the large size; a date value passes a smaller one so it stays
  /// on one line and the cards in a row keep the same height.
  final double valueSize;
  const _AnalyticsStat(this.label, this.value, this.color, {this.valueSize = 26});
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
      // Fixed-height value line so every stat card in a row matches.
      SizedBox(
        height: 34,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, maxLines: 1,
              style: TextStyle(color: color, fontSize: valueSize, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]),
  );
}

class _ConversionBar extends StatelessWidget {
  final Map<String,dynamic> data;
  const _ConversionBar(this.data);
  @override Widget build(BuildContext context) {
    final views  = ((data['views'] ?? data['view']) as num?)?.toDouble() ?? 0;
    final opens  = ((data['opens'] ?? data['open']) as num?)?.toDouble() ?? 0;
    final pct = views > 0 ? (opens / views * 100).clamp(0, 100).toStringAsFixed(1) : "0";
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Conversion Rate", style: TextStyle(fontWeight: FontWeight.w700, color: kMerchantText)),
        const SizedBox(height: 4),
        Text("$pct% of viewers visited the store (tapped Sold by)",
          style: const TextStyle(color: kMerchantMuted, fontSize: 12)),
        const SizedBox(height: 10),
        LinearProgressIndicator(
          value: views > 0 ? opens / views : 0,
          backgroundColor: kMerchantLight,
          color: kMerchantPrimary,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
      ]),
    );
  }
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
      child: Center(child: CircularProgressIndicator(color: kMerchantPrimary)));
    if (_items.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text("Similar Products",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kMerchantText))),
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
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: kMerchantBorder)),
              padding: const EdgeInsets.all(8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(height: 60, width: double.infinity,
                  decoration: BoxDecoration(
                    color: kMerchantLight,
                    borderRadius: BorderRadius.circular(8),
                    image: logo.startsWith("http")
                      ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                      : null,
                  ),
                  child: logo.startsWith("http") ? null
                    : const Center(child: Icon(Icons.local_activity, color: kMerchantPrimary, size: 24))),
                const SizedBox(height: 6),
                Text(p["title"]?.toString() ?? "", maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kMerchantText)),
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
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: kMerchantText))),
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
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: kMerchantBorder)),
            padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(height: 60, width: double.infinity,
                decoration: BoxDecoration(color: kMerchantLight,
                  borderRadius: BorderRadius.circular(8),
                  image: logo.startsWith("http")
                    ? DecorationImage(image: NetworkImage(logo), fit: BoxFit.cover)
                    : null),
                child: logo.startsWith("http") ? null
                  : const Center(child: Icon(Icons.local_activity, color: kMerchantPrimary, size: 24))),
              const SizedBox(height: 6),
              Text(p["title"]?.toString() ?? "", maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kMerchantText)),
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
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kMerchantText)),
      if (subtitle != null) ...[
        const SizedBox(height: 2),
        Text(subtitle!, style: const TextStyle(color: kMerchantMuted, fontSize: 12)),
      ],
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _PriceRow(this.label, this.value, {this.bold = false, this.color});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        color: color ?? (bold ? kMerchantText : kMerchantMuted),
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      Text(value, style: TextStyle(
        color: color ?? (bold ? kMerchantText : kMerchantText),
        fontSize: bold ? 15 : 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ]),
  );
}
