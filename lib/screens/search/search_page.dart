import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

// ─── Local imports ───
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';
import '../../core/services/fav_state.dart';
import '../../core/widgets/store_cards.dart';
import '../store/store_detail_page.dart';
import '../detail/detail_page.dart';
import '../voucher/voucher_view_all_page.dart';

const kBaseUrl     = "https://offro-backend-production.up.railway.app";
const kRazorpayKey = "rzp_live_SdiI6kcuZzZjsl";
const kPrimary  = Color(0xFF3E5F55);
const kLight    = Color(0xFFCDEBD6);
const kAccent   = Color(0xFFA9CDBA);
const kBeige    = Color(0xFFE7D7C8);
const kBg       = Color(0xFFFDFBF6);
const kText     = Color(0xFF2c3e35);
const kMuted    = Color(0xFF6b8c7e);
const kBorder   = Color(0xFFd4e8de);

PageRoute _route(Widget w) => MaterialPageRoute(builder: (_) => w);

class MasonrySearchGrid extends StatelessWidget {
  final List<Map<String,dynamic>> stores; final String token;
  const MasonrySearchGrid({required this.stores,required this.token});

  Widget _imgWidget(Map s) {
    String img = s["image_url"]?.toString() ?? "";
    if (img.isEmpty) img = s["image_thumb"]?.toString() ?? "";
    if (img.isEmpty) img = s["image"]?.toString() ?? "";
    if (img.isEmpty) img = s["image2"]?.toString() ?? "";
    if (img.startsWith("data:image")) {
      try { return Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover,width:double.infinity,height:double.infinity,gaplessPlayback:true); }
      catch(_) { if (kDebugMode) debugPrint('[Offro] suppressed error'); }
    }
    final imgUrl = img.startsWith("/") ? "$kBaseUrl$img" : img;
    if (imgUrl.startsWith("http")) {
      return CachedNetworkImage(imageUrl:imgUrl,fit:BoxFit.cover,width:double.infinity,height:double.infinity,
        placeholder:(_,__)=>Container(color:kAccent,child:const Center(child:Icon(Icons.store,color:kPrimary,size:32))),
        errorWidget:(_,__,___)=>Container(color:kAccent,child:const Center(child:Icon(Icons.store,color:kPrimary,size:32))));
    }
    return Container(color:kAccent, child:Center(child:Icon(Icons.store,color:kPrimary,size:32)));
  }

  @override Widget build(BuildContext context) {
    // Generate random heights: alternate between tall/medium/short
    final heights = List.generate(stores.length, (i) => [140.0,180.0,120.0,160.0,200.0,130.0][i%6]);
    // Build 2-column masonry
    final col1 = <int>[]; final col2 = <int>[];
    double h1=0, h2=0;
    for(int i=0;i<stores.length;i++){
      if(h1<=h2){col1.add(i);h1+=heights[i]+10;}
      else{col2.add(i);h2+=heights[i]+10;}
    }
    Widget _card(int idx) {
      final s=Map<String,dynamic>.from(stores[idx] as Map);
      final dist = s["distance_km"] != null ? (s["distance_km"] as num).toDouble() : null;
      final rating=(s["rating"] as num?)?.toDouble()??0;
      return GestureDetector(
        onTap:()=>Navigator.push(context,_route(StoreDetailPage(store:Map<String,dynamic>.from(s), token:token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
        child:Container(
          height:heights[idx],
          margin:const EdgeInsets.only(bottom:10),
          decoration:BoxDecoration(
            borderRadius:BorderRadius.circular(16),
            boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .1),blurRadius:8,offset:const Offset(0,3))],
          ),
          child:ClipRRect(
            borderRadius:BorderRadius.circular(16),
            child:Stack(fit:StackFit.expand,children:[
              _imgWidget(s),
              Positioned.fill(child:DecoratedBox(decoration:BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,
                  colors:[Colors.transparent,Colors.transparent,Colors.black.withValues(alpha: .7)],stops:const[0,.5,1]),
              ))),
              if(dist!=null) Positioned(top:7,right:7,child:Container(
                padding:const EdgeInsets.symmetric(horizontal:6,vertical:3),
                decoration:BoxDecoration(color:Colors.black54,borderRadius:BorderRadius.circular(8)),
                child:Text(dist<1?"${(dist*1000).round()}m":"${dist.toStringAsFixed(1)}km",
                  style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)),
              )),
              Positioned(bottom:0,left:0,right:0,child:Padding(
                padding:const EdgeInsets.fromLTRB(8,0,8,8),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
                  Text(s["store_name"]?.toString()??"",style:const TextStyle(color:Colors.white,fontSize:12,fontWeight:FontWeight.w800),maxLines:1,overflow:TextOverflow.ellipsis),
                  if(rating>0) Row(children:[
                    const Icon(Icons.star_rounded,color:Color(0xFFFFD700),size:10),const SizedBox(width:2),
                    Text(rating.toStringAsFixed(1),style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)),
                  ]),
                ]),
              )),
            ]),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding:const EdgeInsets.fromLTRB(12,12,12,24),
      child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(children:col1.map(_card).toList())),
        const SizedBox(width:10),
        Expanded(child:Column(children:col2.map(_card).toList())),
      ]),
    );
  }
}

