// lib/screens/merchant/merchant_screens.dart
// FIX 14: requires in pubspec.yaml:
//   printing: ^5.13.1
//   share_plus: ^10.0.3
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../main.dart' show MyApp;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../payment/payment_success_screen.dart';
import 'products_phase2.dart';

PageRoute _offroRoute(Widget w) => MaterialPageRoute(builder: (_) => w);

// ══════════════════════════════════════════════════════════
// MERCHANT HOME PAGE — 3 section cards
// ══════════════════════════════════════════════════════════

class MerchantHomePage extends StatefulWidget {
  final String token;
  const MerchantHomePage({super.key, required this.token});
  @override State<MerchantHomePage> createState() => _MerchantHomePageState();
}
class _MerchantHomePageState extends State<MerchantHomePage> {
  List<Map<String,dynamic>> _stores   = [];
  List<Map<String,dynamic>> _banners  = [];
  List<Map<String,dynamic>> _products = [];
  bool _loading   = true;
  bool _loadError = false;
  int  _stdLimit  = 10;  // admin-configured standard product slot limit

  @override void initState() { super.initState(); _load(); }

  Future<void> _load({int retryCount = 0}) async {
    setState(()=>_loading=true);
    try {
      final storesFuture   = Api.getMerchantStores(widget.token).timeout(const Duration(seconds: 15));
      final bannersFuture  = Api.getMerchantBanners(widget.token).timeout(const Duration(seconds: 10));
      final productsFuture = Api.getMerchantProducts(widget.token).timeout(const Duration(seconds: 10));
      final limitFuture    = Api.getProductLimit(widget.token).timeout(const Duration(seconds: 10));

      final results = await Future.wait([storesFuture, bannersFuture, productsFuture, limitFuture]);
      if (mounted) setState((){
        _stores   = List<Map<String,dynamic>>.from(results[0] as Iterable);
        _banners  = List<Map<String,dynamic>>.from(results[1] as Iterable);
        _products = List<Map<String,dynamic>>.from(results[2] as Iterable);
        final limitMap = results[3] as Map<String,dynamic>;
        _stdLimit = (limitMap["standard_product_limit"] as num?)?.toInt() ?? 10;
        _loading  = false;
        _loadError = false;
      });
    } catch(e) {
      debugPrint('[MerchantHome] _load error (attempt ${retryCount+1}): $e');
      if (retryCount == 0 && mounted) {
        await Future.delayed(const Duration(seconds: 2));
        return _load(retryCount: 1);
      }
      if (mounted) setState(() { _loading = false; _loadError = true; });
    }
  }

  // FIX7: never treat load-error as "new merchant" — only show onboarding if stores truly empty
  bool get _hasEligibleStore => !_loadError && _stores.any((s)=>
    ["active","inactive","waiting_approval","paid"].contains(s["status"]));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      title: Row(children:[
        buildImageLogo(height:24, white:true),
        const SizedBox(width:8),
        const Text("Merchant Home", style:TextStyle(fontWeight:FontWeight.w800)),
      ]),
      backgroundColor: Colors.white, foregroundColor: kText,
      automaticallyImplyLeading:false,
    ),
    body: _loading
      ? const Center(child:CircularProgressIndicator(color:kPrimary))
      // FIX7: show retry instead of new-merchant flow when network failed
      : (_loadError && _stores.isEmpty)
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off_rounded, color: kMuted, size: 48),
              const SizedBox(height: 16),
              const Text("Couldn't load your dashboard", style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text("Check your connection and try again", style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _load(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
              ),
            ]))
      : RefreshIndicator(
          onRefresh:_load,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEEF7F2), Color(0xFFF9FBF9), Color(0xFFF4EFE8)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── Section cards ──
              _SectionCard(
                icon: Icons.store_rounded,
                color: kPrimary,
                bgColor: const Color(0xFFe8f4ef),
                title: "My Store",
                subtitle: _stores.isEmpty
                  ? "No stores yet — tap to add your first"
                  : "${_stores.length} Store${_stores.length>1?'s':''} • ${_stores.where((s)=>s['status']=='active').length} Active",
                onTap: ()=>Navigator.push(context,_offroRoute(MerchantStoresPage(token:widget.token))).then((_)=>_load()),
              ),
              const SizedBox(height:12),

              // Banner card — locked if no eligible store
              _SectionCard(
                icon: Icons.view_carousel_rounded,
                color: _hasEligibleStore ? const Color(0xFFc0392b) : kMuted,
                bgColor: _hasEligibleStore ? const Color(0xFFfde8e8) : const Color(0xFFf0f0f0),
                title: "My Banner",
                subtitle: !_hasEligibleStore
                  ? "🔒 Create a store first to unlock"
                  : _banners.isEmpty
                    ? "No banners yet — promote your store"
                    : ((){
                        final live=_banners.where((b)=>(b['approval_status']??b['status']??'')=='approved').length;
                        final pend=_banners.where((b){final st=(b['approval_status']??b['status']??'').toString();return st=='pending'||st=='pending_approval';}).length;
                        final parts=<String>[];if(live>0)parts.add("$live Live");if(pend>0)parts.add("$pend Pending");
                        return "${_banners.length} Banner${_banners.length>1?'s':''} • ${parts.isEmpty?'Submitted':parts.join(' · ')}";
                      })(),
                onTap: _hasEligibleStore
                  ? ()=>Navigator.push(context,_offroRoute(MerchantBannersPage(token:widget.token))).then((_)=>_load())
                  : ()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:Text("Create an active store first to create banners."),
                      backgroundColor:Colors.orange)),
              ),
              const SizedBox(height:12),

              // Product card — locked if no eligible store
              _SectionCard(
                icon: Icons.local_activity_rounded,
                color: _hasEligibleStore ? const Color(0xFF856404) : kMuted,
                bgColor: _hasEligibleStore ? const Color(0xFFfff3cd) : const Color(0xFFf0f0f0),
                title: "My Products",
                subtitle: !_hasEligibleStore
                  ? "🔒 Create a store first to unlock"
                  : _products.isEmpty
                    ? "No products yet — add your first product"
                    : ((){
                        final std  = _products.where((v)=>(v['product_type']??'')=='standard').length;
                        final prem = _products.where((v)=>(v['product_type']??'premium')=='premium').length;
                        final live = _products.where((v){
                          final st=(v['approval_status']??v['status']??'').toString();
                          return st=='approved';
                        }).length;
                        final parts=<String>[];
                        parts.add("🟢 Std: $std/$_stdLimit");
                        if(prem>0) parts.add("🟣 Prem: $prem");
                        if(live>0) parts.add("$live Live");
                        return parts.join('  ·  ');
                      })(),
                onTap: _hasEligibleStore
                  ? ()=>Navigator.push(context,_offroRoute(MerchantProductsPage(token:widget.token))).then((_)=>_load())
                  : ()=>ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:Text("Create an active store first to create products."),
                      backgroundColor:Colors.orange)),
              ),


            ]),
            ),  // SingleChildScrollView
          ),    // Container (gradient)
        ),      // RefreshIndicator
  );
}

class _SectionCard extends StatelessWidget {
  final IconData icon; final Color color, bgColor;
  final String title, subtitle; final VoidCallback onTap;
  const _SectionCard({required this.icon, required this.color, required this.bgColor,
    required this.title, required this.subtitle, required this.onTap});

  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .22), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .12), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: color.withValues(alpha: .05), blurRadius: 6,  offset: const Offset(0, 2)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Top row: icon + arrow ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: color.withValues(alpha: .12), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("Open", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: color, size: 13),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        // ── Title ──
        Text(title,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: color, letterSpacing: -0.3)),
        const SizedBox(height: 6),
        // ── Subtitle / stats ──
        Text(subtitle,
          style: const TextStyle(color: kMuted, fontSize: 13, height: 1.4),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}



// ══════════════════════════════════════════════════════════
// MERCHANT BANNERS PAGE
// ══════════════════════════════════════════════════════════

class MerchantBannersPage extends StatefulWidget {
  final String token;
  const MerchantBannersPage({super.key, required this.token});
  @override State<MerchantBannersPage> createState() => _MerchantBannersState();
}
class _MerchantBannersState extends State<MerchantBannersPage> {
  List<Map<String,dynamic>> _banners = []; bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>_loading=true);
    _banners = List<Map<String,dynamic>>.from(await Api.getMerchantBanners(widget.token));
    if (mounted) setState(()=>_loading=false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(
      title:Row(children:[buildImageLogo(height:24,white:true),const SizedBox(width:8),const Text("My Banners",style:TextStyle(fontWeight:FontWeight.w800))]),
      backgroundColor: Colors.white, foregroundColor: kText,
    ),
    floatingActionButton:FloatingActionButton.extended(
      backgroundColor: Colors.white, foregroundColor: kText,
      icon:const Icon(Icons.add), label:const Text("New Banner"),
      onPressed:()=>Navigator.push(context,_offroRoute(AddBannerPage(token:widget.token))).then((_)=>_load()),
    ),
    body:_loading
      ? const Center(child:CircularProgressIndicator(color:kPrimary))
      : Column(children:[
          Expanded(child:_banners.isEmpty
            ? const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Icon(Icons.view_carousel_outlined,size:64,color:kAccent),
                SizedBox(height:12),
                Text("No banners yet",style:TextStyle(color:kMuted,fontSize:16)),
                SizedBox(height:6),
                Text("Tap + to create your first banner",style:TextStyle(color:kMuted,fontSize:13)),
              ]))
            : RefreshIndicator(
                onRefresh:_load,
                child:ListView.builder(
                  padding:const EdgeInsets.all(14),
                  itemCount:_banners.length,
                  itemBuilder:(_,i){
                    final b = _banners[i];
                    // FIX 1: use approval_status as primary, fall back to status
                    // TASK 4: expired check
                    String rawStatus = (b["approval_status"]??"") != ""
                        ? (b["approval_status"] ?? "pending")
                        : (b["status"] ?? "pending");
                    final _bEndRaw = b["end_date"]?.toString() ?? "";
                    if (rawStatus == "approved" && _bEndRaw.isNotEmpty) {
                      try { final _bEnd = DateTime.parse(_bEndRaw);
                        if (DateTime.now().isAfter(_bEnd)) rawStatus = "expired";
                      } catch (_) {}
                    }
                    final (Color sc, String sl, IconData si) = switch(rawStatus) {
                      "approved"  => (const Color(0xFF1a6640),"Approved — Live", Icons.check_circle),
                      "rejected"  => (Colors.red, "Rejected", Icons.cancel),
                      "expired"   => (Colors.grey.shade600, "Expired", Icons.event_busy_rounded),
                      "pending_approval" || "pending" => (const Color(0xFF856404),"Pending Approval", Icons.access_time_rounded),
                      _ => (kMuted,"Submitted", Icons.hourglass_empty),
                    };
                    // FIX 2: prefer from_date/end_date, fallback start_date
                    final fromDate = b["from_date"]?.toString() ?? b["start_date"]?.toString() ?? "";
                    final endDate  = b["end_date"]?.toString() ?? "";
                    final imgUrl   = b["image_url"]?.toString() ?? "";
                    return Card(elevation:2,margin:const EdgeInsets.only(bottom:14),
                      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
                      child:Column(children:[
                        if (imgUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius:const BorderRadius.vertical(top:Radius.circular(14)),
                            child:imgUrl.startsWith("data:image")
                              ? Image.memory(base64Decode(imgUrl.split(",").last),
                                  width:double.infinity,height:120,fit:BoxFit.cover)
                              : Image.network(imgUrl,width:double.infinity,height:120,fit:BoxFit.cover,
                                  errorBuilder:(_,__,___) => Container(height:80,color:kLight,child:const Icon(Icons.image_not_supported,color:kMuted))),
                          ),
                        Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Row(children:[
                            Expanded(child:Text(b["title"]??"",style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:kText))),
                            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                              decoration:BoxDecoration(color:sc.withValues(alpha:.13),borderRadius:BorderRadius.circular(20)),
                              child:Row(mainAxisSize:MainAxisSize.min,children:[
                                Icon(si,size:12,color:sc),
                                const SizedBox(width:4),
                                Text(sl,style:TextStyle(color:sc,fontSize:11,fontWeight:FontWeight.w700)),
                              ])),
                          ]),
                          const SizedBox(height:8),
                          // Duration row
                          Row(children:[
                            const Icon(Icons.schedule_rounded,size:14,color:kMuted),
                            const SizedBox(width:5),
                            Text("${b['duration']??b['duration_days']??30} Days",style:const TextStyle(color:kMuted,fontSize:12,fontWeight:FontWeight.w600)),
                            const SizedBox(width:12),
                            const Icon(Icons.payments_outlined,size:14,color:kMuted),
                            const SizedBox(width:5),
                            Text("₹${b['amount']??0}",style:const TextStyle(color:kMuted,fontSize:12,fontWeight:FontWeight.w600)),
                          ]),
                          const SizedBox(height:5),
                          // Date range — FIX 2: clear display
                          if (fromDate.isNotEmpty || endDate.isNotEmpty)
                            Container(
                              margin:const EdgeInsets.only(top:2),
                              padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                              decoration:BoxDecoration(color:kLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
                              child:Row(children:[
                                const Icon(Icons.calendar_month_rounded,size:14,color:kPrimary),
                                const SizedBox(width:6),
                                Expanded(child:Text(
                                  fromDate.isNotEmpty && endDate.isNotEmpty
                                    ? "Start: $fromDate   →   End: $endDate"
                                    : fromDate.isNotEmpty ? "From: $fromDate" : "Until: $endDate",
                                  style:const TextStyle(color:kPrimary,fontSize:11,fontWeight:FontWeight.w600))),
                              ]),
                            ),
                          if ((b["invoice_no"]??"").isNotEmpty) ...[
                            const SizedBox(height:4),
                            Text("Invoice: ${b['invoice_no']}",style:const TextStyle(color:kMuted,fontSize:11)),
                          ],
                          const SizedBox(height:10),
                          Row(mainAxisAlignment:MainAxisAlignment.end,children:[
                            OutlinedButton.icon(
                              onPressed:() async {
                                final ctrl = TextEditingController(text:b["title"]??"");
                                final newTitle = await showDialog<String>(context:context,builder:(_)=>AlertDialog(
                                  title:const Text("Edit Banner Title",style:TextStyle(color:kPrimary,fontWeight:FontWeight.bold)),
                                  content:TextField(controller:ctrl,decoration:InputDecoration(
                                    hintText:"Banner title",
                                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)),
                                    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)))),
                                  actions:[
                                    TextButton(onPressed:()=>Navigator.pop(context),child:const Text("Cancel",style:TextStyle(color:kMuted))),
                                    ElevatedButton(
                                      style:ElevatedButton.styleFrom(backgroundColor:kPrimary),
                                      onPressed:()=>Navigator.pop(context,ctrl.text.trim()),
                                      child:const Text("Save",style:TextStyle(color:Colors.white))),
                                  ],
                                ));
                                if (newTitle!=null && newTitle.isNotEmpty && newTitle!=b["title"]) {
                                  try {
                                    await Api.updateMerchantBanner(widget.token, b["_id"]??"", {"title": newTitle});
                                    _load();
                                  } catch(e) {
                                    if(mounted) ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content:Text("Error: $e"),backgroundColor:Colors.red));
                                  }
                                }
                              },
                              icon:const Icon(Icons.edit_rounded,size:14,color:kPrimary),
                              label:const Text("Edit Title",style:TextStyle(color:kPrimary,fontSize:12)),
                              style:OutlinedButton.styleFrom(
                                side:const BorderSide(color:kPrimary),
                                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
                                padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
                                minimumSize:Size.zero, tapTargetSize:MaterialTapTargetSize.shrinkWrap),
                            ),
                          ]),
                        ])),
                      ]),
                    );
                  },
                ),
              )),
        ]),
  );
}

// ── Banner placement preview widget ──
class _BannerPlacementPreview extends StatelessWidget {
  const _BannerPlacementPreview();
  @override Widget build(BuildContext context) => Container(
    margin:const EdgeInsets.fromLTRB(14,14,14,0),
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(14),
      border:Border.all(color:const Color(0xFF3E5F55), width:1.5),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Icon(Icons.info_outline,size:15,color:kPrimary),
        const SizedBox(width:6),
        const Text("Where your banner appears",style:TextStyle(fontWeight:FontWeight.w700,color:kPrimary,fontSize:13)),
      ]),
      const SizedBox(height:10),
      // FIX 13: Real OFFRO app mockup image
      ClipRRect(
        borderRadius:BorderRadius.circular(10),
        child:Image.network(
          "https://media.base44.com/images/public/69dc008cb5876dcb8680be38/a09b33237_generated_image.png",
          width:double.infinity,
          height:160,
          fit:BoxFit.cover,
          errorBuilder:(_,__,___) => Container(
            height:160, color:kLight,
            child:const Center(child:Text("Banner preview unavailable",style:TextStyle(color:kMuted,fontSize:12))),
          ),
        ),
      ),
      // Simulated phone UI preview — HIDDEN, replaced by mockup above
      if(false) Container(
        decoration:BoxDecoration(
          border:Border.all(color:kBorder),
          borderRadius:BorderRadius.circular(10),
        ),
        child:Column(children:[
          // Fake app header
          Container(height:28,decoration:const BoxDecoration(
            color:Color(0xFF3E5F55),
            borderRadius:BorderRadius.vertical(top:Radius.circular(9)),
          ),alignment:Alignment.center,child:const Text("OFFRO",style:TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.w800))),
          // Banner slot — highlighted
          Container(
            height:50,
            margin:const EdgeInsets.symmetric(horizontal:6,vertical:5),
            decoration:BoxDecoration(
              gradient:const LinearGradient(colors:[Color(0xFF3E5F55),Color(0xFFA9CDBA)]),
              borderRadius:BorderRadius.circular(8),
              border:Border.all(color:const Color(0xFFe67e22),width:2),
            ),
            alignment:Alignment.center,
            child:const Row(mainAxisAlignment:MainAxisAlignment.center,children:[
              Icon(Icons.arrow_upward,size:12,color:Colors.white),
              SizedBox(width:4),
              Text(">> YOUR BANNER HERE",style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800)),
            ]),
          ),
          // Fake content rows
          ...List.generate(2,(_)=>Container(height:14,margin:const EdgeInsets.fromLTRB(6,0,6,4),
            decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(4)))),
          const SizedBox(height:4),
        ]),
      ),
      const SizedBox(height:8),
      Row(children:[
        _InfoChip("📐 1200×400px"),
        const SizedBox(width:6),
        _InfoChip("📦 Max 2MB"),
        const SizedBox(width:6),
        _InfoChip("🖼️ JPG/PNG"),
      ]),
    ]),
  );
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip(this.text);
  @override Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
    decoration:BoxDecoration(color:kLight.withValues(alpha:.6),borderRadius:BorderRadius.circular(6)),
    child:Text(text,style:const TextStyle(fontSize:10,color:kPrimary,fontWeight:FontWeight.w600)),
  );
}

// ══════════════════════════════════════════════════════════
// ADD BANNER PAGE — with checkout flow
// ══════════════════════════════════════════════════════════

class AddBannerPage extends StatefulWidget {
  final String token;
  const AddBannerPage({super.key, required this.token});
  @override State<AddBannerPage> createState() => _AddBannerState();
}
class _AddBannerState extends State<AddBannerPage> {
  final _titleC    = TextEditingController();
  final _daysC     = TextEditingController(text:"30");
  final _discountC = TextEditingController();
  String? _imgB64; bool _loading = false; String _msg = "";
  DateTime _fromDate = DateTime.now();
  Map<String,dynamic>? _pricing;
  String? _selCity;
  // ── Store selection ──
  List<Map<String,dynamic>> _stores = [];
  Map<String,dynamic>? _selectedBannerStore;
  bool _storesLoading = false;
  // Discount code state
  String? _appliedCode; double _appliedDiscount = 0;
  String _discountMsg = ""; bool _discountOk = false; bool _applyingCode = false;

  @override void dispose() { _titleC.dispose(); _daysC.dispose(); _discountC.dispose(); _razorpay.clear(); super.dispose(); }

  Future<void> _loadPricing() async {
    try {
      final p = await Api.getBannerPricing(widget.token);
      if (mounted) setState(()=>_pricing=Map<String,dynamic>.from(p));
    } catch(_){}
  }

  int get _days => int.tryParse(_daysC.text.trim()) ?? 0;
  double get _pricePerDay => (_pricing?["price_per_day"] as num?)?.toDouble() ?? 15;
  double get _basePrice   => double.parse((_pricePerDay * _days).toStringAsFixed(2));
  double get _gstPct      => (_pricing?["gst_pct"] as num?)?.toDouble() ?? 18;
  double get _gst         => double.parse((_basePrice * _gstPct / 100).toStringAsFixed(2));
  double get _discountAmt => double.tryParse(_discountC.text.trim()) ?? 0;
  double get _total       => double.parse(((_basePrice - _discountAmt) + _gst).toStringAsFixed(2));

