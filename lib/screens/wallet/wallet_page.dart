// lib/screens/wallet/wallet_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/design/design.dart';

class WalletPage extends StatefulWidget {
  final String token;
  // true when shown as the Rewards tab inside Home (no own Scaffold / back
  // button, the floating bottom nav stays visible).
  final bool embedded;
  const WalletPage({super.key, required this.token, this.embedded = false});
  @override State<WalletPage> createState() => _WalletState();
}

class _WalletState extends State<WalletPage> {
  // Redeem threshold used by the existing backend flow (200 points = ₹20 voucher).
  static const int _redeemAt = 200;

  int vp = 0, pp = 0;
  bool loading = true;
  List _history = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await Api.getWallet(widget.token);
      if (mounted) setState(() { vp = d["visit_points"] ?? 0; pp = d["pool_points"] ?? 0; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
    // Recent activity = the user's real scan history (same call as Scan History).
    try {
      final h = await Api.getRedemptions(widget.token);
      if (mounted) setState(() => _history = h);
    } catch (e) {
      debugPrint('[OffrO] rewards activity load error: $e');
    }
  }

  Future<void> _withdraw() async {
    // NOTE: function kept named _withdraw() internally and still calls Api.withdraw()
    // (same backend endpoint) — this is purely a UI/wording change for Google Play
    // policy compliance. No business logic, API, or DB fields were changed.
    try {
      final r = await Api.withdraw(widget.token, 200);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r["message"] ?? "Done")));
      _load();
    } catch (e) {
      debugPrint('[OffrO] wallet withdraw error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  static String _fmt(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');

  static String _dateLabel(String raw) {
    try {
      final dt = DateTime.parse(raw);
      const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
      return "${dt.day} ${months[dt.month - 1]} ${dt.year}";
    } catch (_) {
      return raw;
    }
  }

  Widget _balanceCard(int total) {
    final canRedeem = total >= _redeemAt;
    final toGo = (_redeemAt - total).clamp(0, _redeemAt);
    final progress = (total / _redeemAt).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 24, OffroSpacing.gutter, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OffroRadii.hero),
        child: Container(
          color: OffroColors.primary,
          padding: const EdgeInsets.all(24),
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            Positioned(
              right: -80, top: -88,
              child: Container(
                width: 208, height: 208,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: .05), width: 42),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                buildImageLogo(height: 32, white: true),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .10),
                    borderRadius: OffroRadii.pillRadius,
                  ),
                  child: Text("REWARD POINTS",
                    style: OffroText.eyebrow.copyWith(fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: .70))),
                ),
              ]),
              const SizedBox(height: 44),
              Text("Available balance",
                style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: .50))),
              const SizedBox(height: 4),
              Text.rich(TextSpan(children: [
                TextSpan(text: _fmt(total),
                  style: OffroText.display.copyWith(fontSize: 43, letterSpacing: -2.6, height: 1.1, color: Colors.white)),
                TextSpan(text: "  points",
                  style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: .45))),
              ])),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: canRedeem ? _withdraw : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: canRedeem ? .20 : .12),
                    borderRadius: OffroRadii.pillRadius,
                  ),
                  child: Text("Redeem",
                    style: OffroText.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: canRedeem ? 1 : .55))),
                ),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(children: [
                  Container(height: 6, color: Colors.white.withValues(alpha: .10)),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(height: 6, color: OffroColors.mint),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("$_redeemAt pts = ₹20 voucher",
                  style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: .45))),
                Text(canRedeem ? "Ready to redeem" : "$toGo pts to go",
                  style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.white.withValues(alpha: .45))),
              ]),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _voucherCard(int total) {
    final canRedeem = total >= _redeemAt;
    final toGo = (_redeemAt - total).clamp(0, _redeemAt);
    return Padding(
      padding: OffroSpacing.gutterH,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: OffroColors.beige,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const OffroIcon(OffroIcons.gift, size: 20, color: OffroColors.primary),
            const Spacer(),
            Text("$_redeemAt pts",
              style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
          ]),
          const SizedBox(height: 36),
          Text("₹20", style: OffroText.headline.copyWith(fontSize: 30, letterSpacing: -1.8)),
          const SizedBox(height: 4),
          Text("Promotional gift voucher · Amazon or Flipkart",
            style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: OffroColors.textMuted)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: canRedeem ? _withdraw : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: canRedeem ? OffroColors.primary : OffroColors.primary.withValues(alpha: .35),
                borderRadius: OffroRadii.pillRadius,
              ),
              child: Text(canRedeem ? "Redeem" : "Earn $toGo more points",
                style: OffroText.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _howItWorks() {
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          alignment: Alignment.center,
          decoration: const BoxDecoration(color: Color(0x8CCDEBD6), shape: BoxShape.circle),
          child: const OffroIcon(OffroIcons.check, size: 11, color: OffroColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: OffroText.bodySmall.copyWith(fontSize: 12, color: OffroColors.text))),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 20, OffroSpacing.gutter, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: BoxDecoration(
          color: OffroColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("How rewards work", style: OffroText.cardTitle.copyWith(fontSize: 13)),
          const SizedBox(height: 12),
          line("Redeem 200 Reward Points for a ₹20 Promotional Gift Voucher."),
          line("Gift voucher delivery: 3-5 business days."),
          line("Reward points never expire."),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              "Reward points are promotional loyalty points. They cannot be purchased, transferred, or exchanged for cash.",
              style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
          ),
        ]),
      ),
    );
  }

  Widget _activity() {
    final rows = _history.take(5).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 32, OffroSpacing.gutter, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Recent activity", style: OffroText.title.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: OffroColors.surface,
            borderRadius: BorderRadius.circular(22),
          ),
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text("No scans yet — points you earn at stores will show up here.",
                    style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w400, color: OffroColors.textSubtle)),
                )
              : Column(children: [
                  for (int i = 0; i < rows.length; i++)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: i < rows.length - 1
                            ? const Border(bottom: BorderSide(color: Color(0x0D000000)))
                            : null,
                      ),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Color(0x8CCDEBD6), shape: BoxShape.circle),
                          child: const OffroIcon(OffroIcons.star, size: 16, color: OffroColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(((rows[i] as Map)["store_name"] ?? "").toString(),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: OffroText.cardTitle.copyWith(fontSize: 12)),
                          const SizedBox(height: 2),
                          Text("Earned · ${_dateLabel(((rows[i] as Map)["date"] ?? "").toString())}",
                            style: OffroText.caption.copyWith(fontSize: 10, fontWeight: FontWeight.w400, color: OffroColors.textFaint)),
                        ])),
                        Text("+${(rows[i] as Map)["points"] ?? 0}",
                          style: OffroText.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4F8068))),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }

  @override Widget build(BuildContext ctx) {
    final total = vp;
    final topPad = MediaQuery.of(ctx).padding.top;

    final content = loading
        ? const Center(child: CircularProgressIndicator(color: OffroColors.primary))
        : RefreshIndicator(
            color: OffroColors.primary,
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.only(top: widget.embedded ? topPad : 0, bottom: widget.embedded ? 124 : 32),
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                OffroScreenHeader(
                  eyebrow: "Your local loyalty",
                  title: "Rewards",
                  description: "Every local purchase gets you closer to something good.",
                  showBack: !widget.embedded,
                ),
                _balanceCard(total),
                Padding(
                  padding: const EdgeInsets.only(top: 28),
                  child: OffroSectionTitle(
                    eyebrow: "Ready to use",
                    title: "Your vouchers",
                    actionLabel: "View history",
                    onAction: () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => HistoryPage(token: widget.token))),
                  ),
                ),
                const SizedBox(height: 16),
                _voucherCard(total),
                _howItWorks(),
                _activity(),
              ],
            ),
          );

    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(bottom: false, child: content),
    );
  }
}