// ─────────────────────── GIFT VOUCHER CARD WIDGET ───────────────────────



// ─────────────────────── VIEW ALL PAGE ───────────────────────

// ─────────────────────── SEARCH PAGE ───────────────────────
class SearchPage extends StatefulWidget {
  final String token; final String city;
  final List<Map<String,dynamic>> products;
  const SearchPage({required this.token, required this.city, this.products = const []});
  @override State<SearchPage> createState()=>_SearchPageState();
}
class _SearchPageState extends State<SearchPage> {
  final _sc = TextEditingController();
  String _q = ""; bool _busy = false;
  List<Map<String,dynamic>> _results = [];

  @override void dispose(){ _sc.dispose(); super.dispose(); }

  Future<void> _doSearch(String q) async {
    final qt = q.trim();
    if (qt.isEmpty) { setState(()=>_results=[]); return; }
    setState(()=>_busy=true);
    try {
      final allStores = await Api.fetchStores(city:widget.city);
      final ql = qt.toLowerCase();
      final storeResults = List<Map<String,dynamic>>.from(allStores.where((s)=>
        (s["store_name"]??'').toLowerCase().contains(ql)||
        (s["category"]??'').toLowerCase().contains(ql)||
        (s["area"]??'').toLowerCase().contains(ql)||
        (s["offer"]??'').toLowerCase().contains(ql)
      ).toList());
      final productResults = widget.products.where((v) =>
        (v["title"]??'').toLowerCase().contains(ql) ||
        (v["text"]??'').toLowerCase().contains(ql) ||
        (v["store_name"]??'').toLowerCase().contains(ql) ||
        ((v["store"] is Map ? v["store"]["store_name"] : null)?.toString() ?? '').toLowerCase().contains(ql)
      ).map((v) => Map<String,dynamic>.from(v)..['_isProduct'] = true).toList();
      _results = [...productResults, ...storeResults];
    } catch(_) { _results = []; }
    if (mounted) setState(()=>_busy=false);
  }