  String get _fromDateStr => "${_fromDate.year}-${_fromDate.month.toString().padLeft(2,'0')}-${_fromDate.day.toString().padLeft(2,'0')}";
  String get _fromDateDisplay => "${_fromDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_fromDate.month-1]} ${_fromDate.year}";
  DateTime get _endDate => _fromDate.add(Duration(days:_days));
  String get _endDateDisplay => "${_endDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_endDate.month-1]} ${_endDate.year}";

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(context:context, initialDate:_fromDate,
      firstDate:DateTime.now(), lastDate:DateTime.now().add(const Duration(days:365)));
    if(picked!=null) setState(()=>_fromDate=picked);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source:ImageSource.gallery,imageQuality:80,maxWidth:1200);
    if (img==null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content:Text("Image too large. Max 2MB."),backgroundColor:Colors.red));
      return;
    }
    setState(()=>_imgB64="data:image/jpeg;base64,${base64Encode(bytes)}");
  }

  Future<void> _proceed() async {
    if (_titleC.text.trim().isEmpty) { setState(()=>_msg="Banner title required"); return; }
    if (_selectedBannerStore==null) { setState(()=>_msg="Please select a store"); return; }
    if (_selCity==null || _selCity!.trim().isEmpty) { setState(()=>_msg="Please select a city"); return; }
    if (_imgB64==null) { setState(()=>_msg="Please upload a banner image"); return; }
    if (_days<1) { setState(()=>_msg="Enter number of days (minimum 1)"); return; }
    setState((){_loading=true; _msg="";});
    try {
      final order = await Api.createBannerOrder(widget.token, {
        "days":       _days,
        "from_date":  _fromDateStr,
        "discount_code": _appliedCode ?? "",
      });
      if (!mounted) return;
      final payMode = order["pay_mode"] ?? "manual";
      final amtPaise = (order["amount_paise"] as num?)?.toInt() ?? 0;

      if (payMode=="manual" || amtPaise<=0) {
        // Manual flow — show confirm dialog
        final confirmed = await _showBannerSummaryDialog(order, manual:true);
        if (confirmed==true && mounted) {
          final res = await Api.activateFreeBanner(widget.token, {
            "order_id":  order["order_id"],
            "title":     _titleC.text.trim(),
            "image_url": _imgB64,
            "city":      _selCity??"",
            "store_id":  (_selectedBannerStore?["_id"] ?? _selectedBannerStore?["id"] ?? "").toString(),
            "store_name":(_selectedBannerStore?["store_name"] ?? "").toString(),
          });
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:Text("✅ Banner submitted! ${res['message']??''}"),
              backgroundColor:const Color(0xFF1a6640)));
          }
        }
      } else {
        final confirmed = await _showBannerSummaryDialog(order, manual:false);
        if (confirmed==true && mounted) {
          _openRazorpayBanner(order);
        }
      }
    } catch(e) { setState(()=>_msg=e.toString().replaceAll("Exception:","").trim()); }
    if (mounted) setState(()=>_loading=false);
  }

  late Razorpay _razorpay;
  Map<String,dynamic>? _pendingOrder;

  @override void initState() {
    super.initState();
    _loadPricing();
    _loadBannerStores();
    _daysC.addListener(()=>setState((){}));
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
  }

  Future<void> _loadBannerStores() async {
    if (!mounted) return;
    setState(() => _storesLoading = true);
    try {
      final list = await Api.getMerchantStores(widget.token);
      if (mounted) setState(() {
        _stores = List<Map<String,dynamic>>.from(list);
        if (_stores.length == 1) _onBannerStoreSelected(_stores.first);
        _storesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  void _onBannerStoreSelected(Map<String,dynamic> store) {
    final city = (store["city"] ?? "").toString().trim();
    setState(() {
      _selectedBannerStore = store;
      if (city.isNotEmpty) _selCity = city;
    });
  }

  Future<void> _applyDiscountCode() async {
    final code = _discountC.text.trim();
    if (code.isEmpty) return;
    setState(() { _applyingCode = true; _discountMsg = ""; });
    try {
      final r = await Api.validateDiscountCode(widget.token, code);
      final val = (r["value"] as num).toDouble();
      setState(() {
        _appliedCode     = r["code"]?.toString() ?? code;
        _appliedDiscount = val;
        _discountOk      = true;
        _discountMsg     = r["message"]?.toString() ?? "✅ Discount applied!";
      });
    } catch (e) {
      setState(() {
        _appliedCode     = null;
        _appliedDiscount = 0;
        _discountOk      = false;
        _discountMsg     = e.toString().replaceAll("Exception: ", "");
      });
    }
    if (mounted) setState(() => _applyingCode = false);
  }

  void _openRazorpayBanner(Map order) {
    final rzpKey = order["razorpay_key"]?.toString() ?? '';
    final rzpOrderId = order["razorpay_order_id"]?.toString() ?? '';
    if (rzpKey.isEmpty || rzpOrderId.isEmpty) {
      setState(()=>_msg="Payment gateway not configured. Contact support.");
      return;
    }
    _pendingOrder = Map<String,dynamic>.from(order);
    // FIX 4: ensure amount is int and handle launch errors
    try {
      _razorpay.open({
        "key":         rzpKey,
        "amount":      (order["amount_paise"] as num?)?.toInt() ?? 0,
        "name":        "OFFRO",
        "description": "Banner – ${order['days']} Days",
        "order_id":    rzpOrderId,
        "prefill":     {"contact":"","email":""},
        "theme":       {"color":"#3E5F55"},
      });
    } catch (e) {
      if (mounted) setState(()=>_msg="Failed to open payment: $e");
    }
  }

  void _onPaySuccess(PaymentSuccessResponse res) async {
    if (_pendingOrder==null || !mounted) return;
    final captured = _pendingOrder;
    _pendingOrder = null;   // T1/T4: clear immediately to prevent double-fire
    try {
      final result = await Api.verifyBannerPayment(widget.token, {
        "order_id":           captured!["order_id"],
        "title":              _titleC.text.trim(),
        "image_url":          _imgB64,
        "city":               _selCity??"",
        "store_id":           (_selectedBannerStore?["_id"] ?? _selectedBannerStore?["id"] ?? "").toString(),
        "store_name":         (_selectedBannerStore?["store_name"] ?? "").toString(),
        "razorpay_payment_id": res.paymentId,
        "razorpay_order_id":  res.orderId,
        "razorpay_signature": res.signature,
      });
      if (mounted) {
        // FIX 3: Capture navigator before pushReplacement so onDone works after context deactivated
        final nav = Navigator.of(context);
        final invoiceNo = result["invoice_no"]?.toString() ?? result["message"]?.toString() ?? "";
        nav.pushReplacement(MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            storeName: _titleC.text.trim(),
            invoiceNo: invoiceNo,
            onDone: () => nav.popUntil((r) => r.isFirst),
          ),
        ));
      }
    } catch(e) { if(mounted) setState(()=>_msg=e.toString().replaceAll("Exception:","").trim()); }
  }

  void _onPayError(PaymentFailureResponse res) {
    if(mounted) setState(()=>_msg="Payment failed: ${res.message??'Unknown error'}");
  }

  Future<bool?> _showBannerSummaryDialog(Map order, {required bool manual}) async =>
    showDialog<bool>(context:context, builder:(_)=>AlertDialog(
      title:const Text("Banner Order Summary",style:TextStyle(color:kPrimary,fontWeight:FontWeight.bold)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        _dRow("Title",    _titleC.text.trim()),
        _dRow("Duration", "${order['days']} Days"),
        _dRow("Period",   "${order['from_date']} → ${order['end_date']}"),
        _dRow("Rate",     "₹${order['price_per_day']}/day"),
        const Divider(),
        _dRow("Base Price","₹${order['base_price']}"),
        if((order['discount_amount']??0)>0) _dRow("Discount","−₹${order['discount_amount']}",
          color:const Color(0xFF1a6640)),
        _dRow("GST (${order['gst_percent']}%)","₹${order['gst_amount']}"),
        _dRow("Total","₹${order['amount_display']}",bold:true),
        const SizedBox(height:10),
        Container(padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:kLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
          child:Text(manual
            ? "Your banner will be submitted for admin review after confirmation."
            : "Razorpay checkout will open. Banner goes live after admin approval.",
            style:const TextStyle(fontSize:12,color:kPrimary))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text("Cancel",style:TextStyle(color:kMuted))),
        ElevatedButton(
          style:ElevatedButton.styleFrom(backgroundColor:kPrimary),
          onPressed:()=>Navigator.pop(context,true),
          child:Text(manual?"Confirm Submit":"Pay ₹${order['amount_display']}",style:const TextStyle(color:Colors.white))),
      ],
    ));

  Widget _dRow(String k,String v,{bool bold=false,Color? color}) => Padding(
    padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[
      Expanded(child:Text(k,style:const TextStyle(color:kMuted,fontSize:13))),
      Text(v,style:TextStyle(fontSize:13,fontWeight:bold?FontWeight.bold:FontWeight.w500,color:color??(bold?kPrimary:kText))),
    ]));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(title:const Text("Create Banner"),backgroundColor: Colors.white, foregroundColor: kText),
    body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[

      // Title field
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Banner Title *",style:TextStyle(fontWeight:FontWeight.w700,color:kText,fontSize:13)),
          const SizedBox(height:8),
          TextField(controller:_titleC,decoration:InputDecoration(
            hintText:"e.g. 50% OFF at Raj Store",isDense:true,
            contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
          )),
        ])),
      const SizedBox(height:12),

      // ── Store selection (auto-fills city) ──
      if (_storesLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
        )
      else
        DropdownButtonFormField<Map<String,dynamic>>(
          isExpanded: true,
          value: _selectedBannerStore,
          hint: const Text("Select Store *"),
          items: _stores.map((s) => DropdownMenuItem<Map<String,dynamic>>(
            value: s,
            child: Text(s["store_name"]?.toString() ?? "Unnamed Store",
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (s) { if (s != null) _onBannerStoreSelected(s); },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.store, color: kMuted, size: 20),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
      const SizedBox(height: 12),

      // ── City (auto-filled from store) ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F9F6),
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.location_city, color: kMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            (_selCity != null && _selCity!.isNotEmpty) ? _selCity! : "City auto-filled from store",
            style: TextStyle(
              color: (_selCity != null && _selCity!.isNotEmpty) ? kText : kMuted,
              fontSize: 15))),
          if (_selCity != null && _selCity!.isNotEmpty)
            const Icon(Icons.check_circle, color: kPrimary, size: 18),
        ]),
      ),
      const SizedBox(height: 12),

      // Image upload
      GestureDetector(
        onTap:_pickImage,
        child:Container(
          height:110,
          decoration:BoxDecoration(
            color:Colors.white,
            borderRadius:BorderRadius.circular(12),
            border:Border.all(color:_imgB64!=null?kPrimary:kBorder,
              style:_imgB64!=null?BorderStyle.solid:BorderStyle.solid,width:_imgB64!=null?2:1),
          ),
          child:_imgB64!=null
            ? Stack(children:[
                ClipRRect(borderRadius:BorderRadius.circular(11),
                  child:Image.memory(base64Decode(_imgB64!.split(",").last),width:double.infinity,height:110,fit:BoxFit.cover)),
                Positioned(top:6,right:6,child:GestureDetector(
                  onTap:()=>setState(()=>_imgB64=null),
                  child:Container(padding:const EdgeInsets.all(4),
                    decoration:const BoxDecoration(color:Colors.red,shape:BoxShape.circle),
                    child:const Icon(Icons.close,color:Colors.white,size:14)))),
              ])
            : Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Icon(Icons.add_photo_alternate_outlined,size:36,color:kAccent),
                const SizedBox(height:6),
                const Text("Tap to upload banner image",style:TextStyle(color:kMuted,fontSize:13)),
                const SizedBox(height:3),
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[
                  _InfoChip("📐 1200×400px"),const SizedBox(width:6),_InfoChip("📦 Max 2MB"),
                ]),
              ]),
        )),
      const SizedBox(height:12),

      // Duration + From Date
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Duration & Start Date",style:TextStyle(fontWeight:FontWeight.w700,color:kText,fontSize:13)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:TextField(
              controller:_daysC,
              keyboardType:TextInputType.number,
              onChanged:(_)=>setState((){}),
              decoration:InputDecoration(
                labelText:"Number of Days",hintText:"e.g. 7",
                prefixIcon:const Icon(Icons.today_rounded,color:kMuted,size:18),
                filled:true,fillColor:kBg,isDense:true,
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
              ),
            )),
            const SizedBox(width:10),
            Expanded(child:GestureDetector(
              onTap:_pickFromDate,
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
                decoration:BoxDecoration(color:kBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
                child:Row(children:[
                  const Icon(Icons.event_rounded,size:18,color:kMuted),
                  const SizedBox(width:8),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Text("From Date",style:TextStyle(fontSize:11,color:kMuted)),
                    Text(_fromDateDisplay,style:const TextStyle(fontSize:13,color:kText,fontWeight:FontWeight.w600)),
                  ])),
                ]),
              ),
            )),
          ]),
          if(_days>0) Padding(padding:const EdgeInsets.only(top:10),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
              decoration:BoxDecoration(color:kLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
              child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                const Text("Active period:",style:TextStyle(fontSize:12,color:kMuted)),
                Text("$_fromDateDisplay → $_endDateDisplay",style:const TextStyle(fontSize:12,color:kPrimary,fontWeight:FontWeight.w600)),
              ]),
            )),
          if(_pricing!=null && _days>0) Padding(padding:const EdgeInsets.only(top:6),
            child:Text("₹${_pricePerDay.toStringAsFixed(0)}/day × $_days days",
              style:const TextStyle(fontSize:12,color:kMuted))),
        ])),
      const SizedBox(height:12),

      // Price summary
      if (_pricing!=null && _days>0)
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(12)),
          child:Column(children:[
            _dRow("Base Price","₹${_basePrice.toStringAsFixed(2)}"),
            _dRow("GST (${_gstPct.toInt()}%)","₹${_gst.toStringAsFixed(2)}"),
            const Divider(height:16),
            _dRow("Total","₹${_total.toStringAsFixed(2)}",bold:true),
          ])),

      const SizedBox(height:4),
      if (_msg.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:6),
        child:Text(_msg,style:const TextStyle(color:Colors.red,fontSize:12))),
      const SizedBox(height:12),

      // TASK 6 FIX: Discount code shown ABOVE Proceed to Checkout
      // Item 6: Discount code field
      Container(
        padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Discount Code",style:TextStyle(fontWeight:FontWeight.w700,color:kText,fontSize:13)),
          const SizedBox(height:4),
          const Text("Have a promo code? Enter it below.",style:TextStyle(color:kMuted,fontSize:11)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(
              controller:_discountC,
              textCapitalization:TextCapitalization.characters,
              onChanged:(_){ if((_appliedCode ?? "").isNotEmpty) setState((){_appliedCode="";_appliedDiscount=0;_discountMsg="";_discountOk=false;}); },
              decoration:InputDecoration(
                hintText:"e.g. OFFRO20",isDense:true,
                prefixIcon:const Icon(Icons.local_offer_outlined,color:kMuted,size:18),
                contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide(color:_discountOk?kPrimary:kBorder)),
              ),
            )),
            const SizedBox(width:8),
            ElevatedButton(
              onPressed:_applyingCode?null:_applyDiscountCode,
              style:ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kText,
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              child:_applyingCode
                ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Text("Apply",style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
            ),
          ]),
          if (_discountMsg.isNotEmpty) ...[
            const SizedBox(height:6),
            Text(_discountMsg,style:TextStyle(color:_discountOk?const Color(0xFF1a6640):Colors.red,fontWeight:FontWeight.w600,fontSize:12)),
          ],
          if (_appliedDiscount > 0) ...[
            const SizedBox(height:6),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(8)),
              child:Row(children:[
                const Icon(Icons.check_circle,color:Color(0xFF1a6640),size:14),
                const SizedBox(width:6),
                Text("−₹${_appliedDiscount.toStringAsFixed(0)} off  →  Total: ₹${_total.toStringAsFixed(2)}",
                  style:const TextStyle(color:Color(0xFF1a6640),fontWeight:FontWeight.w700,fontSize:12)),
              ]),
            ),
          ],
        ])),
      const SizedBox(height:16),
      const SizedBox(height:24),
      const SizedBox(height:12),

      ElevatedButton.icon(
        icon:_loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.arrow_forward_rounded),
        label:const Text("Proceed to Checkout"),
        style:ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kText,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
          padding:const EdgeInsets.symmetric(vertical:14)),
        onPressed:_loading?null:_proceed,
      ),
    ])),
  );
}

// ══════════════════════════════════════════════════════════
// MERCHANT PRODUCTS PAGE  (Phase 2 — redesigned)
// ══════════════════════════════════════════════════════════

class MerchantProductsPage extends StatefulWidget {
  final String token;
  const MerchantProductsPage({super.key, required this.token});
  @override State<MerchantProductsPage> createState() => _MerchantProductsState();
}

class _MerchantProductsState extends State<MerchantProductsPage> {
  List<Map<String,dynamic>> _products = [];
  List<Map<String,dynamic>> _filtered = [];
  List<Map<String,dynamic>> _stores   = [];   // for standard product store expiry
  bool _loading = true;

  final _searchCtrl = TextEditingController();
  String _activeFilter = "All";

  List<dynamic> _expiryWarnings = [];

