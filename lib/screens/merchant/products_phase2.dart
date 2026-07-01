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
  final _daysC = TextEditingController(text: "30");
  bool _loading = false;
  String _msg = "";
  Map<String,dynamic>? _pendingOrder;
  DateTime _fromDate = DateTime.now();
  late Razorpay _razorpay;

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();
  int get _days => int.tryParse(_daysC.text.trim()) ?? 0;
  DateTime get _endDate => _fromDate.add(Duration(days: _days));

  String _fmtDate(DateTime dt) =>
    "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";
  String _apiDate(DateTime dt) =>
    "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";

  @override void initState() {
    super.initState();
    _daysC.addListener(() => setState((){}));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
  }
  @override void dispose() { _daysC.dispose(); _razorpay.clear(); super.dispose(); }

  Future<void> _proceed() async {
    if (_days < 1) { setState(() => _msg = "Enter valid number of days"); return; }
    setState(() { _loading = true; _msg = ""; });
    try {
      final order = await Api.upgradeProductOrder(widget.token, _pid, {
        "days": _days, "from_date": _apiDate(_fromDate),
      });
      if (!mounted) return;
      final paise = (order["amount_paise"] as num?)?.toInt() ?? 0;
      final mode  = order["pay_mode"] ?? "manual";
      if (mode == "manual" || paise <= 0) {
        // show summary and confirm
        final ok = await _showSummary(order, free: true);
        if (ok == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Upgrade submitted for approval!"),
            backgroundColor: Color(0xFF1a6640)));
          Navigator.pop(context, true);
        }
      } else {
        final ok = await _showSummary(order, free: false);
        if (ok == true && mounted) {
          _pendingOrder = Map<String,dynamic>.from(order);
          _razorpay.open({
            "key":      order["razorpay_key"],
            "amount":   paise,
            "name":     "OFFRO",
            "description": "Product Upgrade – $_days Days",
            "order_id": order["razorpay_order_id"],
            "prefill":  {"contact": "", "email": ""},
            "theme":    {"color": "#3E5F55"},
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _msg = e.toString().replaceAll("Exception: ",""));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool?> _showSummary(Map order, {required bool free}) =>
    showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text("Upgrade to Premium", style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SummaryRow("Duration", "$_days days"),
        _SummaryRow("From",     _fmtDate(_fromDate)),
        _SummaryRow("Until",    _fmtDate(_endDate)),
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
          child: Text(free ? "Confirm" : "Pay ₹${order['total']}", style: const TextStyle(color: Colors.white))),
      ],
    ));

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
      if (mounted) setState(() => _msg = e.toString().replaceAll("Exception: ",""));
    }
  }
  void _onPayError(PaymentFailureResponse res) {
    if (mounted) setState(() => _msg = "Payment failed: ${res.message}");
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      title: const Text("Upgrade to Premium", style: TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white, foregroundColor: kText,
    ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        _UpgradeInfoCard(),
        const SizedBox(height: 20),
        _SectionTitle("Duration"),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(
            controller: _daysC, keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Number of Days", isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(),
            ),
          )),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("From", style: TextStyle(color: kMuted, fontSize: 12)),
            TextButton.icon(
              onPressed: () async {
                final p = await showDatePicker(context: context,
                  initialDate: _fromDate, firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)));
                if (p != null) setState(() => _fromDate = p);
              },
              icon: const Icon(Icons.calendar_today_rounded, size: 14),
              label: Text(_fmtDate(_fromDate), style: const TextStyle(fontSize: 13)),
            ),
          ]),
        ]),
        const SizedBox(height: 8),
        if (_days > 0) Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kLight, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.event_available_rounded, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Text("Active from ${_fmtDate(_fromDate)} to ${_fmtDate(_endDate)}",
              style: const TextStyle(color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
        if (_msg.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _loading ? null : _proceed,
          icon: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.upgrade_rounded, color: Colors.white),
          label: Text(_loading ? "Processing..." : "Upgrade to Premium",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ],
    )),
  );
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
  final _daysC = TextEditingController(text: "30");
  bool _loading = false;
  String _msg = "";
  Map<String,dynamic>? _pendingOrder;
  late Razorpay _razorpay;

  String get _pid => (widget.product["_id"] ?? widget.product["id"] ?? "").toString();
  int get _days => int.tryParse(_daysC.text.trim()) ?? 0;

  @override void initState() {
    super.initState();
    _daysC.addListener(()=>setState((){}));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
  }
  @override void dispose() { _daysC.dispose(); _razorpay.clear(); super.dispose(); }

  Future<void> _proceed() async {
    if (_days < 1) { setState(() => _msg = "Enter valid number of days"); return; }
    setState(() { _loading = true; _msg = ""; });
    try {
      final order = await Api.renewProductOrder(widget.token, _pid, {"days": _days});
      if (!mounted) return;
      final paise = (order["amount_paise"] as num?)?.toInt() ?? 0;
      final mode  = order["pay_mode"] ?? "manual";
      if (mode == "manual" || paise <= 0) {
        final ok = await _showSummary(order, free: true);
        if (ok == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("✅ Renewed successfully!"),
            backgroundColor: Color(0xFF1a6640)));
          Navigator.pop(context, true);
        }
      } else {
        final ok = await _showSummary(order, free: false);
        if (ok == true && mounted) {
          _pendingOrder = Map<String,dynamic>.from(order);
          _razorpay.open({
            "key":      order["razorpay_key"],
            "amount":   paise,
            "name":     "OFFRO",
            "description": "Premium Renewal – $_days Days",
            "order_id": order["razorpay_order_id"],
            "prefill":  {"contact": "", "email": ""},
            "theme":    {"color": "#3E5F55"},
          });
        }
      }
    } catch(e) {
      if (mounted) setState(() => _msg = e.toString().replaceAll("Exception: ",""));
    }
    if (mounted) setState(() => _loading = false);
  }

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
      if (mounted) setState(() => _msg = e.toString().replaceAll("Exception: ",""));
    }
  }
  void _onPayError(PaymentFailureResponse res) {
    if (mounted) setState(() => _msg = "Payment failed: ${res.message}");
  }

  String get _curEnd {
    final raw = widget.product["end_date"]?.toString() ?? "";
    if (raw.isEmpty) return "—";
    try {
      final dt = DateTime.parse(raw);
      return "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";
    } catch (_) { return raw; }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      title: const Text("Renew Premium", style: TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white, foregroundColor: kText,
    ),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade300)),
          child: Row(children: [
            const Icon(Icons.refresh_rounded, color: Color(0xFF856404)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.product["title"]?.toString() ?? "Product",
                style: const TextStyle(fontWeight: FontWeight.bold, color: kText)),
              Text("Current end: $_curEnd", style: const TextStyle(color: kMuted, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),
        _SectionTitle("Extend Duration"),
        const SizedBox(height: 10),
        TextField(
          controller: _daysC, keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Extra Days", isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(),
          ),
        ),
        if (_msg.isNotEmpty) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_msg, style: const TextStyle(color: Colors.red, fontSize: 13))),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF856404),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _loading ? null : _proceed,
          icon: _loading
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.calendar_month_rounded, color: Colors.white),
          label: Text(_loading ? "Processing..." : "Renew for $_days Days",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ],
    )),
  );
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