// ─────────────────────── HISTORY PAGE ───────────────────────
class HistoryPage extends StatefulWidget {
  final String token; const HistoryPage({super.key,required this.token});
  @override State<HistoryPage> createState()=>_HistoryState();
}
class _HistoryState extends State<HistoryPage>{
  List _h=[]; bool _l=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    // Round 9 FIX: Api.getRedemptions() already swallows its own failures
    // and returns [] (an intentional "silent empty" case, unchanged here),
    // but the await itself was previously unguarded — if the call ever
    // threw for an unrelated reason the whole screen would be stuck
    // loading forever. Guard it so the screen always settles.
    try {
      _h = await Api.getRedemptions(widget.token);
    } catch (e) {
      debugPrint('[OffrO] scan history load error: $e');
      _h = [];
    }
    if(mounted)setState(()=>_l=false);
  }
  @override Widget build(BuildContext ctx)=>Scaffold(
    appBar:AppBar(title:const Text("Scan History"),backgroundColor:kPrimary,foregroundColor:Colors.white),backgroundColor:kBg,
    body:_l?const Center(child:CircularProgressIndicator(color:kPrimary)):
    _h.isEmpty?Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[buildLogo(44,kAccent),const SizedBox(height:12),const Text("No scans yet",style:TextStyle(color:OffroColors.textMuted,fontSize:16))])):
    ListView.separated(padding:const EdgeInsets.all(16),itemCount:_h.length,separatorBuilder:(_,__)=>const SizedBox(height:8),
      itemBuilder:(_,i){
        final h=_h[i] as Map;
        final String? storeImg = h["store_image"]?.toString();
        final String dateRaw = h["date"]?.toString() ?? "";
        // Try to format date nicely
        String dateLabel = dateRaw;
        try {
          final dt = DateTime.parse(dateRaw);
          final months=["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
          dateLabel = "${dt.day} ${months[dt.month-1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";
        } catch(_) {}
        return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:OffroColors.border)),
          child:Row(children:[
            // store image or fallback icon
            ClipRRect(borderRadius:BorderRadius.circular(10),
              child: SizedBox(width:48,height:48,
                child: storeImg!=null && storeImg.startsWith("data:image")
                  ? (() { try { return Image.memory(base64Decode(storeImg.split(",").last),fit:BoxFit.cover,gaplessPlayback:true); } catch(_) { return const SizedBox(); } })()
                  : Container(color:kLight,child:const Icon(Icons.store_rounded,color:kPrimary,size:22)))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(h["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:OffroColors.text,fontSize:13)),
              const SizedBox(height:3),
              Row(children:[
                const Icon(Icons.calendar_today_rounded,color:OffroColors.textMuted,size:11),const SizedBox(width:4),
                Text(dateLabel,style:const TextStyle(color:OffroColors.textMuted,fontSize:11)),
              ]),
            ])),
            Container(
              padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration:BoxDecoration(color:kLight,borderRadius:BorderRadius.circular(12)),
              child:Text("+${h['points']} pts",style:const TextStyle(color:kPrimary,fontWeight:FontWeight.bold,fontSize:13)),
            )]));
      },));
}

// ─────────────────────── RAZORPAY WEBVIEW ───────────────────────



// ─────────────────────── GRID STORE CARD (2-per-row, image overlay) ───────────────────────