  @override void initState() { super.initState(); _load(); }
  @override void dispose()   { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        Api.getMerchantProducts(widget.token),
        Api.checkProductExpiry(widget.token),
        Api.getMerchantStores(widget.token),   // needed for standard product store expiry
      ]);
      _products = List<Map<String,dynamic>>.from(results[0] as Iterable);
      final exp = results[1];
      _expiryWarnings = exp is Map ? ((exp["items"] ?? []) as List) : <dynamic>[];
      _stores = List<Map<String,dynamic>>.from(results[2] as Iterable);
    } catch (_) {}
    _applyFilters();
    if (mounted) setState(() => _loading = false);
  }

  // Returns formatted expiry label for a STANDARD product from the store's subscription_end.
  // subscription_end can be ISO "2026-07-22T00:00:00" or pre-formatted "22 Jul 2026".
  String _storeExpiryLabel(Map<String,dynamic> v) {
    final storeId = (v["store_id"] ?? "").toString();
    if (storeId.isEmpty) return "";
    try {
      final store = _stores.firstWhere((s) =>
        (s["_id"] ?? s["id"] ?? "").toString() == storeId);
      final raw = (store["subscription_end"] ?? "").toString().trim();
      if (raw.isEmpty) return "";
      return _parseDateLabel(raw);
    } catch (_) { return ""; }
  }

  // Parses any date string into "dd-mm-yyyy". Falls back to stripping the time portion.
  String _parseDateLabel(String raw) {
    if (raw.isEmpty) return "";
    try {
      final dt = DateTime.parse(raw);  // handles ISO: "2026-07-22T00:00:00"
      return "${dt.day.toString().padLeft(2,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.year}";
    } catch (_) {}
    // Already a readable string like "22 Jul 2026" — just strip any trailing time part
    return raw.contains("T") ? raw.split("T").first : raw;
  }

  // Parses ISO "2026-07-04" OR "04 Jul 2026" OR "04-07-2026" → DateTime
  DateTime? _parseAnyDate(String raw) {
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw); } catch (_) {}
    try {
      final parts = raw.trim().split(RegExp(r'[\s\-/]+'));
      if (parts.length >= 3) {
        const months = {"jan":1,"feb":2,"mar":3,"apr":4,"may":5,"jun":6,
                        "jul":7,"aug":8,"sep":9,"oct":10,"nov":11,"dec":12};
        // "dd MMM yyyy"
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

  String _effectiveStatus(Map<String,dynamic> v) {
    String st = (v["approval_status"] ?? v["status"] ?? "pending_approval")
        .toString().toLowerCase().trim();
    // Normalize all pending/waiting variants → "pending_approval"
    const pendingVariants = {"pending", "waiting_approval", "waiting",
                              "submitted", "new", "under_review", "in_review"};
    if (pendingVariants.contains(st)) st = "pending_approval";
    if (st == "approved") {
      final endRaw = v["end_date"]?.toString() ?? "";
      if (endRaw.isNotEmpty) {
        final dt = _parseAnyDate(endRaw);
        if (dt != null && DateTime.now().isAfter(dt)) st = "expired";
      }
    }
    return st;
  }

  void _applyFilters() {
    final q = _searchCtrl.text.toLowerCase();
    _filtered = _products.where((v) {
      final title = (v["title"] ?? "").toString().toLowerCase();
      final offer = (v["offer_text"] ?? "").toString().toLowerCase();
      final ptype = (v["product_type"] ?? "premium").toString();
      final st    = _effectiveStatus(v);
      if (q.isNotEmpty && !title.contains(q) && !offer.contains(q)) return false;
      switch (_activeFilter) {
        case "Standard":        return ptype == "standard";
        case "Premium":         return ptype != "standard";
        case "approved":        return st == "approved";
        case "pending_approval":return st == "pending_approval";
        case "expired":         return st == "expired";
        default:                return st != "expired";
      }
    }).toList();
  }

  String _pid(Map<String,dynamic> v) {
    final raw = v["_id"];
    return (raw is Map) ? (raw["\$oid"] ?? raw["oid"] ?? "").toString() : (raw ?? "").toString();
  }

  // ── Filter bottom sheet ──────────────────────────────────
  void _openFilter() {
    final opts = [
      ("All",              "All Products",         Icons.grid_view_rounded,         kText),
      ("Standard",         "Standard Only",        Icons.inventory_2_rounded,        const Color(0xFF1a6640)),
      ("Premium",          "Premium Only",         Icons.workspace_premium_rounded,  const Color(0xFF6B2FAA)),
      ("approved",         "Live",                 Icons.check_circle_rounded,       const Color(0xFF1a6640)),
      ("pending_approval", "Pending Approval",     Icons.hourglass_top_rounded,      const Color(0xFF856404)),
      ("expired",          "Expired",              Icons.event_busy_rounded,         Colors.red),
    ];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Filter Products", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: kText)),
            const SizedBox(height: 14),
            ...opts.map((o) {
              final selected = _activeFilter == o.$1;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: (selected ? o.$4 : kBorder).withValues(alpha: .15),
                  child: Icon(o.$3, color: selected ? o.$4 : kMuted, size: 18)),
                title: Text(o.$2, style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? o.$4 : kText, fontSize: 14)),
                trailing: selected ? Icon(Icons.check_rounded, color: o.$4, size: 20) : null,
                onTap: () {
                  setState(() { _activeFilter = o.$1; _applyFilters(); });
                  Navigator.pop(context);
                },
              );
            }),
          ]),
        ),
      ),
    );
  }

  // ── On/Off toggle (optimistic) ──────────────────────────
  Future<void> _toggleActive(Map<String,dynamic> v, String pid) async {
    final current = v["is_active"] as bool? ?? true;
    setState(() { v["is_active"] = !current; _applyFilters(); });
    try {
      await Api.setProductAvailability(widget.token, pid, !current);
    } catch (e) {
      if (mounted) setState(() { v["is_active"] = current; _applyFilters(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Toggle failed: $e"), backgroundColor: Colors.red));
    }
  }

  // ── Full-screen image viewer ─────────────────────────────
  void _showImageFullscreen(BuildContext ctx, String logoUrl) {
    if (logoUrl.isEmpty) return;
    showDialog(context: ctx, builder: (_) => Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(children: [
        Center(child: InteractiveViewer(
          child: logoUrl.startsWith("data:image")
            ? Image.memory(base64Decode(logoUrl.split(",").last), fit: BoxFit.contain)
            : Image.network(logoUrl, fit: BoxFit.contain,
                errorBuilder: (_,__,___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64)),
        )),
        Positioned(top: 44, right: 16, child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: Colors.white, size: 22)))),
      ]),
    ));
  }

  // ── More actions bottom sheet ────────────────────────────
  void _openMore(Map<String,dynamic> v, String pid) {
    final isStd = (v["product_type"] ?? "premium").toString() == "standard";
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(v["title"] ?? "Product",
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kText)),
            const SizedBox(height: 4),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFe8f4ef),
                child: Icon(Icons.edit_rounded, color: kPrimary, size: 18)),
              title: const Text("Edit Product", style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () { Navigator.pop(context); _showEditDialog(v, pid); }),
            // FIX3: Analytics & Activity only for Premium
            if (pid.isNotEmpty && !isStd)
              ListTile(
                leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFFF3CD),
                  child: Icon(Icons.bar_chart_rounded, color: Color(0xFF856404), size: 18)),
                title: const Text("Analytics", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context);
                  Navigator.push(context, _offroRoute(ProductAnalyticsPage(token: widget.token, product: v))); }),
            if (pid.isNotEmpty && !isStd)
              ListTile(
                leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFF0F0F0),
                  child: Icon(Icons.history_rounded, color: kMuted, size: 18)),
                title: const Text("Activity History", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context);
                  Navigator.push(context, _offroRoute(ProductHistoryPage(token: widget.token, product: v))); }),
            ListTile(
              leading: const CircleAvatar(radius: 18, backgroundColor: Color(0xFFFFEBEB),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18)),
              title: const Text("Delete Product", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () { Navigator.pop(context); _confirmDelete(v, pid); }),
            const SizedBox(height: 4),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _activeFilter != "All";
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Row(children: [
          buildImageLogo(height: 24, white: true),
          const SizedBox(width: 8),
          const Text("My Products", style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        backgroundColor: Colors.white, foregroundColor: kText,
        actions: [
          // Filter button with active indicator
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              color: hasFilter ? kPrimary : kMuted,
              tooltip: "Filter",
              onPressed: _openFilter,
            ),
            if (hasFilter)
              Positioned(top: 8, right: 8,
                child: Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle))),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white, foregroundColor: kText,
        icon: const Icon(Icons.add),
        label: const Text("New Product"),
        onPressed: () => _showProductTypeDialog(context, widget.token, _load),
      ),
      body: Column(children: [
        // ── Expiry warning banner ──
        if (_expiryWarnings.isNotEmpty) ExpiryWarningBanner(
          expiring: List<Map<String,dynamic>>.from(
              _expiryWarnings.whereType<Map>().map((e) => Map<String,dynamic>.from(e))),
          onRenewTap: () => setState(() { _activeFilter = "expired"; _applyFilters(); }),
        ),

        // ── Search + active filter chip ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(_applyFilters),
              decoration: InputDecoration(
                hintText: "Search products…",
                hintStyle: const TextStyle(color: kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: kMuted, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18, color: kMuted),
                        onPressed: () { _searchCtrl.clear(); setState(_applyFilters); })
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true, fillColor: Colors.white,
                border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
              ),
            )),
          ]),
        ),
        // Active filter label
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kPrimary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary.withValues(alpha: .3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.filter_list_rounded, size: 13, color: kPrimary),
                  const SizedBox(width: 5),
                  Text(_activeFilter == "approved" ? "Live"
                    : _activeFilter == "pending_approval" ? "Pending"
                    : _activeFilter == "expired" ? "Expired"
                    : _activeFilter,
                    style: const TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() { _activeFilter = "All"; _applyFilters(); }),
                    child: const Icon(Icons.close_rounded, size: 13, color: kPrimary)),
                ]),
              ),
              const Spacer(),
              Text("${_filtered.length} result${_filtered.length == 1 ? '' : 's'}",
                style: const TextStyle(fontSize: 12, color: kMuted)),
            ]),
          ),
        const SizedBox(height: 8),

        // ── List ──
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _filtered.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.local_activity_outlined, size: 64, color: kAccent),
                  const SizedBox(height: 12),
                  Text(_products.isEmpty ? "No products yet" : "No matching products",
                    style: const TextStyle(color: kMuted, fontSize: 16)),
                  if (_products.isEmpty)
                    const Padding(padding: EdgeInsets.only(top: 6),
                      child: Text("Tap + New Product to get started",
                        style: TextStyle(color: kMuted, fontSize: 13))),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildCard(_filtered[i]),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _buildCard(Map<String,dynamic> v) {
    final pType    = (v["product_type"] ?? "premium").toString();
    final isStd    = pType == "standard";
    final pid      = _pid(v);
    final status   = _effectiveStatus(v);
    final endRaw   = v["end_date"]?.toString() ?? "";
    final isActive = v["is_active"] as bool? ?? true;

    final isExpired  = status == "expired";
    final isApproved = status == "approved";

    // ── Status badge ──
    final (Color sc, String sl, IconData si) = isStd
        ? switch(status) {
            "approved"             => (const Color(0xFF1a6640), "Live",    Icons.check_circle_rounded),
            "subscription_expired" => (Colors.grey.shade600,    "Paused",  Icons.pause_circle_rounded),
            _                      => (const Color(0xFF856404), "Pending", Icons.hourglass_top_rounded),
          }
        : switch(status) {
            "approved"         => (const Color(0xFF1a6640), "Live",    Icons.check_circle_rounded),
            "rejected"         => (Colors.red,              "Rejected",Icons.cancel_rounded),
            "expired"          => (Colors.red.shade400,     "Expired", Icons.event_busy_rounded),
            "pending_approval" => (const Color(0xFF856404), "Pending", Icons.hourglass_top_rounded),
            _                  => (const Color(0xFF856404), "Pending", Icons.hourglass_top_rounded),
          };

    // Expiry: standard → store subscription end, premium → product end_date
    String expiryLabel = "";
    if (isStd) {
      expiryLabel = _storeExpiryLabel(v);
    } else if (endRaw.isNotEmpty) {
      expiryLabel = _parseDateLabel(endRaw);
    }

    final logoUrl = v["logo_url"]?.toString() ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStd
            ? const Color(0xFF1a6640).withValues(alpha: .18)
            : const Color(0xFF6B2FAA).withValues(alpha: .18)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Row 1: image + info + More button ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // FIX2: Square image — tap to enlarge
            GestureDetector(
              onTap: () => _showImageFullscreen(context, logoUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72, height: 72,
                  child: _ProductThumb(logoUrl: logoUrl),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info column
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Type badge + status badge
              Row(children: [
                _TypeBadge(isStd: isStd),
                const SizedBox(width: 6),
                _StatusBadge(label: sl, color: sc, icon: si),
              ]),
              const SizedBox(height: 6),
              Text(v["title"] ?? "",
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kText),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              if ((v["offer_text"] ?? "").toString().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(v["offer_text"].toString(),
                  style: const TextStyle(fontSize: 12, color: kMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              // FIX1: Expiry for both std and premium (if end_date exists)
              if (expiryLabel.isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.event_rounded, size: 11,
                    color: isExpired ? Colors.red : kMuted),
                  const SizedBox(width: 3),
                  Text("Expires: $expiryLabel",
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isExpired ? Colors.red : kMuted)),
                ]),
              ],
              // FIX1: price line removed
            ])),

            // More button + FIX4: On/Off toggle stacked vertically
            Column(children: [
              GestureDetector(
                onTap: () => _openMore(v, pid),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kBorder)),
                  child: const Icon(Icons.more_vert_rounded, size: 18, color: kMuted),
                ),
              ),
              const SizedBox(height: 6),
              // FIX4: On/Off switch
              Transform.scale(
                scale: 0.75,
                child: Switch(
                  value: isActive,
                  onChanged: pid.isEmpty ? null : (_) => _toggleActive(v, pid),
                  activeColor: kPrimary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Text(isActive ? "On" : "Off",
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: isActive ? kPrimary : kMuted)),
            ]),
          ]),

          // ── Row 2: CTA buttons ──
          const SizedBox(height: 10),
          if (isStd && v["upgraded"] != true)
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF856404),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.upgrade_rounded, size: 16),
                label: const Text("Upgrade Now", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => Navigator.push(context,
                  _offroRoute(UpgradeProductPage(token: widget.token, product: v))).then((_) => _load()),
              )),
          if (!isStd && (isApproved || isExpired))
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExpired ? Colors.red.shade600 : const Color(0xFF856404),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.autorenew_rounded, size: 16),
                label: Text(
                  expiryLabel.isNotEmpty
                    ? "Renew Now  ·  Expires: $expiryLabel"
                    : "Renew Now",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => Navigator.push(context,
                  _offroRoute(RenewProductPage(token: widget.token, product: v))).then((_) => _load()),
              )),
        ]),
      ),
    );
  }

  Future<void> _showEditDialog(Map<String,dynamic> v, String pid) async {
    final tCtrl  = TextEditingController(text: v["title"] ?? "");
    final oCtrl  = TextEditingController(text: v["offer_text"] ?? "");
    final opCtrl = TextEditingController(text: (v["original_price"] ?? v["original_amount"] ?? "").toString());
    final prCtrl = TextEditingController(text: (v["price"] ?? v["offer_price"] ?? v["amount"] ?? "").toString());
    final saved  = await showDialog<Map<String,dynamic>>(context: context, builder: (_) => AlertDialog(
      title: const Text("Edit Product", style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _EditField(ctrl: tCtrl,  label: "Title"),
        const SizedBox(height: 10),
        _EditField(ctrl: oCtrl,  label: "Offer Text"),
        const SizedBox(height: 10),
        _EditField(ctrl: opCtrl, label: "Original Price", type: TextInputType.number),
        const SizedBox(height: 10),
        _EditField(ctrl: prCtrl, label: "Offer Price",    type: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: kMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
          onPressed: () {
            final opVal = double.tryParse(opCtrl.text.trim());
            final prVal = double.tryParse(prCtrl.text.trim());
            Navigator.pop(context, <String,dynamic>{
              "title": tCtrl.text.trim(),
              "offer_text": oCtrl.text.trim(),
              if (opVal != null) "original_price": opVal,
              if (prVal != null) "price": prVal,
              if (prVal != null) "amount": prVal,
            });
          },
          child: const Text("Save", style: TextStyle(color: Colors.white))),
      ],
    ));
    if (saved != null && saved.isNotEmpty) {
      try {
        if (pid.isEmpty) throw Exception("Product ID missing — cannot update");
        await Api.updateMerchantProduct(widget.token, pid, saved);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product updated!"), backgroundColor: Color(0xFF1a6640)));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception: ','')}"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDelete(Map<String,dynamic> v, String pid) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text("Delete Product?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text("Delete \"${v['title'] ?? 'this product'}\"? This cannot be undone."),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel", style: TextStyle(color: kMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Delete", style: TextStyle(color: Colors.white))),
      ],
    ));
    if (confirm == true && mounted) {
      try {
        await Api.deleteMerchantProduct(widget.token, pid);
        _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Product deleted."), backgroundColor: Colors.red));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting: ${e.toString().replaceAll('Exception: ','')}"), backgroundColor: Colors.red));
      }
    }
  }
}

// ── Compact type badge ──────────────────────────────────────────────────────
class _TypeBadge extends StatelessWidget {
  final bool isStd;
  const _TypeBadge({required this.isStd});
  @override Widget build(BuildContext context) {
    final color = isStd ? const Color(0xFF1a6640) : const Color(0xFF6B2FAA);
    final label = isStd ? "Standard" : "Premium";
    final icon  = isStd ? Icons.inventory_2_rounded : Icons.workspace_premium_rounded;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Compact status badge ────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge({required this.label, required this.color, required this.icon});
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  );
}

// ── Compact action button ──────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ── String capitalize extension ────────────────────────────────────────────
extension _Capitalize on String {
  String capitalize() => isEmpty ? this : "${this[0].toUpperCase()}${substring(1)}";
}

// ── Product type choice dialog + navigation ──────────────────────────────────
void _showProductTypeDialog(BuildContext context, String token, VoidCallback onRefresh) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Choose Product Type", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: kText)),
          const SizedBox(height:6),
          const Text("Select the type of product you want to create.", style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 20),
          // Standard product option
          InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, _offroRoute(StandardProductPage(token: token))).then((_) => onRefresh());
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF1a6640).withValues(alpha: .4)),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFf0faf4),
              ),
              child: Row(children: [
                Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFF1a6640),borderRadius:BorderRadius.circular(12)),
                  child:const Icon(Icons.inventory_2_rounded, color:Colors.white, size:24)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("🟢 Standard Product", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kText)),
                  const SizedBox(height:3),
                  const Text("Free • Linked to your store subscription\nAdmin approval required, no payment needed", style: TextStyle(fontSize: 12, color: kMuted)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: kMuted),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          // Premium product option
          InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, _offroRoute(AddProductPage(token: token))).then((_) => onRefresh());
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6B2FAA).withValues(alpha: .4)),
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFF5F0FF),
              ),
              child: Row(children: [
                Container(width:44,height:44,decoration:BoxDecoration(color:const Color(0xFF6B2FAA),borderRadius:BorderRadius.circular(12)),
                  child:const Icon(Icons.workspace_premium_rounded, color:Colors.white, size:24)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("🟣 Premium Product", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: kText)),
                  const SizedBox(height:3),
                  const Text("Paid • Featured in Discover Products section\nAdmin approval required after payment", style: TextStyle(fontSize: 12, color: kMuted)),
                ])),
                const Icon(Icons.chevron_right_rounded, color: kMuted),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}

// ── Inline edit field helper ──
class _EditField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType type;
  const _EditField({required this.ctrl, required this.label, this.type = TextInputType.text});
  @override Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: type,
    decoration: InputDecoration(
      labelText: label, isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
    ));
}

// ── Product image thumbnail — handles both URL and base64 ──
class _ProductThumb extends StatelessWidget {
  final String logoUrl;
  const _ProductThumb({required this.logoUrl});
  @override Widget build(BuildContext context) {
    if (logoUrl.isEmpty) {
      return Container(width:48,height:48,
        decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(10)),
        child:const Icon(Icons.local_activity,color:kPrimary,size:24));
    }
    if (logoUrl.startsWith("data:image")) {
      try {
        final bytes = base64Decode(logoUrl.split(",").last);
        return ClipRRect(borderRadius:BorderRadius.circular(10),
          child:Image.memory(bytes,width:48,height:48,fit:BoxFit.cover,
            errorBuilder:(_,__,___) => Container(width:48,height:48,
              decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(10)),
              child:const Icon(Icons.local_activity,color:kPrimary,size:24))));
      } catch (_) {
        return Container(width:48,height:48,
          decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(10)),
          child:const Icon(Icons.local_activity,color:kPrimary,size:24));
      }
    }
    return Container(width:48,height:48,
      decoration:BoxDecoration(
        color:kLight.withValues(alpha:.5),
        borderRadius:BorderRadius.circular(10),
        image:DecorationImage(image:NetworkImage(logoUrl),fit:BoxFit.cover),
      ));
  }
}

// ── Product placement preview widget ──
class _ProductPlacementPreview extends StatelessWidget {
  const _ProductPlacementPreview();
  @override Widget build(BuildContext context) => Container(
    margin:const EdgeInsets.fromLTRB(14,14,14,0),
    padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(
      color:Colors.white,
      borderRadius:BorderRadius.circular(14),
      border:Border.all(color:const Color(0xFF856404),width:1.5),
    ),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Icon(Icons.info_outline,size:15,color:Color(0xFF856404)),
        const SizedBox(width:6),
        const Text("Where your product appears",style:TextStyle(fontWeight:FontWeight.w700,color:Color(0xFF856404),fontSize:13)),
      ]),
      const SizedBox(height:10),
      // FIX 13: Real OFFRO app mockup image
      ClipRRect(
        borderRadius:BorderRadius.circular(10),
        child:Image.network(
          "https://media.base44.com/images/public/69dc008cb5876dcb8680be38/0d2c11ece_generated_image.png",
          width:double.infinity, height:160, fit:BoxFit.cover,
          errorBuilder:(_,__,___) => Container(
            height:160,color:kLight,
            child:const Center(child:Text("Product preview unavailable",style:TextStyle(color:kMuted,fontSize:12)))),
        ),
      ),
      // Simulated Product Zone preview — hidden
      if(false) Container(
        decoration:BoxDecoration(border:Border.all(color:kBorder),borderRadius:BorderRadius.circular(10)),
        child:Column(children:[
          Container(height:22,decoration:const BoxDecoration(
            color:Color(0xFF3E5F55),
            borderRadius:BorderRadius.vertical(top:Radius.circular(9)),
          ),alignment:Alignment.centerLeft,padding:const EdgeInsets.only(left:8),
          child:const Text("🎟️ Discover Products",style:TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w800))),
          Container(height:56,padding:const EdgeInsets.symmetric(vertical:4,horizontal:6),
            child:Row(children:[
              // Fake product cards
              ...List.generate(2,(_)=>Container(
                width:52,margin:const EdgeInsets.only(right:6),
                decoration:BoxDecoration(color:kLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
              )),
              // Highlighted slot
              Container(
                width:52,
                decoration:BoxDecoration(
                  color:const Color(0xFFfff3cd),
                  borderRadius:BorderRadius.circular(8),
                  border:Border.all(color:const Color(0xFF856404),width:2),
                ),
                child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  const Icon(Icons.location_on,size:10,color:Color(0xFF856404)),
                  const Text("YOURS",textAlign:TextAlign.center,
                    style:TextStyle(fontSize:7,fontWeight:FontWeight.w800,color:Color(0xFF856404))),
                ]),
              ),
            ])),
          const SizedBox(height:4),
        ]),
      ),
      const SizedBox(height:8),
      Row(children:[
        _InfoChip("📐 400×400px"),
        const SizedBox(width:6),
        _InfoChip("📦 Max 1MB"),
        const SizedBox(width:6),
        _InfoChip("🖼️ PNG/JPG"),
      ]),
    ]),
  );
}

// ══════════════════════════════════════════════════════════
// STANDARD PRODUCT PAGE — free, subscription-linked, no payment
// ══════════════════════════════════════════════════════════

class StandardProductPage extends StatefulWidget {
  final String token;
  const StandardProductPage({super.key, required this.token});
  @override State<StandardProductPage> createState() => _StandardProductState();
}
class _StandardProductState extends State<StandardProductPage> {
  final _titleC       = TextEditingController();
  final _offerC       = TextEditingController();
  final _priceC       = TextEditingController();
  final _origPriceC   = TextEditingController();
  String? _logoB64;
  String? _selCity;
  List<Map<String,dynamic>> _stores = [];
  Map<String,dynamic>? _selectedStore;
  bool _loading = false;
  bool _storesLoading = false;
  String _msg = "";
  Map<String,dynamic> _limitInfo = {"standard_product_limit":10,"standard_count":0};

  @override void initState() {
    super.initState();
    _loadStores();
    _loadLimit();
  }

  @override void dispose() {
    _titleC.dispose(); _offerC.dispose(); _priceC.dispose(); _origPriceC.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    if (!mounted) return;
    setState(() => _storesLoading = true);
    try {
      final list = await Api.getMerchantStores(widget.token);
      if (mounted) setState(() {
        _stores = List<Map<String,dynamic>>.from(list);
        if (_stores.length == 1) _onStoreSelected(_stores.first);
        _storesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  Future<void> _loadLimit() async {
    try {
      final info = await Api.getProductLimit(widget.token);
      if (mounted) setState(() => _limitInfo = info);
    } catch (_) {}
  }

  void _onStoreSelected(Map<String,dynamic> store) {
    final city = (store["city"] ?? "").toString().trim();
    setState(() {
      _selectedStore = store;
      if (city.isNotEmpty) _selCity = city;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 400);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 1 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Logo too large. Max 1MB."), backgroundColor: Colors.red));
      return;
    }
    setState(() => _logoB64 = "data:image/jpeg;base64,${base64Encode(bytes)}");
  }

  Future<void> _submit() async {
    if (_titleC.text.trim().isEmpty) { setState(() => _msg = "Product title required"); return; }
    if (_selectedStore == null) { setState(() => _msg = "Please select a store for this product"); return; }
    if (_logoB64 == null) { setState(() => _msg = "Please upload a product image"); return; }

    final limit = (_limitInfo["standard_product_limit"] as num?)?.toInt() ?? 10;
    final count = (_limitInfo["standard_count"] as num?)?.toInt() ?? 0;
    if (count >= limit) {
      setState(() => _msg = "Standard product limit reached ($limit). Delete an existing product or use Premium.");
      return;
    }

    setState(() { _loading = true; _msg = ""; });
    try {
      final storeId = (_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString();
      final result = await Api.createStandardProduct(widget.token, {
        "title":          _titleC.text.trim(),
        "offer_text":     _offerC.text.trim(),
        "logo_url":       _logoB64 ?? "",
        "price":          _priceC.text.trim(),
        "original_price": _origPriceC.text.trim(),
        "store_id":       storeId,
        "store_name":     (_selectedStore?["store_name"] ?? "").toString(),
        "city":           _selCity ?? "",
        "is_active":      true,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("✅ ${result['message'] ?? 'Standard product created!'}"),
            backgroundColor: const Color(0xFF1a6640)));
      }
    } catch (e) {
      setState(() => _msg = e.toString().replaceAll("Exception:", "").trim());
    }
    if (mounted) setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) {
    final limit = (_limitInfo["standard_product_limit"] as num?)?.toInt() ?? 10;
    final count = (_limitInfo["standard_count"] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Row(children: [
          buildImageLogo(height: 24, white: true),
          const SizedBox(width: 8),
          const Text("Standard Product", style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        backgroundColor: Colors.white, foregroundColor: kText,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFf0faf4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1a6640).withValues(alpha: .3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("🟢 Standard Product", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1a6640))),
              const SizedBox(height: 4),
              const Text("• Free — no payment required\n• Linked to your store subscription\n• Admin approval required before going live\n• Paused automatically when subscription expires", style: TextStyle(fontSize: 12, color: kMuted)),
              const SizedBox(height: 8),
              Text("Usage: $count / $limit standard products", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
            ]),
          ),
          const SizedBox(height: 20),
          // Store selector
          const Text("Select Store *", style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
          const SizedBox(height: 6),
          _storesLoading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _stores.isEmpty
                  ? const Text("No stores found. Create a store first.", style: TextStyle(color: Colors.red, fontSize: 13))
                  : DropdownButtonFormField<Map<String,dynamic>>(
                      value: _selectedStore,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                      ),
                      hint: const Text("Select a store"),
                      items: _stores.map((s) => DropdownMenuItem(value: s, child: Text(s["store_name"]?.toString() ?? ""))).toList(),
                      onChanged: (s) { if (s != null) _onStoreSelected(s); },
                    ),
          const SizedBox(height: 16),
          // Product title
          const Text("Product Title *", style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _titleC,
            decoration: InputDecoration(
              hintText: "e.g. Flat 20% Off on All Items",
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
            ),
          ),
          const SizedBox(height: 16),
          // Offer text
          const Text("Offer Text", style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _offerC,
            decoration: InputDecoration(
              hintText: "e.g. Valid on all products",
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
            ),
          ),
          const SizedBox(height: 16),
          // Price row
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Offer Price", style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _priceC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "₹ 99",
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Original Price", style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _origPriceC,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "₹ 199",
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 16),
          // Logo
          const Text("Product Image *", style: TextStyle(fontWeight: FontWeight.w600, color: kText, fontSize: 13)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              height: 80, width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFf5f5f5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: _logoB64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(base64Decode(_logoB64!.split(',').last), fit: BoxFit.cover))
                  : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.add_photo_alternate_outlined, color: kMuted, size: 28),
                      SizedBox(height: 4),
                      Text("Tap to upload", style: TextStyle(color: kMuted, fontSize: 12)),
                    ]),
            ),
          ),
          if (_msg.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_msg, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a6640),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Create Standard Product", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// ADD PRODUCT PAGE — with checkout flow
