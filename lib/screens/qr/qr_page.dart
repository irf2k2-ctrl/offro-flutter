// lib/screens/qr/qr_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/prefs_service.dart';
import '../../core/widgets/brand_logo.dart';

class QRPage extends StatefulWidget {
  final String token; final VoidCallback? onDone;
  const QRPage({super.key,required this.token,this.onDone});
  @override State<QRPage> createState()=>_QRState();
}
class _QRState extends State<QRPage>{
  bool _scanned=false;
  @override Widget build(BuildContext ctx)=>Scaffold(
    appBar:AppBar(title:const Text("Scan Store QR"),backgroundColor:kPrimary,foregroundColor:Colors.white),
    body:Stack(children:[
      MobileScanner(onDetect:(cap) async {
        if(_scanned)return; final raw = cap.barcodes.isNotEmpty ? cap.barcodes.first.rawValue ?? "" : ""; if(raw.isEmpty)return;
        setState(()=>_scanned=true);
        String? sid=raw.contains("store_id=")?raw.split("store_id=").last.split("&").first.trim():null;
        if(sid==null||sid.isEmpty){if(!mounted)return;Navigator.pop(ctx);ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text("❌ Invalid QR")));return;}
        try{
          final res=await Api.redeemQR(sid,widget.token); widget.onDone?.call();
          if(!mounted)return; Navigator.pop(ctx);
          showDialog(context:ctx,builder:(_)=>AlertDialog(shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
            title:Row(children:[const Icon(Icons.check_circle,color:kPrimary),const SizedBox(width:8),const Text("Points Added!")]),
            content:Text("${res["message"]??"Done!"}\n\n🔐 Store QR has been refreshed for security."),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text("Great!",style:TextStyle(color:kPrimary)))]));
        }catch(e){if(!mounted)return;Navigator.pop(ctx);ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(e.toString().replaceAll("Exception: ",""))));}
      }),
      Center(child:Container(width:220,height:220,decoration:BoxDecoration(border:Border.all(color:kPrimary,width:3),borderRadius:BorderRadius.circular(16)))),
      const Positioned(bottom:60,left:0,right:0,child:Text("Point at store QR code",textAlign:TextAlign.center,style:TextStyle(color:Colors.white,fontSize:14))),
    ]),
  );
}

// ─────────────────────── WALLET PAGE ───────────────────────