  @override Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: TextField(
          controller: _sc,
          autofocus: true,
          style: const TextStyle(color:Colors.white, fontSize:15),
          cursorColor: Colors.white,
          decoration: InputDecoration(
            hintText: "Search stores in ${widget.city}...",
            hintStyle: const TextStyle(color:Colors.white60, fontSize:14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical:14),
          ),
          onChanged:(v){ setState(()=>_q=v); if(v.trim().isNotEmpty) _doSearch(v); else setState(()=>_results=[]); },
          onSubmitted:_doSearch,
        ),
        actions:[
          if (_q.isNotEmpty) IconButton(icon:const Icon(Icons.clear,color:Colors.white),onPressed:(){ _sc.clear(); setState((){ _q=''; _results=[]; }); }),
        ],
      ),
      body: _busy
        ? const Center(child:CircularProgressIndicator(color:kPrimary))
        : _q.isEmpty
          ? SearchLandingGrid(token:widget.token, city:widget.city)
          : _results.isEmpty
            ? Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
                const Icon(Icons.search_off,color:kAccent,size:56),
                const SizedBox(height:12),
                Text("No results for '$_q'",style:const TextStyle(color:kMuted,fontSize:15)),
              ]))
            : ListView.separated(
                padding:const EdgeInsets.all(14),
                separatorBuilder:(_,__)=>const SizedBox(height:8),
                itemCount:_results.length,
                itemBuilder:(_,i){
                  final s=_results[i];
                  final isProduct = s['_isProduct'] == true;
                  if (isProduct) {
                    String img = ''; for (final k in ["logo_url","image_url","image_thumb","image"]) { img = s[k]?.toString()??''; if(img.isNotEmpty) break; }
                    final storeN = (s["store"] is Map ? s["store"]["store_name"] : null)?.toString() ?? s["store_name"]?.toString() ?? "";
                    final price  = s["offer_price"]?.toString() ?? s["sale_price"]?.toString() ?? s["price"]?.toString() ?? "";
                    return GestureDetector(
                      onTap:()=>Navigator.push(context,_route(ProductDetailsPage(product:Map<String,dynamic>.from(s),token:widget.token))),
                      child:Container(padding:const EdgeInsets.all(12),
                        decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                          boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .05),blurRadius:8,offset:const Offset(0,2))]),
                        child:Row(children:[
                          ClipRRect(borderRadius:BorderRadius.circular(10),child:SizedBox(width:62,height:62,
                            child:img.isNotEmpty&&img.startsWith("data:image")
                              ? Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover)
                              : Container(color:const Color(0xFFe8f5f0),child:const Icon(Icons.storefront_outlined,color:kPrimary,size:28)))),
                          const SizedBox(width:12),
                          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                            Text(s["title"]??s["text"]??"Product",style:const TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:14)),
                            if(storeN.isNotEmpty) Text(storeN,style:const TextStyle(color:kMuted,fontSize:12)),
                            if(price.isNotEmpty) Padding(padding:const EdgeInsets.only(top:3),
                              child:Text("₹$price",style:const TextStyle(color:kPrimary,fontSize:12,fontWeight:FontWeight.w700))),
                          ])),
                          const Icon(Icons.arrow_forward_ios_rounded,color:kBorder,size:14),
                        ])));
                  }
                  String img=s["image_url"]?.toString()??''; if(img.isEmpty)img=s["image_thumb"]?.toString()??''; if(img.isEmpty)img=s["image"]?.toString()??''; if(img.isEmpty)img=s["image2"]?.toString()??'';
                  return GestureDetector(
                    onTap:()=>Navigator.push(context,_route(StoreDetailPage(store:Map<String,dynamic>.from(s), token:widget.token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
                    child:Container(padding:const EdgeInsets.all(12),
                      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),
                        boxShadow:[BoxShadow(color:Colors.black.withValues(alpha: .05),blurRadius:8,offset:const Offset(0,2))]),
                      child:Row(children:[
                        ClipRRect(borderRadius:BorderRadius.circular(10),child:SizedBox(width:62,height:62,
                          child:img.isNotEmpty&&img.startsWith("data:image")
                            ? Image.memory(base64Decode(img.split(",").last),fit:BoxFit.cover)
                            : Container(color:kAccent,child:const Icon(Icons.store,color:kPrimary,size:28)))),
                        const SizedBox(width:12),
                        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                          Text(s["store_name"]??"",style:const TextStyle(fontWeight:FontWeight.bold,color:kText,fontSize:14)),
                          Text("${s['category']??''} · ${s['area']??''}",style:const TextStyle(color:kMuted,fontSize:12)),
                          if ((s['visit_points']??0)>0) Padding(padding:const EdgeInsets.only(top:3),
                            child:Text("${s['visit_points']} pts on visit",style:const TextStyle(color:kPrimary,fontSize:11,fontWeight:FontWeight.w600))),
                        ])),
                        const Icon(Icons.arrow_forward_ios_rounded,color:kBorder,size:14),
                      ])));
                }),
    );
  }
}