// ══════════════════════════════════════════════════════════

class AddProductPage extends StatefulWidget {
  final String token;
  const AddProductPage({super.key, required this.token});
  @override State<AddProductPage> createState() => _AddProductState();
}
class _AddProductState extends State<AddProductPage> {
  final _titleC          = TextEditingController();
  final _offerC          = TextEditingController();
  final _priceC          = TextEditingController();
  final _originalPriceC  = TextEditingController();
  final _daysC      = TextEditingController(text:"30");
  final _discountVC = TextEditingController(); // discount code input
  String? _logoB64; bool _loading=false; String _msg="";
  DateTime _fromDate = DateTime.now();
  Map<String,dynamic>? _pricing;
  String? _selCity;
  // ── Store selection ──
  List<Map<String,dynamic>> _stores = [];
  Map<String,dynamic>? _selectedStore;
  bool _storesLoading = false;
  late Razorpay _razorpay;
  Map<String,dynamic>? _pendingOrder;
  // Item 6: code-based discount
  bool   _applyingVCode    = false;
  String _appliedVCode     = "";
  double _appliedVDiscount = 0.0;
  String _discountVMsg     = "";
  bool   _discountVOk      = false;

  @override void initState() {
    super.initState();
    _loadPricing();
    _loadStores();
    _daysC.addListener(()=>setState((){}));
    _razorpay=Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS,_onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,  _onPayError);
  }

  Future<void> _loadStores() async {
    if (!mounted) return;
    setState(() => _storesLoading = true);
    try {
      final list = await Api.getMerchantStores(widget.token);
      if (mounted) setState(() {
        _stores = List<Map<String,dynamic>>.from(list);
        if (_stores.length == 1) _onStoreSelected(_stores.first);
        _storesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _storesLoading = false);
    }
  }

  void _onStoreSelected(Map<String,dynamic> store) {
    final city = (store["city"] ?? "").toString().trim();
    setState(() {
      _selectedStore = store;
      if (city.isNotEmpty) _selCity = city;
    });
  }
  @override void dispose(){ _titleC.dispose();_offerC.dispose();_priceC.dispose();_originalPriceC.dispose();_daysC.dispose();_discountVC.dispose(); _razorpay.clear(); super.dispose(); }

  Future<void> _loadPricing() async {
    try{ final p=await Api.getProductPricing(widget.token); if(mounted) setState(()=>_pricing=Map<String,dynamic>.from(p)); }catch(_){}
  }

  int get _days => int.tryParse(_daysC.text.trim()) ?? 0;
  double get _pricePerDay=>(_pricing?["price_per_day"] as num?)?.toDouble()??10;
  double get _basePrice => double.parse((_pricePerDay * _days).toStringAsFixed(2));
  double get _gstPct=>(_pricing?["gst_pct"] as num?)?.toDouble()??18;
  double get _gst=>double.parse((_basePrice*_gstPct/100).toStringAsFixed(2));
  double get _discountVAmt => _appliedVDiscount;
  double get _total=>double.parse((_basePrice-_appliedVDiscount+_gst).toStringAsFixed(2));

  String get _fromDateStr=>"${_fromDate.year}-${_fromDate.month.toString().padLeft(2,'0')}-${_fromDate.day.toString().padLeft(2,'0')}";
  String get _fromDateDisplay=>"${_fromDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_fromDate.month-1]} ${_fromDate.year}";
  DateTime get _endDate=>_fromDate.add(Duration(days:_days));
  String get _endDateDisplay=>"${_endDate.day} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][_endDate.month-1]} ${_endDate.year}";

  Future<void> _pickFromDate() async {
    final picked=await showDatePicker(context:context,initialDate:_fromDate,
      firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));
    if(picked!=null) setState(()=>_fromDate=picked);
  }

  Future<void> _pickLogo() async {
    final picker=ImagePicker();
    final img=await picker.pickImage(source:ImageSource.gallery,imageQuality:80,maxWidth:400);
    if(img==null)return;
    final bytes=await File(img.path).readAsBytes();
    if(bytes.length>1*1024*1024){
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text("Logo too large. Max 1MB."),backgroundColor:Colors.red));
      return;
    }
    setState(()=>_logoB64="data:image/jpeg;base64,${base64Encode(bytes)}");
  }


  // Item 6: Apply discount code — product
  Future<void> _applyVDiscountCode() async {
    final code = _discountVC.text.trim().toUpperCase();
    if (code.isEmpty) { setState((){ _discountVMsg="Enter a code"; _discountVOk=false; }); return; }
    setState(()=>_applyingVCode=true);
    try {
      final res = await Api.validateDiscountCode(widget.token, code);
      final val = (res["value"] as num?)?.toDouble() ?? 0.0;
      if (mounted) setState((){
        _appliedVCode     = code;
        _appliedVDiscount = val;
        _discountVMsg     = "✅ Code applied — ₹${val.toStringAsFixed(0)} off!";
        _discountVOk      = true;
        _applyingVCode    = false;
      });
    } catch (e) {
      if (mounted) setState((){
        _appliedVCode     = "";
        _appliedVDiscount = 0;
        _discountVMsg     = e.toString().replaceAll("Exception: ","");
        _discountVOk      = false;
        _applyingVCode    = false;
      });
    }
  }


  Future<void> _proceed() async {
    if(_titleC.text.trim().isEmpty){setState(()=>_msg="Product title required");return;}
    if(_selectedStore==null){setState(()=>_msg="Please select a store for this product");return;}
    if(_selCity==null||_selCity!.trim().isEmpty){setState(()=>_msg="Please select a city for this product");return;}
    if(_logoB64==null){setState(()=>_msg="Please upload a product image");return;}
    if(_days<1){setState(()=>_msg="Enter number of days (minimum 1)");return;}
    setState((){_loading=true;_msg="";});
    try{
      final order=await Api.createProductOrder(widget.token,{"days":_days,"from_date":_fromDateStr,"discount_code":_appliedVCode});
      if(!mounted)return;
      final payMode=order["pay_mode"]??"manual";
      final amtPaise=(order["amount_paise"] as num?)?.toInt()??0;

      if(payMode=="manual"||amtPaise<=0){
        final confirmed=await _showProductSummaryDialog(order,manual:true);
        if(confirmed==true&&mounted){
          final res=await Api.activateFreeProduct(widget.token,{
            "order_id":       order["order_id"],
            "title":          _titleC.text.trim(),
            "offer_text":     _offerC.text.trim(),
            "logo_url":       _logoB64??"",
            "price":          _priceC.text.trim(),
            "original_price": _originalPriceC.text.trim(),
            "store_id":       (_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString(),
            "store_name":     (_selectedStore?["store_name"] ?? "").toString(),
            "city":           _selCity ?? "",
          });
          if(mounted){
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:Text("✅ Product submitted! ${res['message']??''}"),
              backgroundColor:const Color(0xFF1a6640)));
          }
        }
      } else {
        final confirmed=await _showProductSummaryDialog(order,manual:false);
        if(confirmed==true&&mounted) _openRazorpay(order);
      }
    }catch(e){setState(()=>_msg=e.toString().replaceAll("Exception:","").trim());}
    if(mounted)setState(()=>_loading=false);
  }

  void _openRazorpay(Map order){
    final rzpKey = order["razorpay_key"]?.toString() ?? '';
    final rzpOrderId = order["razorpay_order_id"]?.toString() ?? '';
    if (rzpKey.isEmpty || rzpOrderId.isEmpty) {
      setState(()=>_msg="Payment gateway not configured. Contact support.");
      return;
    }
    _pendingOrder=Map<String,dynamic>.from(order);
    // FIX 4: ensure amount is int and handle launch errors
    try {
    _razorpay.open({
      "key":rzpKey,
      "amount":(order["amount_paise"] as num?)?.toInt()??0,
      "name":"OFFRO",
      "description":"Product – ${order['days']} Days",
      "order_id":rzpOrderId,
      "prefill":{"contact":"","email":""},
      "theme":{"color":"#3E5F55"},
    });
    } catch(e) {
      if(mounted) setState(()=>_msg="Payment error: ${e.toString().replaceAll('Exception: ','')}");
    }
  }

  void _onPaySuccess(PaymentSuccessResponse res) async {
    if(_pendingOrder==null||!mounted)return;
    final captured=_pendingOrder;
    _pendingOrder=null;   // T1/T4: clear immediately to prevent double-fire
    try{
      final result=await Api.verifyProductPayment(widget.token,{
        "order_id":           captured!["order_id"],
        "title":              _titleC.text.trim(),
        "offer_text":         _offerC.text.trim(),
        "logo_url":           _logoB64??"",
        "city":               _selCity??"",
        "store_id":           (_selectedStore?["_id"] ?? _selectedStore?["id"] ?? "").toString(),
        "store_name":         (_selectedStore?["store_name"] ?? "").toString(),
        "razorpay_payment_id":res.paymentId,
        "razorpay_order_id":  res.orderId,
        "razorpay_signature": res.signature,
      });
      if(mounted){
        // FIX 3: Capture navigator before pushReplacement so onDone works after context deactivated
        final nav = Navigator.of(context);
        final invoiceNo = result["invoice_no"]?.toString() ?? result["message"]?.toString() ?? "";
        nav.pushReplacement(MaterialPageRoute(
          builder: (_) => PaymentSuccessScreen(
            storeName: _titleC.text.trim(),
            invoiceNo: invoiceNo,
            onDone: () => nav.popUntil((r) => r.isFirst),
          ),
        ));
      }
    }catch(e){if(mounted)setState(()=>_msg=e.toString().replaceAll("Exception:","").trim());}
  }

  void _onPayError(PaymentFailureResponse res){
    if(mounted)setState(()=>_msg="Payment failed: ${res.message??'Unknown error'}");
  }

  Future<bool?> _showProductSummaryDialog(Map order,{required bool manual})=>
    showDialog<bool>(context:context,builder:(_)=>AlertDialog(
      title:const Text("Product Order Summary",style:TextStyle(color:kPrimary,fontWeight:FontWeight.bold)),
      content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        _dRow("Title",_titleC.text.trim()),
        _dRow("Offer",_offerC.text.trim()),
        _dRow("Duration","${order['days']} Days"),
        _dRow("Period","${order['from_date']} → ${order['end_date']}"),
        _dRow("Rate","₹${order['price_per_day']}/day"),
        const Divider(),
        _dRow("Base","₹${order['base_price']}"),
        if((order['discount_amount']??0)>0) _dRow("Discount","−₹${order['discount_amount']}",
          color:const Color(0xFF1a6640)),
        _dRow("GST (${order['gst_percent']}%)","₹${order['gst_amount']}"),
        _dRow("Total","₹${order['amount_display']}",bold:true),
        const SizedBox(height:10),
        Container(padding:const EdgeInsets.all(10),
          decoration:BoxDecoration(color:kLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
          child:Text(manual?"Product will go to admin review.":"Razorpay opens. Product live after admin approval.",
            style:const TextStyle(fontSize:12,color:kPrimary))),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text("Cancel",style:TextStyle(color:kMuted))),
        ElevatedButton(
          style:ElevatedButton.styleFrom(backgroundColor:kPrimary),
          onPressed:()=>Navigator.pop(context,true),
          child:Text(manual?"Submit":"Pay ₹${order['amount_display']}",style:const TextStyle(color:Colors.white))),
      ],
    ));

  Widget _dRow(String k,String v,{bool bold=false,Color? color})=>Padding(
    padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[
      Expanded(child:Text(k,style:const TextStyle(color:kMuted,fontSize:13))),
      Text(v,style:TextStyle(fontSize:13,fontWeight:bold?FontWeight.bold:FontWeight.w500,color:color??(bold?kPrimary:kText))),
    ]));

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(title:const Text("Create Product"),backgroundColor: Colors.white, foregroundColor: kText),
    body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      // Fields
      _field(_titleC,"Product Title *","e.g. Raj Store ₹50 Off",Icons.confirmation_number),
      const SizedBox(height:12),
      _field(_offerC,"Offer Text","e.g. Get ₹50 off on orders above ₹299",Icons.local_offer),
      const SizedBox(height:12),

      // Price fields — optional
      Row(children:[
        Expanded(child:_field(_originalPriceC,"Original Price","e.g. 299",Icons.currency_rupee,keyboardType:TextInputType.number)),
        const SizedBox(width:10),
        Expanded(child:_field(_priceC,"Offer Price","e.g. 199",Icons.local_offer_outlined,keyboardType:TextInputType.number)),
      ]),
      const SizedBox(height:4),
      const Padding(
        padding:EdgeInsets.only(left:4,bottom:8),
        child:Text("Discount is auto-calculated from prices",
          style:TextStyle(color:kMuted,fontSize:11)),
      ),

      // ── Store selection (mandatory, above city) ──
      if (_storesLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
        )
      else
        DropdownButtonFormField<Map<String,dynamic>>(
          isExpanded: true,
          value: _selectedStore,
          hint: const Text("Select Store *"),
          items: _stores.map((s) => DropdownMenuItem<Map<String,dynamic>>(
            value: s,
            child: Text(s["store_name"]?.toString() ?? "Unnamed Store",
              overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (s) { if (s != null) _onStoreSelected(s); },
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.store, color: kMuted, size: 20),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
      const SizedBox(height: 12),

      // ── City (auto-filled from store, read-only) ──
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F9F6),
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.location_city, color: kMuted, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            (_selCity != null && _selCity!.isNotEmpty) ? _selCity! : "City auto-filled from store",
            style: TextStyle(
              color: (_selCity != null && _selCity!.isNotEmpty) ? kText : kMuted,
              fontSize: 15))),
          if (_selCity != null && _selCity!.isNotEmpty)
            const Icon(Icons.check_circle, color: kPrimary, size: 18),
        ]),
      ),
      const SizedBox(height: 12),

      // Logo upload
      GestureDetector(
        onTap:_pickLogo,
        child:Container(
          height:90,
          decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:_logoB64!=null?kPrimary:kBorder,width:_logoB64!=null?2:1)),
          child:_logoB64!=null
            ? Stack(children:[
                Center(child:ClipRRect(borderRadius:BorderRadius.circular(11),
                  child:Image.memory(base64Decode(_logoB64!.split(",").last),height:80,width:80,fit:BoxFit.cover))),
                Positioned(top:4,right:4,child:GestureDetector(onTap:()=>setState(()=>_logoB64=null),
                  child:Container(padding:const EdgeInsets.all(3),decoration:const BoxDecoration(color:Colors.red,shape:BoxShape.circle),
                    child:const Icon(Icons.close,color:Colors.white,size:12)))),
              ])
            : Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                const Icon(Icons.image_rounded,size:28,color:kAccent),
                const SizedBox(height:4),
                const Text("Upload Image",style:TextStyle(color:kMuted,fontSize:12)),
                Row(mainAxisAlignment:MainAxisAlignment.center,children:[_InfoChip("📐 400×400px"),const SizedBox(width:6),_InfoChip("📦 Max 1MB")]),
              ]),
        )),
      const SizedBox(height:12),

      // Duration input + From Date picker
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Duration & Start Date",style:TextStyle(fontWeight:FontWeight.w700,color:kText,fontSize:13)),
          const SizedBox(height:12),
          Row(children:[
            Expanded(child:TextField(
              controller:_daysC,
              keyboardType:TextInputType.number,
              decoration:InputDecoration(
                labelText:"Number of Days",hintText:"e.g. 30",
                prefixIcon:const Icon(Icons.calendar_today_outlined,color:kMuted,size:18),
                filled:true,fillColor:kBg,isDense:true,
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
              ),
            )),
            const SizedBox(width:10),
            Expanded(child:GestureDetector(
              onTap:_pickFromDate,
              child:Container(
                padding:const EdgeInsets.symmetric(horizontal:12,vertical:13),
                decoration:BoxDecoration(color:kBg,borderRadius:BorderRadius.circular(10),border:Border.all(color:kBorder)),
                child:Row(children:[
                  const Icon(Icons.event_rounded,size:18,color:kMuted),
                  const SizedBox(width:8),
                  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                    const Text("From Date",style:TextStyle(fontSize:11,color:kMuted)),
                    Text(_fromDateDisplay,style:const TextStyle(fontSize:13,color:kText,fontWeight:FontWeight.w600)),
                  ])),
                ]),
              ),
            )),
          ]),
          if(_days>0) Padding(padding:const EdgeInsets.only(top:10),
            child:Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),
              decoration:BoxDecoration(color:kLight.withValues(alpha:.4),borderRadius:BorderRadius.circular(8)),
              child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                Text("Active period:",style:const TextStyle(fontSize:12,color:kMuted)),
                Text("$_fromDateDisplay → $_endDateDisplay",style:const TextStyle(fontSize:12,color:kPrimary,fontWeight:FontWeight.w600)),
              ]),
            )),
          if(_pricing!=null && _days>0) Padding(padding:const EdgeInsets.only(top:6),
            child:Text("₹${_pricePerDay.toStringAsFixed(0)}/day × $_days days",
              style:const TextStyle(fontSize:12,color:kMuted))),
        ])),
      const SizedBox(height:12),

      if (_pricing!=null && _days>0)
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(12)),
          child:Column(children:[
            _dRow("Base Price","₹${_basePrice.toStringAsFixed(2)}"),
            _dRow("GST (${_gstPct.toInt()}%)","₹${_gst.toStringAsFixed(2)}"),
            const Divider(height:16),
            _dRow("Total","₹${_total.toStringAsFixed(2)}",bold:true),
          ])),

      const SizedBox(height:4),
      if(_msg.isNotEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:6),
        child:Text(_msg,style:const TextStyle(color:Colors.red,fontSize:12))),
      const SizedBox(height:12),

      // FIX 5: Discount field
      // Item 6: Discount code field — product
      Container(
        padding:const EdgeInsets.all(14),
        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Discount Code",style:TextStyle(fontWeight:FontWeight.w700,color:kText,fontSize:13)),
          const SizedBox(height:4),
          const Text("Have a promo code? Enter it below.",style:TextStyle(color:kMuted,fontSize:11)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(
              controller:_discountVC,
              textCapitalization:TextCapitalization.characters,
              onChanged:(_){ if(_appliedVCode.isNotEmpty) setState((){_appliedVCode="";_appliedVDiscount=0;_discountVMsg="";_discountVOk=false;}); },
              decoration:InputDecoration(
                hintText:"e.g. OFFRO20",isDense:true,
                prefixIcon:const Icon(Icons.local_offer_outlined,color:kMuted,size:18),
                contentPadding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                border:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:const BorderSide(color:kBorder)),
                enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(10),borderSide:BorderSide(color:_discountVOk?kPrimary:kBorder)),
              ),
            )),
            const SizedBox(width:8),
            ElevatedButton(
              onPressed:_applyingVCode?null:_applyVDiscountCode,
              style:ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kText,
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              child:_applyingVCode
                ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
                : const Text("Apply",style:TextStyle(fontWeight:FontWeight.w700,fontSize:13)),
            ),
          ]),
          if (_discountVMsg.isNotEmpty) ...[
            const SizedBox(height:6),
            Text(_discountVMsg,style:TextStyle(color:_discountVOk?const Color(0xFF1a6640):Colors.red,fontWeight:FontWeight.w600,fontSize:12)),
          ],
          if (_appliedVDiscount > 0) ...[
            const SizedBox(height:6),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:kLight.withValues(alpha:.5),borderRadius:BorderRadius.circular(8)),
              child:Row(children:[
                const Icon(Icons.check_circle,color:Color(0xFF1a6640),size:14),
                const SizedBox(width:6),
                Text("−₹${_appliedVDiscount.toStringAsFixed(0)} off  →  Total: ₹${_total.toStringAsFixed(2)}",
                  style:const TextStyle(color:Color(0xFF1a6640),fontWeight:FontWeight.w700,fontSize:12)),
              ]),
            ),
          ],
        ])),
      const SizedBox(height:16),
      const SizedBox(height:12),
      ElevatedButton.icon(
        icon:_loading?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Icon(Icons.arrow_forward_rounded),
        label:const Text("Proceed to Checkout"),
        style:ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: kText,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
          padding:const EdgeInsets.symmetric(vertical:14)),
        onPressed:_loading?null:_proceed,
      ),
      const SizedBox(height:24),
    ])),
  );

  Widget _field(TextEditingController c,String label,String hint,IconData icon,{TextInputType keyboardType=TextInputType.text})=>TextField(
    controller:c,
    decoration:InputDecoration(
      labelText:label,hintText:hint,prefixIcon:Icon(icon,color:kMuted,size:20),
      filled:true,fillColor:Colors.white,
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:kBorder)),
      enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:kBorder)),
    ));
}



/// Format backend date string ("13 May 2026 14:30") → "13 May 2026, 2:30 PM"
String _fmtDateTime(String? raw) {
  // T3: Handles ISO "2026-05-21T14:37:00", datetime "2026-05-21 14:37", 
  //     and legacy "21 May 2026 14:37:00" formats.
  // Output: "21 May 2026 | 02:45 PM"
  if (raw == null || raw.isEmpty) return "";
  try {
    DateTime? dt;
    // Try ISO / datetime string parse first
    final clean = raw.trim().replaceAll("T", " ").split(".").first;
    dt = DateTime.tryParse(clean);
    if (dt == null) {
      // Legacy: "21 May 2026 14:37:00" — rebuild as parseable
      final months = {"Jan":1,"Feb":2,"Mar":3,"Apr":4,"May":5,"Jun":6,
                      "Jul":7,"Aug":8,"Sep":9,"Oct":10,"Nov":11,"Dec":12};
      final parts = clean.split(" ");
      if (parts.length >= 3) {
        final day = int.tryParse(parts[0]);
        final mon = months[parts[1]];
        final yr  = int.tryParse(parts[2]);
        if (day != null && mon != null && yr != null) {
          int h=0, mi=0;
          if (parts.length >= 4) {
            final tp = parts[3].split(":");
            h  = int.tryParse(tp[0]) ?? 0;
            mi = int.tryParse(tp.length>1?tp[1]:"0") ?? 0;
          }
          dt = DateTime(yr, mon, day, h, mi);
        }
      }
    }
    if (dt == null) return raw;
    const mos = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    final d   = dt.day.toString().padLeft(2,"0");
    final mo  = mos[dt.month - 1];
    final yr  = dt.year;
    int   h   = dt.hour;
    final mi  = dt.minute.toString().padLeft(2,"0");
    final ampm = h >= 12 ? "PM" : "AM";
    h = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return "$d $mo $yr | ${h.toString().padLeft(2,'0')}:$mi $ampm";
  } catch (_) { return raw; }
}


