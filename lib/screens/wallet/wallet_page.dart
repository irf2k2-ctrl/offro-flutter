// lib/screens/wallet/wallet_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';

class WalletPage extends StatefulWidget {
  final String token; const WalletPage({super.key,required this.token});
  @override State<WalletPage> createState()=>_WalletState();
}
class _WalletState extends State<WalletPage>{
  int vp=0,pp=0; bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { try{final d=await Api.getWallet(widget.token);if(mounted)setState((){vp=d["visit_points"]??0;pp=d["pool_points"]??0;loading=false;});}catch(_){if(mounted)setState(()=>loading=false);} }
  Future<void> _withdraw() async {
    // NOTE: function kept named _withdraw() internally and still calls Api.withdraw()
    // (same backend endpoint) — this is purely a UI/wording change for Google Play
    // policy compliance. No business logic, API, or DB fields were changed.
    try{final r=await Api.withdraw(widget.token,200);if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(r["message"]??"Done")));_load();}
    catch(e){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceAll("Exception: ",""))));}
  }
  @override Widget build(BuildContext ctx){
    int total=vp;
    return Scaffold(appBar:AppBar(title:const Text("My Rewards"),backgroundColor:kPrimary,foregroundColor:Colors.white),backgroundColor:kBg,
      body:loading?const Center(child:CircularProgressIndicator(color:kPrimary)):SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(children:[
        const SizedBox(height:10),
        Container(width:double.infinity,padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:kPrimary,borderRadius:BorderRadius.circular(18)),
          child:Column(children:[
            const Text("Available Reward Points",style:TextStyle(color:kLight,fontSize:14)),
            const SizedBox(height:8),
            Text("$total",style:const TextStyle(color:Colors.white,fontSize:46,fontWeight:FontWeight.bold)),
            const Text("points",style:TextStyle(color:kAccent)),
          ])),
        const SizedBox(height:20),
        Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),border:Border.all(color:kBorder)),
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text("💡 Reward Information",style:TextStyle(fontWeight:FontWeight.bold,color:kPrimary,fontSize:14)),const SizedBox(height:8),
            _info("🎁","Redeem 200 Reward Points for a ₹20 Promotional Gift Voucher."),
            _info("✅ Redeem after","200 Reward Points"),
            _info("🎁 Promotional Gift Voucher","Amazon or Flipkart"),
            _info("⏱️","Reward Points Never Expire"),
            _info("📋","Gift Voucher Delivery: 3-5 Business Days"),
          ])),
        const SizedBox(height:20),
        SizedBox(width:double.infinity,child:ElevatedButton(
          onPressed:total>=200?_withdraw:null,
          style:ElevatedButton.styleFrom(backgroundColor:kPrimary,padding:const EdgeInsets.symmetric(vertical:14),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),disabledBackgroundColor:kAccent),
          child:Text(total>=200?"Redeem Rewards (200 Reward Points = ₹20 Gift Voucher)":"Earn ${200-total} more reward points to redeem a Gift Voucher",style:const TextStyle(color:Colors.white,fontSize:14)))),
        const SizedBox(height:8),
        const Text("Redeem after 200 Reward Points  •  Gift Voucher delivered within 3-5 business days",textAlign:TextAlign.center,style:TextStyle(color:kMuted,fontSize:11)),
        const SizedBox(height:14),
        const Text("Reward points are promotional loyalty points. They cannot be purchased, transferred, or exchanged for cash.",
          textAlign:TextAlign.center,style:TextStyle(color:kMuted,fontSize:10,fontStyle:FontStyle.italic)),
      ])));
  }
  Widget _box(String t,int v,Color bg,IconData ico)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(14)),
    child:Column(children:[Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(ico,color:kPrimary,size:14),const SizedBox(width:4),Text(t,style:const TextStyle(color:kPrimary,fontSize:12,fontWeight:FontWeight.w600))]),const SizedBox(height:8),Text("$v",style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:kText))]));
  Widget _info(String k,String v)=>Padding(
    padding:const EdgeInsets.only(bottom:5),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text("$k: ",style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12,color:kPrimary)),
      Expanded(child:Text(v,style:const TextStyle(fontSize:12,color:kText))),
    ]));
}

// ─────────────────────── HISTORY PAGE ───────────────────────
class HistoryPage extends StatefulWidget {
  final String token; const HistoryPage({super.key,required this.token});
  @override State<HistoryPage> createState()=>_HistoryState();
}
class _HistoryState extends State<HistoryPage>{
  List _h=[]; bool _l=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { _h=await Api.getRedemptions(widget.token); if(mounted)setState(()=>_l=false); }
  @override Widget build(BuildContext ctx)=>Scaffold(
    appBar:AppBar(title:const Text("Scan History"),backgroundColor:kPrimary,foregroundColor:Colors.white),backgroundColor:kBg,
    body:_l?const Center(child:CircularProgressIndicator(color:kPrimary)):
    _h.isEmpty?Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[buildLogo(44,kAccent),const SizedBox(height:12),const Text("No scans yet",style:TextStyle(color:kMuted,fontSize:16))])):
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
        return Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:kBorder)),
          child:Row(children:[
            // store image or fallback icon
            ClipRRect(borderRadius:BorderRadius.circular(10),
              child: SizedBox(width:48,height:48,
                child: storeImg!=null && storeImg.startsWith("data:image")
                  ? (() { try { return Image.memory(base64Decode(storeImg.split(",").last),fit:BoxFit.cover,gaplessPlayback:true); } catch(_) { return const SizedBox(); } })()
                  : Container(color:kLight,child:const Icon(Icons.store_rounded,color:kPrimary,size:22)))),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(h["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:13)),
              const SizedBox(height:3),
              Row(children:[
                const Icon(Icons.calendar_today_rounded,color:kMuted,size:11),const SizedBox(width:4),
                Text(dateLabel,style:const TextStyle(color:kMuted,fontSize:11)),
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