// ─────────────────────── SEARCH LANDING GRID ───────────────────────
class SearchLandingGrid extends StatefulWidget {
  final String token; final String city;
  const SearchLandingGrid({required this.token,required this.city});
  @override State<SearchLandingGrid> createState()=>_SearchLandingGridState();
}
class _SearchLandingGridState extends State<SearchLandingGrid> {
  List<Map<String,dynamic>> _stores=[];bool _loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{final d=await Api.fetchStores(city:widget.city);if(mounted)setState((){_stores=List<Map<String,dynamic>>.from(d);_loading=false;});}
    catch(_){if(mounted)setState(()=>_loading=false);}
  }
  @override Widget build(BuildContext context){
    if(_loading) return const Center(child:CircularProgressIndicator(color:kPrimary));
    if(_stores.isEmpty) return const Center(child:Text("No stores yet",style:TextStyle(color:kMuted)));
    return MasonrySearchGrid(stores:_stores, token:widget.token);
  }
}

class ViewAllPage extends StatefulWidget {
  final String title;
  final List<Map<String,dynamic>> stores;
  final String token;
  final bool bigCards; // true = Explore Stores style, false = grid
  const ViewAllPage({required this.title, required this.stores, required this.token, this.bigCards=false});
  @override State<ViewAllPage> createState()=>_ViewAllPageState();
}
class _ViewAllPageState extends State<ViewAllPage>{
  final _searchCtrl = TextEditingController();
  String _q = "";
  @override void dispose(){ _searchCtrl.dispose(); super.dispose(); }

  List<Map<String,dynamic>> get _filtered {
    if (_q.trim().isEmpty) return widget.stores;
    final q = _q.toLowerCase();
    return widget.stores.where((s){
      return (s["store_name"]??"").toString().toLowerCase().contains(q)
          || (s["area"]??"").toString().toLowerCase().contains(q)
          || (s["city"]??"").toString().toLowerCase().contains(q)
          || (s["category"]??"").toString().toLowerCase().contains(q)
          || (s["offer"]??"").toString().toLowerCase().contains(q)
          || (s["about"]??"").toString().toLowerCase().contains(q);
    }).toList();
  }

  @override Widget build(BuildContext context){
    final filtered = _filtered;
    final scrH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: kText,
        title: Text(widget.title, style:const TextStyle(fontWeight:FontWeight.w800)),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14,0,14,10),
            child: Container(
              decoration: BoxDecoration(color:Colors.white, borderRadius:BorderRadius.circular(12)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v)=>setState(()=>_q=v),
                style: const TextStyle(color:kText, fontSize:14),
                decoration: InputDecoration(
                  hintText: "Search store, area, offer...",
                  hintStyle: const TextStyle(color:kMuted, fontSize:13),
                  prefixIcon: const Icon(Icons.search, color:kMuted, size:20),
                  suffixIcon: _q.isNotEmpty ? IconButton(icon:const Icon(Icons.clear,size:18,color:kMuted), onPressed:(){_searchCtrl.clear();setState(()=>_q="");}) : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical:12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: filtered.isEmpty
        ? Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            const Icon(Icons.search_off,color:kAccent,size:56),const SizedBox(height:12),
            Text(_q.isEmpty?"No stores yet":"No results for '$_q'",style:const TextStyle(color:kMuted,fontSize:15))]))
        : ListView.builder(
            padding:const EdgeInsets.fromLTRB(14,8,14,24),
            itemCount:filtered.length,
            itemBuilder:(_,i)=>Padding(
              padding:const EdgeInsets.only(bottom:10),
              child:GestureDetector(
                onTap:()=>Navigator.push(context,_route(StoreDetailPage(store:Map<String,dynamic>.from(filtered[i]), token:widget.token, userName:"", onProductTap:(p,tk)=>Navigator.push(context,_route(ProductDetailsPage(product:p,token:tk)))))),
                child:TopStoreCard(store:filtered[i]),
              ),
            )),
    );
  }
}