class MerchantHome extends StatefulWidget {
  final String token; final Map merchant;
  const MerchantHome({super.key, required this.token, required this.merchant});
  @override State<MerchantHome> createState() => _MerchantHomeState();
}
class _MerchantHomeState extends State<MerchantHome> {
  int _idx = 0;
  late List<Widget> _pages;
  @override void initState() {
    super.initState();
    _pages = [
      MerchantHomePage(token: widget.token),
      MerchantDealsPage(token: widget.token),
      MerchantInvoicesPage(token: widget.token),
      MerchantTxnPage(token: widget.token),
      MerchantProfilePage(token: widget.token, merchant: widget.merchant),
    ];
  }
  @override Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
    body: _pages[_idx],
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _idx,
      onTap: (i) => setState(()=>_idx=i),
      selectedItemColor: kPrimary, unselectedItemColor: kMuted,
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon:Icon(Icons.home_rounded),label:"Home"),
        BottomNavigationBarItem(icon:Icon(Icons.local_offer),label:"Deals"),
        BottomNavigationBarItem(icon:Icon(Icons.receipt_long),label:"Invoices"),
        BottomNavigationBarItem(icon:Icon(Icons.history),label:"Activity"),
        BottomNavigationBarItem(icon:Icon(Icons.person),label:"Profile"),
      ],
    ),
  ));
}

// ─────────── Merchant Stores Page ───────────
class MerchantStoresPage extends StatefulWidget {
  final String token;
  const MerchantStoresPage({super.key, required this.token});
  @override State<MerchantStoresPage> createState() => _MerchantStoresState();
}
class _MerchantStoresState extends State<MerchantStoresPage> {
  List<Map<String,dynamic>> stores = []; bool loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(()=>loading=true);
    stores = List<Map<String,dynamic>>.from(await Api.getMerchantStores(widget.token));
    if (mounted) setState(()=>loading=false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(title:Row(children:[buildImageLogo(height:24,white:true),const SizedBox(width:8),const Text("My Stores",style:TextStyle(fontWeight:FontWeight.w800))]),
        backgroundColor: Colors.white, foregroundColor: kText,automaticallyImplyLeading:false),
    floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.white, foregroundColor: kText,
        icon:const Icon(Icons.add), label:const Text("Add Store"),
        onPressed:()=>Navigator.push(context,_offroRoute(AddEditStorePage(token:widget.token))).then((_)=>_load())),
    body: loading ? const Center(child:CircularProgressIndicator(color:kPrimary)) :
      stores.isEmpty ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        buildLogo(44,kAccent), const SizedBox(height:12),
        const Text("No stores yet",style:TextStyle(color:kMuted,fontSize:16)),
        const SizedBox(height:8), const Text("Tap + to add your first store",style:TextStyle(color:kMuted,fontSize:13)),
      ])) :
      RefreshIndicator(onRefresh:_load,child:ListView.builder(
        padding:const EdgeInsets.all(14),
        itemCount:stores.length,
        itemBuilder:(_,i){
          final s = stores[i] as Map;
          final status = s["status"]??"draft";
          Color sc = kMuted;
          String sl = status;
          if (status=="active") { sc=const Color(0xFF1a6640); sl="✅ Active"; }
          else if (status=="waiting_approval") { sc=const Color(0xFF856404); sl="⏳ Pending Approval"; }
          else if (status=="paid") { sc=const Color(0xFF856404); sl="✅ Payment Confirmed"; }
          else if (status=="draft") { sc=kMuted; sl="📝 Draft"; }
          else if (status=="inactive") { sc=Colors.red.shade700; sl="❌ Inactive"; }
          else if (status=="pending") { sc=kMuted; sl="🕐 Pending"; }
          return Card(elevation:2,margin:const EdgeInsets.only(bottom:12),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
            child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                Expanded(child:Text(s["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,fontSize:15,color:kText))),
                Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                    decoration:BoxDecoration(color:sc.withValues(alpha: .12),borderRadius:BorderRadius.circular(20)),
                    child:Text(sl,style:TextStyle(color:sc,fontSize:11,fontWeight:FontWeight.w600))),
              ]),
              const SizedBox(height:6),
              Text("${s['city']??''}, ${s['area']??''}",style:const TextStyle(color:kMuted,fontSize:12)),
              Text(s["category"]??"",style:const TextStyle(color:kMuted,fontSize:12)),
              if ((s["deal_count"] as int? ?? 0) > 0) ...[
                const SizedBox(height:5),
                Container(
                  padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),
                  decoration:BoxDecoration(color:const Color(0xFFFFF0D0),borderRadius:BorderRadius.circular(8),border:Border.all(color:const Color(0xFFE6A817))),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    const Icon(Icons.local_offer,size:12,color:Color(0xFFB87A00)),
                    const SizedBox(width:4),
                    Text("${s['deal_count']??0} Deal${((s['deal_count']??0)>1)?'s':''} Active",style:const TextStyle(color:Color(0xFFB87A00),fontSize:11,fontWeight:FontWeight.w700)),
                  ])),
              ],
              if ((s["subscription_end"]??'').isNotEmpty)
                Container(margin:const EdgeInsets.only(top:5),padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                  decoration:BoxDecoration(
                    color: status=="active" ? const Color(0xFFd1f0e0) : const Color(0xFFFFF3CD),
                    borderRadius:BorderRadius.circular(8)),
                  child:Row(mainAxisSize:MainAxisSize.min,children:[
                    Icon(Icons.event_available,size:13,color: status=="active" ? const Color(0xFF1a6640) : const Color(0xFF856404)),
                    const SizedBox(width:4),
                    Text("${status=='active'?'Active till':'Expires'}: ${(s['subscription_end']?.toString() ?? '').split('T').first}",
                      style:TextStyle(color: status=="active" ? const Color(0xFF1a6640) : const Color(0xFF856404),fontSize:11.5,fontWeight:FontWeight.w700)),
                  ])),
              const SizedBox(height:10),
              Row(children:[
                if (status=="draft"||status=="inactive") Expanded(child:ElevatedButton.icon(
                  icon:const Icon(Icons.payment,size:16), label:const Text("Subscribe"),
                  style:ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
                  onPressed:()=>Navigator.push(context,_offroRoute(SubscribePage(token:widget.token,store:s))).then((_)=>_load()))),
                if (status=="waiting_approval") Expanded(child:Container(
                  padding:const EdgeInsets.symmetric(vertical:8),
                  alignment:Alignment.center,
                  child:const Text("⏳ Awaiting Admin Approval",style:TextStyle(color:Color(0xFF856404),fontSize:12,fontWeight:FontWeight.w600)))),
                if (status=="active") ...[
                  Expanded(child:OutlinedButton.icon(
                    icon:const Icon(Icons.edit,size:16,color:kPrimary), label:const Text("Edit",style:TextStyle(color:kPrimary)),
                    style:OutlinedButton.styleFrom(side:const BorderSide(color:kPrimary),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
                    onPressed:()=>Navigator.push(context,_offroRoute(AddEditStorePage(token:widget.token,store:s))).then((_)=>_load()))),
                  const SizedBox(width:8),
                  OutlinedButton.icon(
                    icon:const Icon(Icons.add_shopping_cart,size:16,color:kPrimary),label:const Text("Deals",style:TextStyle(color:kPrimary,fontSize:12)),
                    style:OutlinedButton.styleFrom(side:const BorderSide(color:kBorder),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
                    onPressed:()=>Navigator.push(context,_offroRoute(AddDealPage(token:widget.token,storeId:s["_id"]??"",storeName:s["store_name"]??"")))),
                ],
                if (s["status"]=="active") ...[const SizedBox(width:8),OutlinedButton.icon(
                  icon:Icon((s["qr_code"]??'').isNotEmpty?Icons.qr_code:Icons.crop_free,size:16,color:kPrimary),
                  label:Text((s["qr_code"]??'').isNotEmpty?"QR":"Gen QR",style:const TextStyle(color:kPrimary,fontSize:12)),
                  style:OutlinedButton.styleFrom(side:const BorderSide(color:kBorder),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
                  onPressed:(s["qr_code"]??'').isNotEmpty
                    ?()=>_showQR(context,s["store_name"]??"",s["qr_code"]??'')
                    :() async {
                        final sid = s["_id"]??"";
                        try {
                          final res = await Api.resetStoreQr(sid, widget.token);
                          final qr = res["qr_code"]??"";
                          if(qr.isNotEmpty){ setState(()=>s["qr_code"]=qr); if(mounted)_showQR(context,s["store_name"]??"",qr); }
                        } catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text("Failed: $e"))); }
                      })],
              ]),
            ])));
        },
      )),
  );

  void _showQR(BuildContext ctx, String name, String qr) => showDialog(context:ctx, builder:(_)=>AlertDialog(
    title:Text(name,style:const TextStyle(fontSize:15,color:kPrimary)),
    content:Column(mainAxisSize:MainAxisSize.min,children:[
      qr.startsWith("data:image") ? Image.memory(base64Decode(qr.split(",").last),width:220,height:220) : const Icon(Icons.qr_code,size:100),
      const SizedBox(height:8), const Text("Show this to customers to earn points",textAlign:TextAlign.center,style:TextStyle(color:kMuted,fontSize:12)),
    ]),
    actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text("Close",style:TextStyle(color:kPrimary)))],
  ));
}

// ─────────── Add/Edit Store Page ───────────

// ─────────────────────── INDIA STATES & CITIES ───────────────────────
// Flat city list for banner/product city targeting
List<String> get _allCities {
  final set = <String>{};
  for (final cities in kIndiaCities.values) set.addAll(cities);
  final list = set.toList()..sort();
  return list;
}

const Map<String,List<String>> kIndiaCities = {
  "Andhra Pradesh": ["Visakhapatnam","Vijayawada","Guntur","Nellore","Kurnool","Rajahmundry","Tirupati","Kakinada","Kadapa","Anantapur"],
  "Arunachal Pradesh": ["Itanagar","Naharlagun","Pasighat"],
  "Assam": ["Guwahati","Silchar","Dibrugarh","Jorhat","Nagaon","Tinsukia"],
  "Bihar": ["Patna","Gaya","Bhagalpur","Muzaffarpur","Purnia","Darbhanga","Bihar Sharif","Arrah"],
  "Chhattisgarh": ["Raipur","Bhilai","Bilaspur","Korba","Durg","Rajnandgaon","Jagdalpur"],
  "Goa": ["Panaji","Margao","Vasco da Gama","Mapusa","Ponda"],
  "Gujarat": ["Ahmedabad","Surat","Vadodara","Rajkot","Bhavnagar","Jamnagar","Gandhinagar","Junagadh","Anand"],
  "Haryana": ["Faridabad","Gurugram","Panipat","Ambala","Yamunanagar","Rohtak","Hisar","Karnal","Sonipat","Panchkula"],
  "Himachal Pradesh": ["Shimla","Solan","Dharamshala","Mandi","Baddi","Palampur","Kullu"],
  "Jharkhand": ["Ranchi","Jamshedpur","Dhanbad","Bokaro","Deoghar","Hazaribagh"],
  "Karnataka": ["Bengaluru","Mysuru","Mangaluru","Hubli","Dharwad","Belagavi","Kalaburagi","Ballari","Vijayapura","Shivamogga","Tumkur","Davangere","Hassan","Udupi"],
  "Kerala": ["Thiruvananthapuram","Kochi","Kozhikode","Thrissur","Kollam","Kannur","Palakkad","Alappuzha","Malappuram","Kottayam"],
  "Madhya Pradesh": ["Bhopal","Indore","Jabalpur","Gwalior","Ujjain","Sagar","Dewas","Satna","Ratlam","Rewa"],
  "Maharashtra": ["Mumbai","Pune","Nagpur","Nashik","Thane","Aurangabad","Solapur","Kolhapur","Amravati","Nanded","Sangli","Malegaon","Jalgaon","Akola","Latur"],
  "Manipur": ["Imphal","Thoubal","Bishnupur","Churachandpur"],
  "Meghalaya": ["Shillong","Tura","Jowai"],
  "Mizoram": ["Aizawl","Lunglei","Champhai"],
  "Nagaland": ["Kohima","Dimapur","Mokokchung"],
  "Odisha": ["Bhubaneswar","Cuttack","Rourkela","Berhampur","Sambalpur","Puri","Balasore"],
  "Punjab": ["Ludhiana","Amritsar","Jalandhar","Patiala","Bathinda","Mohali","Firozpur","Hoshiarpur"],
  "Rajasthan": ["Jaipur","Jodhpur","Kota","Bikaner","Ajmer","Udaipur","Bhilwara","Alwar","Bharatpur","Sikar"],
  "Sikkim": ["Gangtok","Namchi","Gyalshing"],
  "Tamil Nadu": ["Chennai","Coimbatore","Madurai","Tiruchirappalli","Salem","Tirunelveli","Vellore","Erode","Thoothukudi","Tiruppur","Dindigul","Thanjavur"],
  "Telangana": ["Hyderabad","Warangal","Nizamabad","Karimnagar","Ramagundam","Khammam","Mahbubnagar","Nalgonda","Adilabad"],
  "Tripura": ["Agartala","Dharmanagar","Udaipur"],
  "Uttar Pradesh": ["Lucknow","Kanpur","Agra","Varanasi","Prayagraj","Meerut","Bareilly","Aligarh","Ghaziabad","Noida","Mathura","Moradabad","Gorakhpur"],
  "Uttarakhand": ["Dehradun","Haridwar","Roorkee","Haldwani","Rishikesh","Nainital","Kashipur","Rudrapur"],
  "West Bengal": ["Kolkata","Asansol","Siliguri","Durgapur","Bardhaman","Malda","Baharampur","Kharagpur"],
  "Delhi": ["New Delhi","Dwarka","Rohini","Pitampura","Laxmi Nagar","Janakpuri","Saket","Karol Bagh","Connaught Place"],
  "Jammu and Kashmir": ["Srinagar","Jammu","Anantnag","Baramulla","Sopore","Kathua"],
  "Ladakh": ["Leh","Kargil"],
  "Andaman and Nicobar Islands": ["Port Blair","Diglipur","Rangat"],
  "Chandigarh": ["Chandigarh"],
  "Dadra and Nagar Haveli and Daman and Diu": ["Daman","Diu","Silvassa"],
  "Lakshadweep": ["Kavaratti","Agatti"],
  "Puducherry": ["Puducherry","Karaikal","Mahe","Yanam"],
};
const List<String> kIndiaStates = [
  "Andhra Pradesh","Arunachal Pradesh","Assam","Bihar","Chhattisgarh",
  "Goa","Gujarat","Haryana","Himachal Pradesh","Jharkhand",
  "Karnataka","Kerala","Madhya Pradesh","Maharashtra","Manipur",
  "Meghalaya","Mizoram","Nagaland","Odisha","Punjab",
  "Rajasthan","Sikkim","Tamil Nadu","Telangana","Tripura",
  "Uttar Pradesh","Uttarakhand","West Bengal","Delhi",
  "Jammu and Kashmir","Ladakh","Andaman and Nicobar Islands",
  "Chandigarh","Dadra and Nagar Haveli and Daman and Diu",
  "Lakshadweep","Puducherry",
];

class AddEditStorePage extends StatefulWidget {
  final String token; final Map? store;
  const AddEditStorePage({super.key, required this.token, this.store});
  @override State<AddEditStorePage> createState() => _AddEditStoreState();
}
class _AddEditStoreState extends State<AddEditStorePage> {
  final _name = TextEditingController();
  final _area = TextEditingController(); final _addr = TextEditingController();
  final _phone= TextEditingController(); final _lat  = TextEditingController();
  final _lng  = TextEditingController();
  String _category = ""; String? _imgB64; String? _img2B64; bool _loading = false; String _msg = "";
  List<dynamic> _categories = [];
  String? _selState; String? _selCity;
  List<String> _areas = []; bool _areasLoading = false;
  bool _locLoading = false; bool _locConfirmed = false;
  final _mapsUrlCtrl = TextEditingController();
  bool _mapsResolving = false;
  bool _mapsApplied = false;
  String _resolvedPlaceName = '';
  String _resolvedAddress = '';
  final _about = TextEditingController();
  String? _openTime;   // e.g. "09:00"
  String? _closeTime;  // e.g. "22:00"

  // 30-min interval time slots for dropdowns
  static List<Map<String,String>> _timeSlots() {
    final slots = <Map<String,String>>[];
    for (int h = 0; h < 24; h++) {
      for (int m = 0; m < 60; m += 30) {
        final val = "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}";
        final suffix = h >= 12 ? "PM" : "AM";
        final h12    = h > 12 ? h - 12 : (h == 0 ? 12 : h);
        final mStr   = m > 0 ? ":${m.toString().padLeft(2,'0')}" : ":00";
        final label  = "$h12$mStr $suffix";
        slots.add({"value": val, "label": label});
      }
    }
    return slots;
  }

  Future<void> _captureGpsLocation() async {
    setState(() { _locLoading = true; _locConfirmed = false; });
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) setState(() {
        _lat.text = pos.latitude.toStringAsFixed(6);
        _lng.text = pos.longitude.toStringAsFixed(6);
        _locConfirmed = true;
        _locLoading   = false;
      });
      await _reverseGeocode(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) setState(() {
        _locLoading = false;
        _msg = "Could not get location: ${e.toString().replaceAll('Exception: ','')}";
      });
    }
  }

  // ── Reverse geocode: fill state/city/area/address from lat/lng ──
  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final res = await Api.reverseGeocode(lat, lng);
      if (!mounted || res.containsKey('error')) return;
      setState(() {
        final st = res['state']?.toString() ?? '';
        final ct = res['city']?.toString() ?? '';
        final ar = res['area']?.toString() ?? '';
        final ad = res['address']?.toString() ?? '';
        // Case-insensitive state match
        final matchedState = st.isNotEmpty
            ? kIndiaStates.firstWhere((s) => s.toLowerCase() == st.toLowerCase(), orElse: () => '')
            : '';
        if (matchedState.isNotEmpty) _selState = matchedState;
        // Case-insensitive city match within the matched state's city list
        if (ct.isNotEmpty) {
          final stateKey = matchedState.isNotEmpty ? matchedState : (_selState ?? '');
          final cities = kIndiaCities[stateKey] ?? [];
          final matchedCity = cities.firstWhere(
              (c) => c.toLowerCase() == ct.toLowerCase(), orElse: () => '');
          if (matchedCity.isNotEmpty) { _selCity = matchedCity; _loadAreas(matchedCity); }
          else if (cities.isEmpty) { _selCity = ct; _loadAreas(ct); }
        }
        if (ar.isNotEmpty) _area.text = ar;
        if (ad.isNotEmpty) _addr.text = ad;
      });
    } catch (_) {}
  }

  // ── Google Maps link resolution (inline Blinkit-style) ──
  Future<void> _resolveMapsLink(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    setState(() {
      _mapsResolving = true;
      _mapsApplied = false;
      _resolvedPlaceName = '';
      _resolvedAddress = '';
    });
    final res = await Api.resolveMapsLink(trimmed);
    if (!mounted) return;
    if (res.containsKey('error') || res['lat'] == null || res['lng'] == null) {
      setState(() {
        _mapsResolving = false;
        _resolvedPlaceName = '';
        _resolvedAddress = '';
        _msg = res['error']?.toString().isNotEmpty == true
            ? res['error'].toString()
            : 'Could not resolve this Maps link. Try the Share button → Copy Link in Google Maps.';
      });
    } else {
      setState(() {
        _mapsResolving = false;
        _resolvedPlaceName = res['place_name']?.toString() ?? '';
        _resolvedAddress   = res['address']?.toString() ?? '';
        _lat.text = res['lat'].toString();
        _lng.text = res['lng'].toString();
        _mapsApplied  = true;
        _locConfirmed = true;
      });
      // Auto-fill address fields from resolved location
      final st = res['state']?.toString() ?? '';
      final ct = res['city']?.toString() ?? '';
      final ar = res['area']?.toString() ?? '';
      final ad = res['address']?.toString() ?? '';
      if (mounted && (st.isNotEmpty || ct.isNotEmpty || ar.isNotEmpty || ad.isNotEmpty)) {
        setState(() {
          // Case-insensitive state match
          final matchedState = st.isNotEmpty
              ? kIndiaStates.firstWhere((s) => s.toLowerCase() == st.toLowerCase(), orElse: () => '')
              : '';
          if (matchedState.isNotEmpty) _selState = matchedState;
          // Case-insensitive city match within the matched state's city list
          if (ct.isNotEmpty) {
            final stateKey = matchedState.isNotEmpty ? matchedState : (_selState ?? '');
            final cities = kIndiaCities[stateKey] ?? [];
            final matchedCity = cities.firstWhere(
                (c) => c.toLowerCase() == ct.toLowerCase(), orElse: () => '');
            if (matchedCity.isNotEmpty) { _selCity = matchedCity; _loadAreas(matchedCity); }
            else if (cities.isEmpty) { _selCity = ct; _loadAreas(ct); }
          }
          if (ar.isNotEmpty) _area.text = ar;
          if (ad.isNotEmpty) _addr.text = ad;
        });
      }
    }
  }

  bool get _isEdit => widget.store != null;

  @override void initState() {
    super.initState();
    _loadCategories();
    if (_isEdit) {
      _populateFromStore(widget.store!);
      // Also fetch the full store detail to get image2 + state/city (list API may omit them)
      _fetchFullStoreDetail();
    }
  }

  void _populateFromStore(Map s) {
    _name.text  = s["store_name"]??"";
    final rawState = (s["state"]??"").toString().trim();
    final rawCity  = (s["city"]??"").toString().trim();
    _selState   = rawState.isNotEmpty ? rawState : null;
    _selCity    = rawCity.isNotEmpty  ? rawCity  : null;
    _area.text  = s["area"]??"";       _addr.text = s["address"]??"";
    // Load area dropdown for the store's city (async, non-blocking)
    final _storedCity = (s["city"]??"").toString().trim();
    if (_storedCity.isNotEmpty) _loadAreas(_storedCity);
    _phone.text = s["phone"]??"";      _lat.text  = s["lat"]??"";
    _lng.text   = s["lng"]??"";        _category  = s["category"]??"";
    if ((s["image"]??'').isNotEmpty) _imgB64 = s["image"];
    if ((s["image2"]??'').isNotEmpty) _img2B64 = s["image2"];
    _about.text = s["about"]??"";
    _openTime  = s["open_time"]?.toString();
    _closeTime = s["close_time"]?.toString();
  }

  Future<void> _fetchFullStoreDetail() async {
    try {
      final storeId = widget.store!["_id"]?.toString() ?? "";
      if (storeId.isEmpty) return;
      final detail = await Api.getMerchantStoreDetail(widget.token, storeId);
      if (mounted && detail != null) {
        setState(() => _populateFromStore(detail));
      }
    } catch (_) {}
  }
  @override void dispose() { _name.dispose();_area.dispose();_addr.dispose();_phone.dispose();_lat.dispose();_lng.dispose();_about.dispose();_mapsUrlCtrl.dispose(); super.dispose(); }

  Future<void> _loadCategories() async { _categories = await Api.fetchCategories(token: widget.token); if (mounted) setState((){}); }

  /// Google Maps location picker — premium dialog with URL paste & coordinate extraction.
  /// Supports all Google Maps URL formats including short links (maps.app.goo.gl).
  Future<void> _pickFromGoogleMaps() async {
    double? _parsedLat;
    double? _parsedLng;
    String _parseError = "";
    String _pastedText = "";
    bool _isProcessing = false;

    // ── Enhanced URL parser — covers all Google Maps URL variants ──
    // Handles: @lat,lng  |  ?q=lat,lng  |  ll=lat,lng  |  /place/@lat,lng
    // Also handles: manual "lat,lng" or "lat lng" coordinate entry
    Future<bool> _tryParse(String input, void Function(double, double) onSuccess) async {
      final raw = input.trim();
      if (raw.isEmpty) return false;

      // ── Coord patterns: relaxed to 1+ decimal digits to catch all Google formats ──
      // ── Step 1: Direct coordinate input (bare "lat,lng" typed by user) ──
      final bareCoord = RegExp(r'^\s*(-?\d{1,3}\.\d{4,})\s*,\s*(-?\d{1,3}\.\d{4,})\s*$');
      final bcm = bareCoord.firstMatch(raw);
      if (bcm != null) {
        final la = double.tryParse(bcm.group(1)!);
        final ln = double.tryParse(bcm.group(2)!);
        if (la != null && ln != null && la.abs() <= 90 && ln.abs() <= 180
            && la != 0.0 && ln != 0.0) {
          onSuccess(la, ln);
          return true;
        }
      }

      // ── Step 2: Direct Maps URL — safe coord extraction ──
      // ONLY @lat,lng and ?q=lat,lng patterns — never loose patterns.
      bool _safeExtractCoords(String url) {
        for (final pat in [
          RegExp(r'@(-?\d{1,3}\.\d{4,}),(-?\d{1,3}\.\d{4,})'),
          RegExp(r'[?&]q=(-?\d{1,3}\.\d{4,}),(-?\d{1,3}\.\d{4,})'),
        ]) {
          final m = pat.firstMatch(url);
          if (m != null) {
            final la = double.tryParse(m.group(1)!);
            final ln = double.tryParse(m.group(2)!);
            if (la != null && ln != null && la.abs() <= 90 && ln.abs() <= 180
                && la != 0.0 && ln != 0.0) {
              onSuccess(la, ln);
              return true;
            }
          }
        }
        return false;
      }
      if (_safeExtractCoords(raw)) return true;

      // ── Step 3: Handle Google Maps URLs — resolve via backend ──
      // Flutter's http package cannot reliably follow maps.app.goo.gl redirects on
      // Android. Delegate ALL Google Maps resolution to the backend which uses
      // Python urllib (full redirect chain, Nominatim fallback).
      final isGoogleUrl = raw.contains('goo.gl') || raw.contains('maps.app')
          || raw.contains('google.com/maps') || raw.contains('maps.google');
      if (!isGoogleUrl) return false;

      try {
        final res = await Api.resolveMapsLink(raw);
        if (!res.containsKey('error')) {
          final la = double.tryParse(res['lat']?.toString() ?? '');
          final ln = double.tryParse(res['lng']?.toString() ?? '');
          if (la != null && ln != null && la.abs() <= 90 && ln.abs() <= 180
              && la != 0.0 && ln != 0.0) {
            onSuccess(la, ln);
            return true;
          }
        }
      } catch (_) {}
      return false;
    }

    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setD) {
              return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header with Google branding ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1a73e8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(children: [
                  // Google Maps "G" logo badge
                  Container(
                    width: 38, height: 38,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text("G",
                        style: TextStyle(color: Color(0xFF1a73e8), fontSize: 22, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Google Maps", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                      Text("Paste a shared Maps link to set location", style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    ],
                  )),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                  ),
                ]),
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step-by-step instructions
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFe8f0fe),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _mapsStep("1", "Open Google Maps app on your phone"),
                        const SizedBox(height: 6),
                        _mapsStep("2", "Search for your store or drop a pin"),
                        const SizedBox(height: 6),
                        _mapsStep("3", "Tap Share → Copy link (then paste full link here)"),
                        const SizedBox(height: 6),
                        _mapsStep("4", "Paste it below and tap Apply"),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    // Paste field
                    const Text("Paste Maps Link or Coordinates",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF444444))),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _parseError.isNotEmpty
                          ? const Color(0xFFc0392b)
                          : _parsedLat != null
                            ? const Color(0xFF1a6640)
                            : const Color(0xFFCCCCCC)),
                      ),
                      child: TextField(
                        autofocus: false,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
                        onChanged: (v) async {
                          _pastedText = v;
                          final ok = await _tryParse(v, (la, ln) {
                            _parsedLat = la;
                            _parsedLng = ln;
                            _parseError = "";
                          });
                          if (!ok && v.trim().isNotEmpty) {
                            _parsedLat = null;
                            _parsedLng = null;
                            _parseError = "Could not extract coordinates from this link.";
                          } else if (v.trim().isEmpty) {
                            _parsedLat = null;
                            _parsedLng = null;
                            _parseError = "";
                          }
                          setD(() {});
                        },
                        decoration: const InputDecoration(
                          hintText: "Paste full share link or type: 12.9716, 77.5946",
                          hintStyle: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.link_rounded, color: Color(0xFF1a73e8), size: 20),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Result feedback
                    if (_parsedLat != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFe6f4ea),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF1a6640).withValues(alpha: .3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF1a6640), size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Location detected!", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1a6640))),
                              Text(
                                "Lat: ${_parsedLat!.toStringAsFixed(6)}  |  Lng: ${_parsedLng!.toStringAsFixed(6)}",
                                style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                              ),
                            ],
                          )),
                        ]),
                      )
                    else if (_parseError.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFfce8e6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFc0392b).withValues(alpha: .3)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.error_outline_rounded, color: Color(0xFFc0392b), size: 16),
                            const SizedBox(width: 6),
                            const Text("Could not extract coordinates",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFc0392b))),
                          ]),
                          const SizedBox(height: 4),
                          const Text(
                            "Make sure you copy the link using the Share button in Google Maps — not the address bar URL.",
                            style: TextStyle(fontSize: 11, color: Color(0xFF888888), height: 1.4)),
                        ]),
                      )
                    else
                      const Text(
                        "You can also type coordinates directly: e.g. 12.9716, 77.5946",
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
                      ),
                  ],
                ),
              ),

              // ── Action buttons ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Open Google Maps app to let user find location
                        final uri = Uri.parse("https://maps.google.com/?q=my+location");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text("Open Maps"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1a73e8),
                        side: const BorderSide(color: Color(0xFF1a73e8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _parsedLat == null ? null : () {
                        if (mounted) setState(() {
                          _lat.text     = _parsedLat!.toStringAsFixed(7);
                          _lng.text     = _parsedLng!.toStringAsFixed(7);
                          _locConfirmed = true;
                        });
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text("Apply Location"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _parsedLat != null
                          ? const Color(0xFF1a73e8)
                          : const Color(0xFFCCCCCC),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        disabledBackgroundColor: const Color(0xFFE0E0E0),
                        disabledForegroundColor: const Color(0xFF999999),
                        elevation: 0,
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ), // Column
          ), // SingleChildScrollView
        );  // Dialog/return
        }, // StatefulBuilder builder fn
      ),  // StatefulBuilder widget
    );  // showDialog
  }

  // Helper: numbered step row for maps instructions
  static Widget _mapsStep(String num, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(color: Color(0xFF1a73e8), shape: BoxShape.circle),
        child: Center(child: Text(num,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF333333), height: 1.4))),
    ],
  );


  Future<void> _loadAreas(String city) async {
    if (city.trim().isEmpty) { setState(() { _areas = []; }); return; }
    setState(() => _areasLoading = true);
    final areas = await Api.fetchAreas(city.trim());
    if (mounted) setState(() { _areas = areas; _areasLoading = false; });
    // If current _area.text is not in the new list, keep it (custom value)
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image too large. Max 2MB allowed."), backgroundColor: Colors.red));
      return;
    }
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image too large. Max 2MB allowed."), backgroundColor: Colors.red));
      return;
    }
    setState(() => _imgB64 = "data:image/jpeg;base64,${base64Encode(bytes)}");
  }


  Future<void> _pickImage2() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75, maxWidth: 800);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    setState(() => _img2B64 = "data:image/jpeg;base64,${base64Encode(bytes)}");
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) { setState(()=>_msg="Store name required"); return; }
    if (_selCity == null || _selCity!.trim().isEmpty) { setState(()=>_msg="Please select a city to continue"); return; }
    final _phoneVal = _phone.text.trim();
    if (_phoneVal.isEmpty) { setState(()=>_msg="Mobile number is required"); return; }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phoneVal)) { setState(()=>_msg="Enter a valid 10-digit mobile number (starts with 6–9)"); return; }
    setState(()=>_loading=true); _msg="";
    final data = {
      "store_name":_name.text.trim(),"category":_category,
      "state":_selState??"","city":_selCity??"","area":_area.text.trim(),
      "address":_addr.text.trim(),"phone":_phone.text.trim(),
      "lat":_lat.text.trim(),"lng":_lng.text.trim(),
      "about":_about.text.trim(),
      if(_openTime!=null)"open_time":_openTime!,
      if(_closeTime!=null)"close_time":_closeTime!,
      if(_imgB64!=null)"image":_imgB64,
      if(_img2B64!=null)"image2":_img2B64,
    };
    try {
      if (_isEdit) await Api.updateMerchantStore(widget.token, widget.store!["_id"], data);
      else         await Api.createMerchantStore(widget.token, data);
      if (!mounted) return;
      Navigator.pop(context);
    } catch(e) { setState(()=>_msg=e.toString().replaceAll("Exception: ","")); }
    if (mounted) setState(()=>_loading=false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(title:Text(_isEdit?"Edit Store":"Add Store"),backgroundColor: Colors.white, foregroundColor: kText),
    body: SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _field(_name,"Store Name *",Icons.store),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(value:_category.isEmpty?null:_category,
        items:[..._categories.map((e){final c=(e is Map?e['name']:e).toString();return DropdownMenuItem<String>(value:c,child:Text(c));})],
        onChanged:(v)=>setState(()=>_category=v??''),
        decoration:_dec("Category",Icons.category),
        hint:const Text("Select category")),
      const SizedBox(height:12),
      // GPS location capture
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text("Store Location", style: TextStyle(fontWeight: FontWeight.w700, color: kText, fontSize: 13)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _locLoading ? null : _captureGpsLocation,
            icon: _locLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.gps_fixed, size: 18),
            label: Text(_locLoading ? "Detecting..." : "Use Current Location"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white, foregroundColor: kText,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_locConfirmed && !_mapsApplied) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: kLight.withValues(alpha: .4), borderRadius: BorderRadius.circular(8)),
              child: const Text("✅ GPS location captured",
                  style: TextStyle(fontSize: 12, color: kPrimary, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 14),
          // ── Blinkit-style Google Maps inline input ──────────────────
          const Text("or paste Google Maps link",
              style: TextStyle(color: kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _mapsApplied
                    ? const Color(0xFF1a6640)
                    : _msg.contains('resolve') || _msg.contains('Could not')
                        ? const Color(0xFFc0392b)
                        : kBorder,
              ),
            ),
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _mapsResolving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))
                    : Image.asset('assets/images/google_maps_pin.png',
                        width: 22, height: 22,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.place, color: Color(0xFF4285F4), size: 22)),
              ),
              Expanded(
                child: TextField(
                  controller: _mapsUrlCtrl,
                  style: const TextStyle(fontSize: 13, color: kText),
                  decoration: const InputDecoration(
                    hintText: 'Paste Google Maps link here',
                    hintStyle: TextStyle(fontSize: 12, color: kMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (v) => _resolveMapsLink(v),
                  onChanged: (v) {
                    if (_mapsApplied) setState(() { _mapsApplied = false; _resolvedPlaceName = ''; _resolvedAddress = ''; });
                  },
                ),
              ),
              if (_mapsUrlCtrl.text.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() {
                    _mapsUrlCtrl.clear();
                    _mapsApplied = false;
                    _resolvedPlaceName = '';
                    _resolvedAddress = '';
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded, size: 18, color: kMuted),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          // Resolve button
          if (!_mapsApplied)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _mapsResolving ? null : () => _resolveMapsLink(_mapsUrlCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _mapsResolving
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Resolve Location", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          // ── Preview card (shows after successful resolve) ──
          if (_resolvedPlaceName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1a6640).withValues(alpha: .4)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1a6640), size: 16),
                  const SizedBox(width: 6),
                  const Text("google.com",
                      style: TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 6),
                Text(_resolvedPlaceName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kText)),
                if (_resolvedAddress.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_resolvedAddress,
                      style: const TextStyle(fontSize: 12, color: kMuted)),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _mapsApplied ? null : () => _resolveMapsLink(_mapsUrlCtrl.text),
                    icon: Icon(
                      _mapsApplied ? Icons.check_rounded : Icons.location_on_rounded,
                      size: 16),
                    label: Text(
                      _mapsApplied ? "✓ Location Applied" : "Apply Location",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mapsApplied ? const Color(0xFF1a6640) : kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(_lat, "Latitude", Icons.gps_fixed, type: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _field(_lng, "Longitude", Icons.gps_not_fixed, type: TextInputType.number)),
          ]),
          const SizedBox(height: 4),
          const Text("Auto-filled by GPS or Google Maps, or enter manually.",
              style: TextStyle(color: kMuted, fontSize: 11)),
        ]),
      ),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        value: kIndiaStates.contains(_selState)?_selState:null,
        items: kIndiaStates.map((s)=>DropdownMenuItem<String>(value:s,child:Text(s,style:const TextStyle(fontSize:13),overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v)=>setState((){_selState=v;_selCity=null;}),
        decoration:_dec("State *",Icons.map),
        hint:const Text("Select State",overflow:TextOverflow.ellipsis)),
      const SizedBox(height:12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        value: (_selState!=null && (kIndiaCities[_selState]??[]).contains(_selCity))?_selCity:null,
        items: (_selState==null?[]:kIndiaCities[_selState]??[]).map((c)=>DropdownMenuItem<String>(value:c,child:Text(c,style:const TextStyle(fontSize:13),overflow:TextOverflow.ellipsis))).toList(),
        onChanged:(v){ setState(()=>_selCity=v); if(v!=null) _loadAreas(v); },
        decoration:_dec("City *",Icons.location_city),
        hint:Text(_selState==null?"Select State first":"Select City",overflow:TextOverflow.ellipsis)),
      const SizedBox(height:12),
      // ── Area / Locality Dropdown ──────────────────────────────────────
      if (_areasLoading)
        const LinearProgressIndicator(minHeight: 2, color: kPrimary)
      else if (_areas.isNotEmpty)
        DropdownButtonFormField<String>(
          isExpanded: true,
          // current value: if _area.text is in list use it, else null (show hint)
          value: _areas.contains(_area.text) ? _area.text : null,
          items: _areas.map((a) => DropdownMenuItem<String>(
            value: a,
            child: Text(a, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: (v) { if (v != null) setState(() => _area.text = v); },
          decoration: _dec("Area / Locality", Icons.my_location),
          hint: const Text("Select area", overflow: TextOverflow.ellipsis),
        )
      else
        _field(_area, "Area / Locality", Icons.my_location),
      const SizedBox(height:12),
      _field(_addr,"Full Address",Icons.home),
      const SizedBox(height:12),
      _field(_phone,"Phone",Icons.phone,type:TextInputType.phone,maxLen:10),
      const SizedBox(height: 16),
      // Image picker
      GestureDetector(onTap:_pickImage,child:Container(height:150,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder,style:BorderStyle.solid)),
        child: _imgB64!=null
            ? ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(_imgB64!.split(",").last),fit:BoxFit.cover,width:double.infinity))
            : Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.add_a_photo,color:kMuted,size:36),const SizedBox(height:8),const Text("Image 1 — Main display card image",style:TextStyle(color:kMuted,fontSize:13))]))),
      const SizedBox(height:12),
      // Second image picker — optional logo
      const Text("Upload Logo [Optional]",style:TextStyle(color:kMuted,fontSize:12,fontWeight:FontWeight.w600)),
      const SizedBox(height:6),
      GestureDetector(onTap:_pickImage2,child:Container(height:110,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder,style:BorderStyle.solid)),
        child: _img2B64!=null
            ? Stack(children:[
                ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.memory(base64Decode(_img2B64!.split(",").last),fit:BoxFit.cover,width:double.infinity,height:110)),
                Positioned(top:6,right:6,child:GestureDetector(
                  onTap:(){setState(()=>_img2B64=null);},
                  child:Container(padding:const EdgeInsets.all(4),decoration:BoxDecoration(color:Colors.black54,shape:BoxShape.circle),child:const Icon(Icons.close,color:Colors.white,size:14)))),
              ])
            : Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.image_outlined,color:kMuted,size:32),const SizedBox(height:6),const Text("Tap to upload logo",style:TextStyle(color:kMuted,fontSize:12))]))),
      const SizedBox(height:12),
      // ── Opening & Closing Time ──────────────────────────────────────
      const SizedBox(height:12),
      const Text("Store Timings [Optional]",
        style: TextStyle(color: kMuted, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _openTime,
            isExpanded: true,
            items: _timeSlots().map((t) => DropdownMenuItem<String>(
              value: t["value"],
              child: Text(t["label"]!, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _openTime = v),
            decoration: _dec("Opening Time", Icons.access_time_rounded),
            hint: const Text("Open at", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _closeTime,
            isExpanded: true,
            items: _timeSlots().map((t) => DropdownMenuItem<String>(
              value: t["value"],
              child: Text(t["label"]!, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) => setState(() => _closeTime = v),
            decoration: _dec("Closing Time", Icons.access_time_filled_rounded),
            hint: const Text("Close at", style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ),
      ]),
      const SizedBox(height:16),
      // About field
      TextField(controller:_about, maxLines:4, keyboardType:TextInputType.multiline,
        decoration:_dec("About this store (description shown to customers)",Icons.info_outline).copyWith(
          alignLabelWithHint:true)),
      const SizedBox(height:20),
      SizedBox(height:50,child:ElevatedButton(
        onPressed:_loading?null:_save,
        style:ElevatedButton.styleFrom(backgroundColor:kPrimary,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
        child:_loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):
            Text(_isEdit?"Save Changes":"Create Store",style:const TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w700)))),
      if (_msg.isNotEmpty)...[const SizedBox(height:10),Text(_msg,textAlign:TextAlign.center,style:TextStyle(color:Colors.red.shade700,fontSize:13))],
      const SizedBox(height:24),
    ])),
  );

  Widget _field(TextEditingController c,String hint,IconData icon,{TextInputType type=TextInputType.text,int? maxLen}) =>
    TextField(controller:c,keyboardType:type,maxLength:maxLen,decoration:_dec(hint,icon).copyWith(counterText:maxLen!=null?"":null));
  InputDecoration _dec(String hint, IconData icon) => InputDecoration(
    hintText:hint,
    prefixIcon:Icon(icon,color:kMuted,size:20),
    filled:true,
    fillColor:Colors.white,
    contentPadding:const EdgeInsets.symmetric(vertical:14,horizontal:14),
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:kBorder)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:kBorder)),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:kPrimary,width:2)));
}

// ─────────── Subscribe Page ───────────
class SubscribePage extends StatefulWidget {
  final String token; final Map store;
  const SubscribePage({super.key,required this.token,required this.store});
  @override State<SubscribePage> createState() => _SubscribeState();
}
class _SubscribeState extends State<SubscribePage> {
  Map<String,dynamic> _pendingOrder = {};
  List _plans = []; bool _loading = true; String _selectedPlan = ""; String _fromDate = "";
  Map? _selectedPlanData; String _msg = "";
  final TextEditingController _discC = TextEditingController();
  String? _appliedCode; double _discountValue = 0; bool _validatingDisc = false; String _discMsg = "";

  // Razorpay instance must live for the lifetime of this page so its native
  // callbacks (success/error/external_wallet) are not garbage-collected while
  // the Razorpay native checkout activity is on top. Creating it inside a
  // local function caused the app to silently return after "Pay Now" on
  // newer Android versions.
  late final Razorpay _razorpay;

  @override void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaySuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR,   _onPayError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExtWallet);
    _loadPlans();
    _fromDate = DateTime.now().toIso8601String().substring(0,10);
  }

  @override void dispose() {
    _razorpay.clear();
    _discC.dispose();
    super.dispose();
  }

  Future<void> _openRazorpay(Map<String,dynamic> order) async {
    try {
      final amountPaise = (order["amount"] as num?)?.toInt() ??
          ((double.tryParse(order["amount_display"]?.toString() ?? "0") ?? 0) * 100).round();
      final opts = {
        'key': kRazorpayKey,
        'amount': amountPaise,
        'currency': 'INR',
        'order_id': order["razorpay_order_id"] ?? order["order_id"] ?? "",
        'name': 'Offro',
        'description': order["plan_label"] ?? 'Store Subscription',
        'prefill': {
          'contact': order["merchant_phone"] ?? "",
        },
        'image': 'https://offro-backend-production.up.railway.app/static/offro_logo.png',
        'theme': {'color': '#3E5F55'},
      };
      _razorpay.open(opts);
    } catch(e) {
      if (mounted) setState(() => _msg = 'Could not open payment: $e');
    }
  }

  Future<void> _onPaySuccess(PaymentSuccessResponse resp) async {
    if (!mounted) return;
    final payId = resp.paymentId ?? "";
    final ordId = resp.orderId ?? _pendingOrder["razorpay_order_id"] ?? "";
    final sig   = resp.signature ?? "";
    // Show "Confirming payment" dialog immediately so user sees action right away
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: Card(
        color: Colors.white,
        child: Padding(padding: EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: kPrimary),
          SizedBox(height: 16),
          Text("Confirming payment...", style: TextStyle(fontWeight: FontWeight.w600, color: kText)),
          SizedBox(height: 4),
          Text("Please wait a moment", style: TextStyle(color: kMuted, fontSize: 12)),
        ])),
      )),
    );
    // Verify payment synchronously (with retries)
    String invoiceNo = payId;
    try {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await Api.verifyPayment(widget.token, {
            "razorpay_payment_id": payId,
            "razorpay_order_id":   ordId,
            "razorpay_signature":  sig,
            "store_id": widget.store["_id"],
          });
          invoiceNo = result["invoice_no"]?.toString() ?? payId;
          break;
        } catch(e) {
          if (attempt < 2) await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    } catch (_) {}
    if (!mounted) return;
    // Dismiss the confirming dialog
    Navigator.of(context).pop();
    // Navigate immediately to success screen
    // push (not pushReplacement) keeps MerchantHome in stack
    Navigator.push(context, MaterialPageRoute(builder: (ctx) => PaymentSuccessScreen(
      storeName: widget.store["store_name"]?.toString() ?? "",
      invoiceNo: invoiceNo,
      onDone: () {
        Navigator.of(ctx).popUntil((route) => route.isFirst);
      },
    )));
  }

  void _onPayError(PaymentFailureResponse resp) {
    if (mounted) setState(() { final m = resp.message ?? ""; _msg = "Payment cancelled or failed: $m"; });
  }

  void _onExtWallet(ExternalWalletResponse resp) {
    if (mounted) setState(() { final w = resp.walletName ?? ""; _msg = "External wallet: $w"; });
  }

    Future<void> _validateDiscount() async {
    final code = _discC.text.trim();
    if (code.isEmpty) return;
    setState(()=>_validatingDisc=true);
    try {
      final r = await Api.validateDiscount(code);
      setState((){
        _appliedCode = r["code"];
        _discountValue = (r["value"] as num).toDouble();
        _discMsg = "✅ ₹${_discountValue.toStringAsFixed(0)} discount applied!";
      });
    } catch(e) {
      setState((){
        _appliedCode = null; _discountValue = 0;
        _discMsg = e.toString().replaceAll("Exception: ","");
      });
    }
    if (mounted) setState(()=>_validatingDisc=false);
  }

  Future<void> _loadPlans() async {
    _plans = await Api.getPlans(widget.token);
    if (_plans.isNotEmpty) { _selectedPlan = _plans[0]["id"]; _selectedPlanData = Map.from(_plans[0]); }
    if (mounted) setState(()=>_loading=false);
  }

  Future<void> _subscribe() async {
    if (_selectedPlan.isEmpty) return;
    setState(()=>_loading=true); _msg="";
    try {
      final order = await Api.initiateSubscription(widget.token, {
        "store_id":     widget.store["_id"],
        "plan":         _selectedPlan,
        "from_date":    _fromDate,
        if (_appliedCode != null) "discount_code": _appliedCode,
        if (_discountValue > 0) "discount_value": _discountValue,
      });
      if (!mounted) return;
      final payMode = order["pay_mode"] ?? "manual";
      // If amount is 0, always treat as manual (free plan / promo)
      final orderAmt = (order["amount"] as num?)?.toInt() ??
          ((double.tryParse(order["amount_display"]?.toString() ?? "0") ?? 0) * 100).round();

      // ── Manual / offline payment mode ──
      if (payMode == "manual" || orderAmt <= 0) {
        showDialog(context:context,barrierDismissible:false,builder:(ctx)=>AlertDialog(
          title:const Text("Subscription Request Sent",style:TextStyle(color:kPrimary,fontWeight:FontWeight.bold)),
          content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
            _row("Store", widget.store["store_name"]??''),
            _row("Plan",  order["plan_label"]??''),
            _row("From",  order["from_date"]??''),
            _row("To",    order["end_date"]??''),
            const Divider(),
            _row("Base Price","₹${order['base_price']}"),
            _row("GST (${order['gst_percent']}%)","₹${order['gst_amount']}"),
            _row("Total Payable","₹${order['amount_display']}",bold:true),
            const SizedBox(height:12),
            Container(
              padding:const EdgeInsets.all(10),
              decoration:BoxDecoration(color:kLight.withValues(alpha: .4),borderRadius:BorderRadius.circular(8)),
              child:const Text(
                "✅  Your subscription request has been submitted.\n\nPlease pay the amount to your Offro representative.\nThe admin will activate your store once payment is confirmed.",
                style:TextStyle(fontSize:12,color:kPrimary,height:1.5),
              ),
            ),
          ]),
          actions:[
            ElevatedButton(
              style:ElevatedButton.styleFrom(backgroundColor:kPrimary,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10))),
              onPressed:() async {
                Navigator.pop(ctx);
                // If amount is 0, activate immediately via free endpoint
                if (orderAmt <= 0) {
                  try {
                    await Api.activateFreeSubscription(widget.token, {
                      "store_id":       widget.store["_id"]?.toString() ?? "",
                      "subscription_id": order["subscription_id"]?.toString() ?? "",
                    });
                  } catch(_) {}
                }
                if (context.mounted) Navigator.pop(context);
              },
              child:const Text("OK",style:TextStyle(color:Colors.white))),
          ],
        ));
        return;
      }

      // ── Razorpay online mode ──
      setState(() => _pendingOrder = Map<String,dynamic>.from(order));
      final planLbl = order["plan_label"]?.toString() ?? _selectedPlan;
      // Use num conversion to avoid toString() showing "0" on valid values
      final baseP   = (order["base_price"] as num?)?.toStringAsFixed(2) ?? _selectedPlanData?["price"]?.toString() ?? "0";
      final gstPct  = (order["gst_percent"] as num?)?.toString() ?? "18";
      final gstAmt  = (order["gst_amount"] as num?)?.toStringAsFixed(2) ?? "0";
      final totalD  = (order["amount_display"] as num?)?.toStringAsFixed(2) ?? (order["total"] as num?)?.toStringAsFixed(2) ?? "0";
      final fromD   = order["from_date"]?.toString() ?? "";
      final toD     = order["end_date"]?.toString() ?? "";
      showDialog(context:context,builder:(_)=>AlertDialog(
        title:const Text("Confirm Payment",style:TextStyle(color:kPrimary,fontWeight:FontWeight.bold)),
        content:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
          _row("Store", widget.store["store_name"]?.toString()??''),
          _row("Plan",  planLbl),
          _row("From",  fromD),
          _row("To",    toD),
          const Divider(),
          _row("Base Price","₹$baseP"),
          _row("GST ($gstPct%)","₹$gstAmt"),
          _row("Total","₹$totalD",bold:true),
          const SizedBox(height:12),
          Container(padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:kLight.withValues(alpha: .4),borderRadius:BorderRadius.circular(8)),
            child:const Text("Razorpay checkout will open. After payment, admin will approve your store.",style:TextStyle(fontSize:12,color:kPrimary))),
        ]),
        actions:[
          TextButton(onPressed:()=>Navigator.pop(context),child:const Text("Cancel",style:TextStyle(color:kMuted))),
          ElevatedButton(
            style:ElevatedButton.styleFrom(backgroundColor:kPrimary),
            onPressed:() {
              Navigator.pop(context);
              _openRazorpay(_pendingOrder);
            },
            child:const Text("Pay Now",style:TextStyle(color:Colors.white))),
        ],
      ));
    } catch(e) {
      if (mounted) setState(()=>_msg=e.toString().replaceAll("Exception: ",""));
    }
    if (mounted) setState(()=>_loading=false);
  }

  Widget _row(String k,String v,{bool bold=false}) => Padding(padding:const EdgeInsets.symmetric(vertical:3),
    child:Row(children:[Expanded(child:Text(k,style:const TextStyle(color:kMuted,fontSize:13))),Text(v,style:TextStyle(fontSize:13,fontWeight:bold?FontWeight.bold:FontWeight.w500,color:bold?kPrimary:kText))]));

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(title:const Text("Subscribe Store"),backgroundColor: Colors.white, foregroundColor: kText),
    body:_loading?const Center(child:CircularProgressIndicator(color:kPrimary)):SingleChildScrollView(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Store",style:TextStyle(color:kMuted,fontSize:11,fontWeight:FontWeight.w600)),
          Text(widget.store["store_name"]??"",style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:kText)),
          Text("${widget.store['city']??''}, ${widget.store['area']??''}",style:const TextStyle(color:kMuted,fontSize:12)),
        ])),
      const SizedBox(height:20),
      const Text("Select Plan",style:TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:15)),
      const SizedBox(height:10),
      ..._plans.map((p){
        final sel = _selectedPlan==p["id"];
        return GestureDetector(onTap:()=>setState((){_selectedPlan=p["id"];_selectedPlanData=Map.from(p);}),
          child:Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:sel?kPrimary:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:sel?kPrimary:kBorder,width:sel?2:1)),
            child:Row(children:[
              Icon(sel?Icons.radio_button_checked:Icons.radio_button_unchecked,color:sel?Colors.white:kMuted),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(p["label"],style:TextStyle(fontWeight:FontWeight.bold,color:sel?Colors.white:kText)),
                Text("₹${p['price']} + ${p['gst_percent']}% GST",style:TextStyle(fontSize:12,color:sel?kLight:kMuted)),
              ])),
              Text("₹${p['total']}",style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:sel?Colors.white:kPrimary)),
            ])));
      }).toList(),
      const SizedBox(height:16),
      const Text("Start Date",style:TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:15)),
      const SizedBox(height:8),
      GestureDetector(
        onTap:() async {
          final d = await showDatePicker(context:context,initialDate:DateTime.now(),firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:60)),
            builder:(ctx,child)=>Theme(data:ThemeData(colorScheme:const ColorScheme.light(primary:kPrimary)),child:child!));
          if (d!=null) setState(()=>_fromDate=d.toIso8601String().substring(0,10));
        },
        child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
          child:Row(children:[const Icon(Icons.calendar_today,color:kPrimary,size:18),const SizedBox(width:10),Text(_fromDate,style:const TextStyle(color:kText,fontWeight:FontWeight.w600))]))),
      if (_selectedPlanData!=null)...[
        const SizedBox(height:16),
        Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:kLight.withValues(alpha: .5),borderRadius:BorderRadius.circular(12)),
          child:Column(children:[
            _row("Base Price","₹${_selectedPlanData!['price']}"),
            _row("GST (${_selectedPlanData!['gst_percent']}%)","₹${_selectedPlanData!['gst_amount']}"),
            const Divider(height:16),
            _row("Total Payable","₹${_selectedPlanData!['total']}",bold:true),
          ])),
      ],
      const SizedBox(height:16),
      // ── Discount Code ──
      Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text("Have a discount code?",style:TextStyle(fontWeight:FontWeight.w600,color:kText,fontSize:13)),
          const SizedBox(height:8),
          Row(children:[
            Expanded(child:TextField(
              controller:_discC,
              textCapitalization:TextCapitalization.characters,
              decoration:InputDecoration(hintText:"Enter code",isDense:true,contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:10),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8),borderSide:BorderSide(color:kBorder))),
            )),
            const SizedBox(width:8),
            ElevatedButton(
              onPressed:_validatingDisc?null:_validateDiscount,
              style:ElevatedButton.styleFrom(backgroundColor:kPrimary,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8)),padding:const EdgeInsets.symmetric(horizontal:14,vertical:10)),
              child:_validatingDisc?const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2)):const Text("Apply",style:TextStyle(color:Colors.white,fontSize:13))),
          ]),
          if (_discMsg.isNotEmpty)...[const SizedBox(height:6),Text(_discMsg,style:TextStyle(fontSize:12,color:_appliedCode!=null?const Color(0xFF1a6640):Colors.red.shade700))],
          if (_appliedCode!=null && _discountValue>0)...[
            const SizedBox(height:6),
            Row(children:[const Text("Discount: ",style:TextStyle(fontSize:12,color:kMuted)),Text("- ₹${_discountValue.toStringAsFixed(0)}",style:const TextStyle(fontSize:12,color:Color(0xFF1a6640),fontWeight:FontWeight.bold)),
              const Spacer(),
              GestureDetector(onTap:(){setState((){_appliedCode=null;_discountValue=0;_discMsg="";_discC.clear();});},child:const Text("Remove",style:TextStyle(fontSize:11,color:Colors.red,decoration:TextDecoration.underline)))]),
          ],
        ])),
      const SizedBox(height:24),
      SizedBox(height:52,child:ElevatedButton(
        onPressed:_loading?null:_subscribe,
        style:ElevatedButton.styleFrom(backgroundColor:kPrimary,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
        child:const Text("Proceed to Pay",style:TextStyle(color:Colors.white,fontSize:16,fontWeight:FontWeight.w700)))),
      if (_msg.isNotEmpty)...[const SizedBox(height:10),Text(_msg,textAlign:TextAlign.center,style:TextStyle(color:Colors.red.shade700,fontSize:13))],
      const SizedBox(height:24),
    ])),
  );
}

// ─────────── Merchant Invoices Page ───────────
class MerchantInvoicesPage extends StatefulWidget {
  final String token; const MerchantInvoicesPage({super.key,required this.token});
  @override State<MerchantInvoicesPage> createState() => _InvoicesState();
}
class _InvoicesState extends State<MerchantInvoicesPage> {
  List _invoices=[]; bool _loading=true;
  @override void initState(){ super.initState(); _load(); }
  Future<void> _load() async {
    if(mounted) setState(()=>_loading=true);
    _invoices = await Api.getFullInvoices(widget.token);  // T2: shows banner + product invoices too
    if(mounted) setState(()=>_loading=false);
  }

  // FIX 14: Build printable HTML for an invoice
  String _buildInvoiceHtml(Map inv) => """
<!DOCTYPE html><html><head><meta charset='utf-8'>
<style>
  body{font-family:Arial,sans-serif;padding:24px;color:#2c3e35;max-width:600px;margin:0 auto;}
  .header{background:#3E5F55;color:white;padding:20px 24px;border-radius:10px;margin-bottom:24px;}
  .header h1{margin:0;font-size:22px;} .header p{margin:4px 0;font-size:13px;opacity:.85;}
  .section{background:#fff;border:1px solid #d4e8de;border-radius:8px;padding:16px;margin-bottom:16px;}
  .row{display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid #f0f0f0;}
  .row:last-child{border-bottom:none;}
  .label{color:#6b8c7e;font-size:13px;} .value{font-size:13px;font-weight:600;color:#2c3e35;}
  .total-row{background:#CDEBD6;border-radius:6px;padding:10px 14px;display:flex;justify-content:space-between;margin-top:12px;}
  .total-label{font-weight:bold;color:#2c3e35;} .total-value{font-weight:bold;color:#3E5F55;font-size:16px;}
  .badge{display:inline-block;background:#CDEBD6;color:#3E5F55;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:bold;}
  .footer{text-align:center;color:#6b8c7e;font-size:11px;margin-top:24px;}
</style></head><body>
<div class='header'>
  <h1>OFFRO</h1>
  <p>Tax Invoice</p>
  <p>${inv['invoice_no']??''}</p>
</div>
<div class='section'>
  <div class='row'><span class='label'>Store</span><span class='value'>${inv['store_name']??''}</span></div>
  <div class='row'><span class='label'>Plan</span><span class='value'>${inv['plan']??''}</span></div>
  <div class='row'><span class='label'>Period</span><span class='value'>${inv['from_date']??''} – ${inv['end_date']??''}</span></div>
  <div class='row'><span class='label'>Date</span><span class='value'>${inv['created_at']?.toString().substring(0,10)??''}</span></div>
</div>
<div class='section'>
  <div class='row'><span class='label'>Base Amount</span><span class='value'>₹${inv['base_price']??0}</span></div>
  <div class='row'><span class='label'>GST (18%)</span><span class='value'>₹${inv['gst']??0}</span></div>
  <div class='total-row'><span class='total-label'>Total Paid</span><span class='total-value'>₹${inv['total']??0}</span></div>
</div>
<div class='footer'>OFFRO — Thank you for your business!<br>This is a system-generated invoice.</div>
</body></html>
""";

  // FIX 14: Share invoice as text
  void _shareInvoice(Map inv) {
    final text = [
      "OFFRO — Invoice",
      "Invoice No: ${inv['invoice_no']??''}",
      "Store: ${inv['store_name']??''}",
      "Plan: ${inv['plan']??''}",
      "Period: ${inv['from_date']??''} – ${inv['end_date']??''}",
      "Base: ₹${inv['base_price']??0}  GST: ₹${inv['gst']??0}",
      "Total Paid: ₹${inv['total']??0}",
      "Date: ${inv['created_at']?.toString().substring(0,10)??''}",
    ].join("\n");
    Share.share(text, subject: "OFFRO Invoice ${inv['invoice_no']??''}");
  }

  // FIX 14: Print/Download PDF
  Future<void> _printInvoice(Map inv) async {
    await Printing.layoutPdf(
      onLayout: (fmt) async => await Printing.convertHtml(
        format: fmt,
        html: _buildInvoiceHtml(inv),
      ),
      name: "OFFRO_Invoice_${inv['invoice_no']??''}",
    );
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(
      title:Row(children:[buildImageLogo(height:24,white:true),const SizedBox(width:8),const Text("Invoices",style:TextStyle(fontWeight:FontWeight.w800))]),
      backgroundColor: Colors.white, foregroundColor: kText,automaticallyImplyLeading:false,
      actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:_load,tooltip:"Refresh")],
    ),
    body:_loading?const Center(child:CircularProgressIndicator(color:kPrimary)):
    RefreshIndicator(
      color:kPrimary,onRefresh:_load,
      child:_invoices.isEmpty
        ? ListView(children:[SizedBox(height:MediaQuery.of(context).size.height*0.4,
            child:const Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
              Icon(Icons.receipt_long_outlined,size:56,color:kAccent),
              SizedBox(height:12),
              Text("No invoices yet",style:TextStyle(color:kMuted,fontSize:15)),
              SizedBox(height:6),
              Text("Pull down to refresh",style:TextStyle(color:kMuted,fontSize:12)),
            ])))])
        : ListView.builder(
            padding:const EdgeInsets.all(14),
            itemCount:_invoices.length,
            itemBuilder:(_,i){
              final inv = _invoices[i] as Map;
              return Card(elevation:1,margin:const EdgeInsets.only(bottom:10),
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),
                child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[
                    const Icon(Icons.receipt_long,color:kPrimary,size:16),
                    const SizedBox(width:6),
                    Expanded(child:Text(inv["invoice_no"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kPrimary,fontSize:13))),
                    Text(_fmtDateTime(inv["created_at"]?.toString()),style:const TextStyle(color:kMuted,fontSize:11)),
                  ]),
                  const Divider(height:14),
                  Text(inv["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kText)),
                  Text("Plan: ${inv['plan']??''}  •  ${inv['from_date']??''} – ${inv['end_date']??''}",style:const TextStyle(color:kMuted,fontSize:12)),
                  const SizedBox(height:6),
                  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                    // TASK 6: show discount info if present
                    Builder(builder: (_) {
                      final origAmt  = (inv["original_amount"] ?? inv["base_price"] ?? 0) as num;
                      final discCode = inv["discount_code"]?.toString() ?? "";
                      final discAmt  = (inv["discount_amount"] ?? 0) as num;
                      final gstAmt   = (inv["gst"] ?? 0) as num;
                      final totalAmt = (inv["total"] ?? 0) as num;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Base: ₹${origAmt.toStringAsFixed(2)}  GST: ₹${gstAmt.toStringAsFixed(2)}",
                            style:const TextStyle(color:kMuted,fontSize:12)),
                          if(discCode.isNotEmpty && discAmt > 0)
                            Text("Discount ($discCode): −₹${discAmt.toStringAsFixed(2)}",
                              style:const TextStyle(color:Color(0xFF1a6640),fontSize:11,fontWeight:FontWeight.w600)),
                        ],
                      );
                    }),
                    Text("₹${((inv["total"]??0) as num).toStringAsFixed(2)}",
                      style:const TextStyle(fontWeight:FontWeight.bold,color:kPrimary,fontSize:15)),
                  ]),
                  const SizedBox(height:12),
                  // FIX 14: Action buttons
                  Row(children:[
                    Expanded(child:OutlinedButton.icon(
                      icon:const Icon(Icons.share_rounded,size:16),
                      label:const Text("Share",style:TextStyle(fontSize:12)),
                      style:OutlinedButton.styleFrom(
                        foregroundColor:kPrimary,side:const BorderSide(color:kPrimary),
                        padding:const EdgeInsets.symmetric(vertical:8),
                        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                      onPressed:()=>_shareInvoice(inv),
                    )),
                    const SizedBox(width:10),
                    Expanded(child:ElevatedButton.icon(
                      icon:const Icon(Icons.download_rounded,size:16),
                      label:const Text("Download PDF",style:TextStyle(fontSize:12)),
                      style:ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: kText,
                        padding:const EdgeInsets.symmetric(vertical:8),
                        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8))),
                      onPressed:()=>_printInvoice(inv),
                    )),
                  ]),
                ])));
            }),
    ),
  );
}

// ─────────── Merchant Activity Page (FIX 7) ───────────

// Humanize raw transaction type/description codes → readable text
String _humanizeActivity(String raw) {
  const _map = {
    "account_created":        "Account registered",
    "store_created":          "New store created",
    "store_updated":          "Store profile updated",
    "store_approved":         "Store approved",
    "store_rejected":         "Store rejected",
    "subscription":           "Store subscription activated",
    "subscription_free":      "Free subscription activated",
    "subscription_paid":      "Subscription payment received",
    "banner":                 "Banner submitted",
    "banner_approved":        "Banner approved",
    "banner_rejected":        "Banner rejected",
    "banner_paid":            "Banner payment received",
    "product":                "Product submitted",
    "product_approved":       "Product approved",
    "product_rejected":       "Product rejected",
    "product_paid":           "Product payment received",
    "payment":                "Payment received",
    "free":                   "Free plan activated",
    "profile_updated":        "Profile updated",
    "qr_reset":               "QR code regenerated",
  };
  final key = raw.trim().toLowerCase().replaceAll(' ', '_');
  // If it's already a human-readable string (contains spaces or title case), return as-is
  if (raw.contains(' ') && !raw.contains('_')) return raw;
  return _map[key] ?? raw.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? '' : '\${w[0].toUpperCase()}\${w.substring(1)}').join(' ');
}

class MerchantTxnPage extends StatefulWidget {
  final String token; const MerchantTxnPage({super.key,required this.token});
  @override State<MerchantTxnPage> createState() => _TxnState();
}
class _TxnState extends State<MerchantTxnPage> {
  List _txns=[]; List _banners=[]; List _products=[];
  bool _loading=true;
  int _tab=0; // 0=All, 1=Banners, 2=Products, 3=Payments
  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if(mounted) setState(()=>_loading=true);
    final results = await Future.wait([
      Api.getMerchantTransactions(widget.token),
      Api.getMerchantBanners(widget.token),
      Api.getMerchantProducts(widget.token),
    ]);
    if(mounted) setState((){
      _txns    = results[0];
      _banners = results[1];
      _products= results[2];
      _loading = false;
    });
  }

  List<Map> get _allActivity {
    final events = <Map>[];
    // Payments/subscriptions from txns
    for(final t in _txns) {
      events.add({
        "type":"payment","icon":Icons.payment,"color":kPrimary,
        "title":_humanizeActivity(t["description"]?.toString()??t["plan"]?.toString()??"Payment"),
        "subtitle":"₹${t['amount']??0}",
        "date":t["date"]??t["created_at"]??"",
        "amount":t["amount"]??0,
      });
    }
    // Banner events
    for(final b in _banners) {
      final st=(b["approval_status"]??b["status"]??"pending").toString();
      final (Color sc,IconData si) = switch(st){
        "approved"   => (const Color(0xFF1a6640), Icons.check_circle_outline),
        "rejected"   => (Colors.red, Icons.cancel_outlined),
        _ => (const Color(0xFF856404), Icons.hourglass_top_rounded),
      };
      events.add({
        "type":"banner","icon":Icons.photo_size_select_actual_outlined,"color":const Color(0xFF2980b9),
        "title":"Banner: ${b['title']??'Untitled'}",
        "subtitle":st=="approved"?"✅ Approved — Live":st=="rejected"?"❌ Rejected":"⏳ Pending Approval",
        "subtitle_color":sc,"status_icon":si,
        "date":b["created_at"]??"",
        "amount":b["amount"]??0,
        "from_date":b["from_date"]??"",
        "end_date":b["end_date"]??"",
      });
    }
    // Product events
    for(final v in _products) {
      final st=(v["approval_status"]??v["status"]??"pending").toString();
      final (Color sc,IconData si) = switch(st){
        "approved"   => (const Color(0xFF1a6640), Icons.check_circle_outline),
        "rejected"   => (Colors.red, Icons.cancel_outlined),
        _ => (const Color(0xFF856404), Icons.hourglass_top_rounded),
      };
      events.add({
        "type":"product","icon":Icons.local_activity_outlined,"color":const Color(0xFF8e44ad),
        "title":"Product: ${v['title']??'Untitled'}",
        "subtitle":st=="approved"?"✅ Approved — Live":st=="rejected"?"❌ Rejected":"⏳ Pending Approval",
        "subtitle_color":sc,"status_icon":si,
        "date":v["created_at"]??"",
        "amount":v["amount"]??0,
        "from_date":v["from_date"]??"",
        "end_date":v["end_date"]??"",
      });
    }
    // Sort by date descending
    events.sort((a,b){
      try{return (b["date"]??'').compareTo(a["date"]??'');}catch(_){return 0;}
    });
    return events;
  }

  List<Map> get _filtered {
    if(_tab==0) return _allActivity;
    if(_tab==1) return _allActivity.where((e)=>e["type"]=="banner").toList();
    if(_tab==2) return _allActivity.where((e)=>e["type"]=="product").toList();
    return _allActivity.where((e)=>e["type"]=="payment").toList();
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(
      title:Row(children:[buildImageLogo(height:24,white:true),const SizedBox(width:8),const Text("Activity",style:TextStyle(fontWeight:FontWeight.w800))]),
      backgroundColor: Colors.white, foregroundColor: kText,automaticallyImplyLeading:false,
      actions:[IconButton(icon:const Icon(Icons.refresh),onPressed:_load)],
    ),
    body:Column(children:[
      // Filter tabs
      Container(decoration:const BoxDecoration(color:kPrimary),padding:const EdgeInsets.fromLTRB(12,0,12,10),
        child:Row(children:["All","Banners","My Products","Payments"].asMap().entries.map((e)=>
          GestureDetector(
            onTap:()=>setState(()=>_tab=e.key),
            child:Container(
              margin:const EdgeInsets.only(right:8),
              padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
              decoration:BoxDecoration(
                color:_tab==e.key?Colors.white:Colors.white.withValues(alpha:.18),
                borderRadius:BorderRadius.circular(20)),
              child:Text(e.value,style:TextStyle(
                color:_tab==e.key?kPrimary:Colors.white,
                fontSize:12,fontWeight:FontWeight.w700)),
            ),
          )).toList()),
      ),  // close filter-tabs Container
      // Content
      Expanded(child:_loading
        ? const Center(child:CircularProgressIndicator(color:kPrimary))
        : RefreshIndicator(
            color:kPrimary,onRefresh:_load,
            child:_filtered.isEmpty
              ? ListView(children:[SizedBox(height:300,child:Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                  const Icon(Icons.history,size:48,color:kAccent),
                  const SizedBox(height:12),
                  const Text("No activity yet",style:TextStyle(color:kMuted,fontSize:15)),
                ])))])
              : ListView.builder(
                  padding:const EdgeInsets.fromLTRB(14,12,14,24),
                  itemCount:_filtered.length,
                  itemBuilder:(_,i){
                    final t = _filtered[i];
                    final Color ic = t["color"] as Color? ?? kPrimary;
                    final Color sc = t["subtitle_color"] as Color? ?? kMuted;
                    return Container(
                      margin:const EdgeInsets.only(bottom:8),
                      padding:const EdgeInsets.all(14),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
                      child:Row(children:[
                        CircleAvatar(backgroundColor:ic.withValues(alpha:.12),radius:20,
                          child:Icon(t["icon"] as IconData,color:ic,size:18)),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(t["title"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:13)),
                          const SizedBox(height:2),
                          Text(t["subtitle"]??"",style:TextStyle(color:sc,fontSize:11,fontWeight:FontWeight.w600)),
                          if((t["from_date"]??"").isNotEmpty && (t["end_date"]??"").isNotEmpty)
                            Text("${t['from_date']} → ${t['end_date']}",style:const TextStyle(color:kMuted,fontSize:10)),
                          const SizedBox(height:2),
                          Text(_fmtDateTime(t["date"]?.toString()),style:const TextStyle(color:kMuted,fontSize:10)),
                        ])),
                        if((t["amount"]??0)>0)
                          Text("₹${t['amount']}",style:const TextStyle(color:kPrimary,fontWeight:FontWeight.bold,fontSize:13)),
                      ]),
                    );
                  }),
          )),
    ]),
  );
}

// ─────────── Merchant Profile Page ───────────
class MerchantProfilePage extends StatefulWidget {
  final String token; final Map merchant;
  const MerchantProfilePage({super.key,required this.token,required this.merchant});
  @override State<MerchantProfilePage> createState() => _MerchantProfileState();
}
class _MerchantProfileState extends State<MerchantProfilePage> {
  String? _imgB64;
  bool _uploading = false;
  late Map<String, dynamic> _merchantData;

  @override void initState() {
    super.initState();
    _merchantData = Map<String, dynamic>.from(widget.merchant);
    _imgB64 = _merchantData["profile_image"] as String?;
    _fetchLatestProfile();
  }

  Future<void> _fetchLatestProfile() async {
    try {
      final fresh = await Api.getMerchantProfile(widget.token);
      if (fresh != null && mounted) {
        setState(() {
          _merchantData = fresh;
          _imgB64 = fresh["profile_image"] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Image too large. Max 2MB allowed."), backgroundColor: Colors.red));
      return;
    }
    final b64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
    setState(() { _uploading = true; _imgB64 = b64; });
    try {
      await Api.updateMerchantProfile(widget.token, {"profile_image": b64});
      await _fetchLatestProfile();
    } catch(_) {}
    if (mounted) setState(() => _uploading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:kBg,
    appBar:AppBar(
      title:Row(children:[buildImageLogo(height:24,white:true),const SizedBox(width:8),const Text("Profile",style:TextStyle(fontWeight:FontWeight.w800))]),
      backgroundColor: Colors.white, foregroundColor: kText,automaticallyImplyLeading:false),
    body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:kPrimary,borderRadius:BorderRadius.circular(16)),
        child:Column(children:[
          GestureDetector(
            onTap: _pickProfileImage,
            child: Stack(alignment:Alignment.bottomRight,children:[
              CircleAvatar(radius:44, backgroundColor:kAccent,
                backgroundImage: _imgB64 != null && _imgB64!.startsWith("data:") ? MemoryImage(base64Decode(_imgB64!.split(",").last)) : null,
                child: _imgB64 == null ? buildLogo(38,kLight) : null),
              Container(width:26,height:26,decoration:const BoxDecoration(color:Colors.white,shape:BoxShape.circle),
                child: _uploading ? const Padding(padding:EdgeInsets.all(4),child:CircularProgressIndicator(strokeWidth:2,color:kPrimary)) : const Icon(Icons.camera_alt,size:16,color:kPrimary)),
            ])),
          const SizedBox(height:8),
          Text(_merchantData["name"]??"",style:const TextStyle(color:Colors.white,fontSize:18,fontWeight:FontWeight.bold)),
          Text(_merchantData["phone"]??"",style:const TextStyle(color:kAccent)),
          if((_merchantData["city"]??'').isNotEmpty)
            Text("${_merchantData['city']}, ${_merchantData['area']??''}",style:const TextStyle(color:kAccent,fontSize:12)),
          const SizedBox(height:4),
          const Text("Tap photo to change",style:TextStyle(color:kLight,fontSize:10)),
        ])),
      const SizedBox(height:20),
      _tile(context,Icons.info_outline,"About Us",() => _openAbout(context)),
      _tile(context,Icons.description,"Terms & Conditions",() => _openPolicy(context,"Terms & Conditions",Api.getMerchantTerms())),
      _tile(context,Icons.privacy_tip,"Privacy Policy",() => _openPolicy(context,"Privacy Policy",Api.fetchPolicy("privacy"))),
      _tile(context,Icons.receipt,"Refund Policy",() => _openPolicy(context,"Refund Policy",Api.fetchPolicy("refund"))),
      _tile(context,Icons.badge,"KYC Policy",() => _openPolicy(context,"KYC Policy",Api.fetchPolicy("kyc"))),
      const SizedBox(height:8),
      ListTile(tileColor:const Color(0xFFe8faf0),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:const BorderSide(color:Color(0xFF25D366))),
        leading:const CircleAvatar(backgroundColor:Color(0xFF25D366),child:Icon(Icons.chat_bubble,color:Colors.white)),
        title:const Text("Contact Offro",style:TextStyle(fontWeight:FontWeight.bold,color:Color(0xFF1a7a3c))),
        subtitle:const Text("Chat with us on WhatsApp",style:TextStyle(fontSize:11,color:Color(0xFF25D366))),
        trailing:const Icon(Icons.chevron_right,color:Color(0xFF25D366)),
        onTap:()async{final s=await Api.getSocialLinks();
          final rawWa=s["whatsapp"]??"";
          if(rawWa.isNotEmpty){
            final digits=rawWa.replaceAll(RegExp(r'[^0-9]'),'');
            final waNum=digits.length>=10?(digits.length==10?"91$digits":digits):digits;
            await launchUrl(Uri.parse("https://wa.me/$waNum"),mode:LaunchMode.externalApplication);
          }}),
      const SizedBox(height:20),
      // ── Switch Mode ──
      SizedBox(height:48, child: OutlinedButton.icon(
        icon: const Icon(Icons.swap_horiz_rounded, color: kPrimary),
        label: const Text("Switch Mode", style: TextStyle(color: kPrimary, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: kPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => SwitchModeSheet(
              currentMode: 'merchant',
              token: widget.token,
              phone: widget.merchant['phone']?.toString() ?? '',
              onSwitch: (role) {
                if (role == 'user') {
                  // Switch to User → GPS loader
                  final token = widget.token;
                  final name  = widget.merchant['name']?.toString() ?? '';
                  final phone = widget.merchant['phone']?.toString() ?? '';
                  final uid   = widget.merchant['merchant_id']?.toString() ?? widget.merchant['_id']?.toString() ?? '';
                  Navigator.of(context).pop(); // close profile
                  MyApp.goSwitchMode(token, name, phone, uid, 'user');
                }
              },
            ),
          );
        })),
      const SizedBox(height:12),
      SizedBox(height:48,child:OutlinedButton.icon(
        icon:const Icon(Icons.logout,color:Colors.red),label:const Text("Logout",style:TextStyle(color:Colors.red)),
        style:OutlinedButton.styleFrom(side:const BorderSide(color:Colors.red),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
        onPressed:() async {
            await Prefs.clear(keepMode: false);
            Api.clearCache();
            if (!context.mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => LoginScreen()),
              (_) => false,
            );
          })),
    ])),
  );

  Widget _tile(BuildContext ctx, IconData icon, String title, VoidCallback onTap) =>
    ListTile(tileColor:Colors.white,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:const BorderSide(color:kBorder)),
      leading:CircleAvatar(backgroundColor:kLight,child:Icon(icon,color:kPrimary)),
      title:Text(title,style:const TextStyle(fontWeight:FontWeight.bold,color:kText)),
      trailing:const Icon(Icons.chevron_right,color:kPrimary),onTap:onTap,
      contentPadding:const EdgeInsets.symmetric(horizontal:14,vertical:4));

  void _openAbout(BuildContext ctx) async {
    final c = await Api.getAboutUs();
    if (!ctx.mounted) return;
    showDialog(context:ctx, builder:(_)=>OffroDialog(title:"About Us",body:c.isEmpty?"Offro connects local stores with customers through deals and loyalty points.":c));
  }

  void _openPolicy(BuildContext ctx, String title, Future<String> loader) {
    showDialog(context:ctx, barrierDismissible:false,
      builder:(_)=>FutureBuilder<String>(future:loader,
        builder:(c,snap){
          if(snap.connectionState!=ConnectionState.done) return const AlertDialog(content:SizedBox(height:80,child:Center(child:CircularProgressIndicator(color:kPrimary))));
          return OffroDialog(title:title,body:snap.data??"");
        }));
  }
}


// ─────────── User Profile Header (with image upload) ───────────
class UserProfileHeader extends StatefulWidget {
  final String token, name, phone;
  const UserProfileHeader({required this.token, required this.name, required this.phone});
  @override State<UserProfileHeader> createState() => _UserProfileHeaderState();
}
class _UserProfileHeaderState extends State<UserProfileHeader> {
  String? _imgB64;
  bool _uploading = false;

  @override void initState() {
    super.initState();
    _loadProfileImage();
  }

  Future<void> _loadProfileImage() async {
    try {
      final d = await Api.getMe(widget.token);
      if (mounted && d != null && d["profile_image"] != null) setState(()=>_imgB64=d["profile_image"]);
    } catch(_){}
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 600);
    if (img == null) return;
    final bytes = await File(img.path).readAsBytes();
    final b64 = "data:image/jpeg;base64,${base64Encode(bytes)}";
    setState(() { _uploading = true; _imgB64 = b64; });
    try { await Api.updateUserProfile(widget.token, {"profile_image": b64}); } catch(_) {}
    if (mounted) setState(() => _uploading = false);
  }

  @override Widget build(BuildContext context) => ListTile(
    leading: GestureDetector(
      onTap: _pickImage,
      child: Stack(alignment:Alignment.bottomRight, children:[
        CircleAvatar(radius:24, backgroundColor:kLight,
          backgroundImage: _imgB64 != null && _imgB64!.startsWith("data:")
            ? MemoryImage(base64Decode(_imgB64!.split(",").last)) : null,
          child: _imgB64 == null ? const Icon(Icons.person, color:kPrimary) : null),
        Container(width:16,height:16,decoration:const BoxDecoration(color:kPrimary,shape:BoxShape.circle),
          child: _uploading ? const Padding(padding:EdgeInsets.all(2),child:CircularProgressIndicator(strokeWidth:1.5,color:Colors.white)) : const Icon(Icons.camera_alt,size:10,color:Colors.white)),
      ])),
    title: Text(widget.name, style:const TextStyle(fontWeight:FontWeight.bold)),
    subtitle: Text(widget.phone),
  );
}

// ─────────────────────── USER HOME ───────────────────────


// ─── MERCHANT DEALS ───────────────────────────────────
class MerchantDealsPage extends StatefulWidget {
  final String token;
  const MerchantDealsPage({super.key, required this.token});
  @override State<MerchantDealsPage> createState() => _MerchantDealsState();
}
class _MerchantDealsState extends State<MerchantDealsPage> {
  List<Map<String,dynamic>> _deals = []; List<Map<String,dynamic>> _stores = []; bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _deals = List<Map<String,dynamic>>.from(await Api.getMerchantDeals(widget.token));
    _stores = List<Map<String,dynamic>>.from(await Api.getMerchantStores(widget.token));
    if (mounted) setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(title:Row(children:[buildImageLogo(height:24,white:true),const SizedBox(width:8),const Text("My Deals",style:TextStyle(fontWeight:FontWeight.w800))]), backgroundColor: Colors.white, foregroundColor: kText, automaticallyImplyLeading:false),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: Colors.white, foregroundColor: kText,
      icon: const Icon(Icons.add), label: const Text("Add Deal"),
      onPressed: () {
        final activeStores = _stores.where((s) => s["status"] == "active").toList();
        if (activeStores.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("You need an active store to add deals."), backgroundColor: Colors.orange));
          return;
        }
        Navigator.push(context, _offroRoute(AddDealPage(
          token: widget.token,
          storeId: activeStores[0]["_id"] ?? "",
          storeName: activeStores[0]["store_name"] ?? "",
          stores: activeStores,
        ))).then((_) => _load());
      }),
    body: _loading ? const Center(child: CircularProgressIndicator(color: kPrimary)) :
      _deals.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.local_offer_outlined, size: 64, color: kAccent),
        const SizedBox(height: 12),
        const Text("No deals yet", style: TextStyle(color: kMuted, fontSize: 16)),
        const SizedBox(height: 8),
        const Text("Add deals to attract more customers", style: TextStyle(color: kMuted, fontSize: 13)),
      ])) :
      RefreshIndicator(onRefresh: _load, child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: _deals.length,
        itemBuilder: (_, i) {
          final d = _deals[i] as Map;
          return Card(elevation: 2, margin: const EdgeInsets.only(bottom: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Container(width: 44, height: 44,
                decoration: BoxDecoration(color: kLight.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text("${d['discount'] ?? 0}%",
                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13)))),
              title: Text(d["title"] ?? "", style: const TextStyle(fontWeight: FontWeight.w600, color: kText)),
              subtitle: Text("${d['store_name'] ?? ''} • ${d['category'] ?? ''}", style: const TextStyle(color: kMuted, fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete Deal?"),
                      content: Text("Delete \"${d['title']}\"?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.white))),
                      ]));
                  if (confirm == true) {
                    await Api.deleteDeal(widget.token, d["_id"]);
                    _load();
                  }
                }),
            ));
        },
      )),
  );
}

// ─────────────────────── ADD DEAL PAGE ───────────────────────
class AddDealPage extends StatefulWidget {
  final String token; final String storeId; final String storeName;
  final List<Map<String,dynamic>> stores;
  const AddDealPage({super.key, required this.token, required this.storeId,
    required this.storeName, this.stores = const <Map<String,dynamic>>[]});
  @override State<AddDealPage> createState() => _AddDealState();
}
class _AddDealState extends State<AddDealPage> {
  final _title = TextEditingController();
  final _desc  = TextEditingController();
  final _disc  = TextEditingController();
  String _category = ""; bool _loading = false; String _msg = "";
  List<dynamic> _categories = [];
  late String _selectedStoreId;
  late String _selectedStoreName;

  @override void initState() {
    super.initState();
    _selectedStoreId = widget.storeId;
    _selectedStoreName = widget.storeName;
    Api.fetchCategories(token: widget.token).then((v) { if (mounted) setState(() => _categories = v as List); });
  }
  @override void dispose() { _title.dispose(); _desc.dispose(); _disc.dispose(); super.dispose(); }

  Future<void> _save() async {
    final discVal = int.tryParse(_disc.text.trim()) ?? 0;
    if (_title.text.trim().isEmpty) { setState(() => _msg = "Deal title is required"); return; }
    if (_disc.text.trim().isEmpty)  { setState(() => _msg = "Discount % is required"); return; }
    if (discVal <= 0)               { setState(() => _msg = "Discount must be greater than 0%"); return; }
    if (discVal > 100)              { setState(() => _msg = "Discount cannot exceed 100%"); return; }
    setState(() => _loading = true); _msg = "";
    try {
      await Api.addDeal(widget.token, {
        "store_id":    _selectedStoreId,
        "title":       _title.text.trim(),
        "description": _desc.text.trim(),
        "discount":    discVal,
        "category":    _category,
        "start_date":  DateTime.now().toIso8601String().substring(0, 10),
        "end_date":    DateTime.now().add(const Duration(days: 30)).toIso8601String().substring(0, 10),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("✅ Deal added successfully!"), backgroundColor: Color(0xFF1a6640)));
      Navigator.pop(context);
    } catch (e) { setState(() => _msg = e.toString().replaceAll("Exception: ", "")); }
    if (mounted) setState(() => _loading = false);
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(title: const Text("Add Deal"), backgroundColor: Colors.white, foregroundColor: kText),
    body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.stores.length > 1) ...[
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: _selectedStoreId,
          items: widget.stores.map<DropdownMenuItem<String>>((s) =>
            DropdownMenuItem<String>(value: s["_id"]?.toString() ?? "",
              child: Text(s["store_name"]?.toString() ?? "", overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) { final s = widget.stores.firstWhere((s) => s["_id"] == v, orElse: () => <String,dynamic>{}); setState(() { _selectedStoreId = v; _selectedStoreName = s["store_name"] ?? ""; }); }},
          decoration: InputDecoration(labelText: "Store", prefixIcon: const Icon(Icons.store, color: kMuted, size: 20),
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
        const SizedBox(height: 14),
      ] else
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: kLight.withValues(alpha: .4), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [const Icon(Icons.store, color: kPrimary, size: 18), const SizedBox(width: 8),
            Text(_selectedStoreName, style: const TextStyle(color: kPrimary, fontWeight: FontWeight.w600))]),
        ),
      TextField(controller: _title,
        decoration: InputDecoration(hintText: "Deal Title (e.g. 20% off on all items)", prefixIcon: const Icon(Icons.title, color: kMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
      const SizedBox(height: 12),
      TextField(controller: _disc, keyboardType: TextInputType.number,
        decoration: InputDecoration(hintText: "Discount %", prefixIcon: const Icon(Icons.percent, color: kMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        isExpanded: true,
        value: _category.isEmpty ? null : _category,
        items: _categories.map((e) { final c=(e is Map?e['name']:e).toString(); return DropdownMenuItem<String>(value:c,child:Text(c)); }).toList(),
        onChanged: (v) => setState(() => _category = v ?? ""),
        decoration: InputDecoration(hintText: "Category", prefixIcon: const Icon(Icons.category, color: kMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
      const SizedBox(height: 12),
      TextField(controller: _desc, maxLines: 3,
        decoration: InputDecoration(hintText: "Description (optional)", prefixIcon: const Icon(Icons.description_outlined, color: kMuted, size: 20),
          filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBorder)))),
      const SizedBox(height: 20),
      SizedBox(height: 50, child: ElevatedButton(
        onPressed: _loading ? null : _save,
        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text("Add Deal", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)))),
      if (_msg.isNotEmpty) ...[const SizedBox(height: 10),
        Text(_msg, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontSize: 13))],
      const SizedBox(height: 24),
    ])),
  );
}