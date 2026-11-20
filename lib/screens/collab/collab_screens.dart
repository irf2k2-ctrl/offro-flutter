// ══════════════════════════════════════════════════════════
// Creator Collaborations
//
// Merchant side : CollabWorkspacePage -> CampaignBriefPage, CampaignProposalsPage
// Influencer side: InfluencerOpportunitiesView -> OpportunityDetailPage
//
// All data comes from the backend (routers/collaborations.py). Nothing is
// faked. No chat: after the creator accepts, the MERCHANT's phone is shown to
// the creator. The creator's phone is never sent to the merchant.
// ══════════════════════════════════════════════════════════
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/design/design.dart'
    show OffroColors, OffroText, OffroRadii, OffroSpacing, OffroButton, OffroCard,
         OffroIcons, OffroIcon, OffroIconData, OffroTones, OffroScreenHeader, OffroNetworkImage;
import '../../core/services/api_service.dart';
import '../../core/services/error_mapper.dart';
import '../../core/utils/navigation.dart';
import '../merchant/merchant_screens.dart' show merchantHeaderBar;
import '../../core/l10n/l10n.dart';

// month names come from monthsShortOf (l10n)

/// "2026-10-25" -> "25 Oct 2026". Empty / unparseable -> "".
String _pretty(dynamic ymd) {
  final s = (ymd ?? "").toString();
  final p = s.split("-");
  if (p.length < 3) return "";
  final m = int.tryParse(p[1]) ?? 0;
  if (m < 1 || m > 12) return "";
  return "${int.tryParse(p[2]) ?? p[2]} ${monthsShortOf(offroNoContext)[m - 1]} ${p[0]}";
}

String _ymd(DateTime d) =>
    "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

List<Map<String, dynamic>> _maps(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

void _snack(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Widget _eyebrow(String t) => Text(t.toUpperCase(), style: OffroText.eyebrow);

Widget _loadError(String msg, VoidCallback retry) => Padding(
      padding: const EdgeInsets.all(OffroSpacing.gutter),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(msg, textAlign: TextAlign.center, style: OffroText.body),
        const SizedBox(height: 12),
        OffroButton.secondary(label: offroNoContext.locTryAgain, onPressed: retry),
      ]),
    );

// ═════════════════════════════════════════════════════════
// 1. MERCHANT — workspace
// ═════════════════════════════════════════════════════════
class CollabWorkspacePage extends StatefulWidget {
  final String token;
  const CollabWorkspacePage({super.key, required this.token});
  @override
  State<CollabWorkspacePage> createState() => _CollabWorkspacePageState();
}

class _CollabWorkspacePageState extends State<CollabWorkspacePage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _campaigns = [];
  int _active = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.collabCampaigns(widget.token);
      if (!mounted) return;
      setState(() {
        _campaigns = _maps(d["campaigns"]);
        _active = (d["active_count"] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e, l10n: mounted ? context.l10n : null); _loading = false; });
    }
  }

  Future<void> _create() async {
    // Typed route: appRoute() returns PageRoute<dynamic>, which can't be passed
    // where Navigator.push<bool> expects Route<bool>.
    final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => CampaignBriefPage(token: widget.token)));
    if (ok == true) _load();
  }

  Future<void> _review(Map<String, dynamic> c) async {
    await Navigator.push(context,
        appRoute(CampaignProposalsPage(token: widget.token, campaign: c)));
    _load(); // the campaign may have been closed there
  }

  List<List<String>> get _steps => [
    ["1", context.l10n.bizCreateBrief, context.l10n.bizShareWhatYouNeedAnd],
    ["2", context.l10n.bizInviteCreators, context.l10n.bizLocalCreatorsInYourCity],
    ["3", context.l10n.bizConfirmMatch, context.l10n.bizReviewWhoAcceptedAndConnect],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: merchantHeaderBar(eyebrow: context.l10n.bizCreator, title: context.l10n.bizCollaborations),
      body: RefreshIndicator(
        color: kMerchantPrimary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 8, OffroSpacing.gutter, 32),
          children: [
            Text(context.l10n.bizWorkWithTrustedLocalCreators, style: OffroText.title),
            const SizedBox(height: 8),
            Text(
              context.l10n.bizCreateOneClearCampaignBrief,
              style: OffroText.body),
            const SizedBox(height: 24),
            _eyebrow(context.l10n.bizHowItWorks),
            const SizedBox(height: 10),
            OffroCard(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                          color: OffroTones.fashion.background, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(_steps[i][0],
                          style: OffroText.cardTitle.copyWith(
                              color: OffroTones.fashion.foreground, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_steps[i][1], style: OffroText.cardTitle),
                      const SizedBox(height: 2),
                      Text(_steps[i][2], style: OffroText.body.copyWith(fontSize: 12.5)),
                    ])),
                  ]),
                ],
              ]),
            ),
            const SizedBox(height: 20),
            OffroButton(label: context.l10n.bizCreateCampaignBrief, onPressed: _create),
            const SizedBox(height: 28),
            _eyebrow(context.l10n.bizYourCampaigns),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text(context.l10n.bizCollaborationWorkspace, style: OffroText.title.copyWith(fontSize: 18))),
              Text(context.l10n.bizNActive('$_active'), style: OffroText.body.copyWith(fontSize: 12.5)),
            ]),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: kMerchantPrimary)))
            else if (_error != null)
              _loadError(_error!, _load)
            else if (_campaigns.isEmpty)
              OffroCard(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text(context.l10n.bizNoCampaignsYet, style: OffroText.cardTitle),
                  const SizedBox(height: 6),
                  Text(context.l10n.bizCreateYourFirstCampaignBrief,
                      textAlign: TextAlign.center, style: OffroText.body.copyWith(fontSize: 12.5)),
                ]))
            else
              for (final c in _campaigns) ...[
                _CampaignCard(c: c, onReview: () => _review(c)),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: kMerchantLight, borderRadius: BorderRadius.circular(OffroRadii.cardSm)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.l10n.bizWhenShouldYouUseThis, style: OffroText.cardTitle),
                const SizedBox(height: 6),
                Text(
                  context.l10n.bizUseCollaborationsForLaunchesVisits,
                  style: OffroText.body.copyWith(fontSize: 12.5)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final Map<String, dynamic> c;
  final VoidCallback onReview;
  const _CampaignCard({required this.c, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final status = (c["status"] ?? "active").toString();
    final proposals = (c["proposals"] as num?)?.toInt() ?? 0;
    final due = _pretty(c["publish_by"]);
    final visit = _pretty(c["visit_date"]);
    final open = status == "active";
    return OffroCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Store thumbnail (OffroNetworkImage shows the standard OffrO store placeholder when empty/failed).
          OffroNetworkImage(
            url: (c["store_image"] ?? "").toString(),
            width: 52, height: 52,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text((c["title"] ?? "").toString(), style: OffroText.cardTitle.copyWith(fontSize: 15))),
              if (!open)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: kMerchantBorder, borderRadius: BorderRadius.circular(99)),
                  child: Text(status == "expired" ? context.l10n.dealExpired : context.l10n.homeClosed,
                      style: OffroText.caption.copyWith(color: kMerchantMuted)),
                ),
            ]),
            const SizedBox(height: 4),
            Text((c["store_name"] ?? "").toString(), style: OffroText.body.copyWith(fontSize: 12.5)),
          ])),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _meta(OffroIcons.sparkles, (proposals == 1 ? context.l10n.bizProposalOne : context.l10n.bizProposalMany('$proposals'))),
          if (due.isNotEmpty) _meta(OffroIcons.clock, context.l10n.bizPublishByDate(due)),
          if (visit.isNotEmpty) _meta(OffroIcons.store, context.l10n.bizVisitOn(visit)),
        ]),
        const SizedBox(height: 12),
        OffroButton.secondary(label: context.l10n.bizReviewProposals, onPressed: onReview),
      ]),
    );
  }

  Widget _meta(OffroIconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        OffroIcon(i, size: 13, color: kMerchantMuted),
        const SizedBox(width: 5),
        Text(t, style: OffroText.body.copyWith(fontSize: 12)),
      ]);
}

// ═════════════════════════════════════════════════════════
// 1b. MERCHANT — proposals (creators who accepted)
// ═════════════════════════════════════════════════════════
class CampaignProposalsPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> campaign;
  const CampaignProposalsPage({super.key, required this.token, required this.campaign});
  @override
  State<CampaignProposalsPage> createState() => _CampaignProposalsPageState();
}

class _CampaignProposalsPageState extends State<CampaignProposalsPage> {
  bool _loading = true, _closing = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];
  late String _status = (widget.campaign["status"] ?? "active").toString();

  String get _id => (widget.campaign["id"] ?? "").toString();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.collabProposals(widget.token, _id);
      if (!mounted) return;
      final camp = d["campaign"];
      setState(() {
        _rows = _maps(d["proposals"]);
        if (camp is Map && camp["status"] != null) _status = camp["status"].toString();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e, l10n: mounted ? context.l10n : null); _loading = false; });
    }
  }

  Future<void> _close() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(c.l10n.bizCloseCampaign),
        content: Text(c.l10n.bizCreatorsWillNoLongerBe),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(c.l10n.bizKeepOpen)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(c.l10n.commonClose)),
        ],
      ),
    );
    if (yes != true) return;
    setState(() => _closing = true);
    try {
      await Api.collabClose(widget.token, _id);
      if (mounted) setState(() { _status = "closed"; _closing = false; });
    } catch (e) {
      if (mounted) { setState(() => _closing = false); _snack(context, friendlyError(e, l10n: mounted ? context.l10n : null)); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.campaign;
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: merchantHeaderBar(eyebrow: context.l10n.bizCampaign, title: context.l10n.bizProposals),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 8, OffroSpacing.gutter, 32),
        children: [
          Text((c["title"] ?? "").toString(), style: OffroText.title.copyWith(fontSize: 19)),
          const SizedBox(height: 4),
          Text((c["store_name"] ?? "").toString(), style: OffroText.body),
          const SizedBox(height: 20),
          _eyebrow(context.l10n.bizCreatorsWhoAccepted),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: kMerchantPrimary)))
          else if (_error != null)
            _loadError(_error!, _load)
          else if (_rows.isEmpty)
            OffroCard(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(context.l10n.bizNoProposalsYet, style: OffroText.cardTitle),
                const SizedBox(height: 6),
                Text(context.l10n.bizCreatorsInYourCityWill,
                    textAlign: TextAlign.center, style: OffroText.body.copyWith(fontSize: 12.5)),
              ]))
          else
            for (final r in _rows) ...[
              _creatorCard(r),
              const SizedBox(height: 12),
            ],
          if (_status == "active") ...[
            const SizedBox(height: 12),
            OffroButton.secondary(
                label: _closing ? context.l10n.bizClosing : context.l10n.bizCloseCampaign2,
                onPressed: _closing ? null : _close),
          ],
        ],
      ),
    );
  }

  Widget _creatorCard(Map<String, dynamic> r) {
    final cats = (r["categories"] is List)
        ? (r["categories"] as List).map((e) => e.toString()).join(" · ")
        : "";
    final ig = (r["instagram"] ?? "").toString().trim();
    final phone = (r["phone"] ?? "").toString().trim();
    final waUri = phone.isEmpty ? null : _waUri(phone);
    return OffroCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: OffroTones.fashion.background,
          backgroundImage: (r["photo_url"] ?? "").toString().startsWith("http")
              ? NetworkImage(r["photo_url"].toString()) : null,
          child: (r["photo_url"] ?? "").toString().startsWith("http")
              ? null
              : OffroIcon(OffroIcons.user, size: 20, color: OffroTones.fashion.foreground),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((r["name"] ?? "").toString(), style: OffroText.cardTitle.copyWith(fontSize: 15)),
          if (cats.isNotEmpty || (r["city"] ?? "").toString().isNotEmpty)
            Text([cats, (r["city"] ?? "").toString()].where((e) => e.isNotEmpty).join(" · "),
                style: OffroText.body.copyWith(fontSize: 12)),
          if (ig.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ig.startsWith("@") ? ig : "@$ig",
                style: OffroText.body.copyWith(fontSize: 12.5, color: kMerchantPrimary)),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(phone, style: OffroText.body.copyWith(fontSize: 12.5, color: kMerchantText)),
          ],
        ])),
        if (waUri != null)
          IconButton(
            tooltip: context.l10n.bizChatOnWhatsApp,
            onPressed: () => _openWhatsApp(waUri),
            icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 26),
          ),
      ]),
    );
  }

  /// https://wa.me/<number> - the standard WhatsApp deep link. 10-digit Indian numbers get 91.
  Uri? _waUri(String raw) {
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
    if (d.length == 10) d = '91$d';
    if (d.length < 11) return null;
    return Uri.parse("https://wa.me/$d");
  }

  Future<void> _openWhatsApp(Uri u) async {
    try {
      final ok = await launchUrl(u, mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack(context, context.l10n.bizCouldnTOpenWhatsApp);
    } catch (_) {
      if (mounted) _snack(context, context.l10n.bizCouldnTOpenWhatsApp);
    }
  }
}

// ═════════════════════════════════════════════════════════
// 2. MERCHANT — campaign brief
// ═════════════════════════════════════════════════════════
class CampaignBriefPage extends StatefulWidget {
  final String token;
  const CampaignBriefPage({super.key, required this.token});
  @override
  State<CampaignBriefPage> createState() => _CampaignBriefPageState();
}

class _CampaignBriefPageState extends State<CampaignBriefPage> {
  bool _loading = true, _saving = false;
  String? _loadErr;
  List<Map<String, dynamic>> _stores = [];
  List<String> _objectives = [], _contentTypes = [], _specialities = [];
  String _any = "Any";

  String? _storeId, _objective;
  String _speciality = "Any";
  final _title = TextEditingController();
  final _message = TextEditingController();
  final Set<String> _content = {};
  DateTime? _visit, _publishBy;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loading = true; _loadErr = null; });
    try {
      final r = await Future.wait([
        Api.collabOptions(widget.token),
        Api.getMerchantStores(widget.token),
        Api.fetchCategories(token: widget.token).catchError((_) => <dynamic>[]),
      ]);
      final o = r[0] as Map<String, dynamic>;
      final stores = _maps(r[1]).where((s) => s["is_active"] != false).toList();
      final cats = (r[2] as List)
          .map((c) => c is Map ? (c["name"]?.toString() ?? "") : c.toString())
          .where((n) => n.isNotEmpty).toSet().toList();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _objectives = (o["objectives"] as List).map((e) => e.toString()).toList();
        _contentTypes = (o["content_types"] as List).map((e) => e.toString()).toList();
        _any = (o["any_speciality"] ?? "Any").toString();
        _specialities = [_any, ...cats];
        _speciality = _any;
        _objective = _objectives.isNotEmpty ? _objectives.first : null;
        if (_stores.length == 1) _storeId = (_stores.first["_id"] ?? "").toString();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loadErr = friendlyError(e, l10n: mounted ? context.l10n : null); _loading = false; });
    }
  }

  Future<void> _pick(bool visit) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cur = visit ? _visit : _publishBy;
    final d = await showDatePicker(
      context: context,
      initialDate: cur ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() => visit ? _visit = d : _publishBy = d);
  }

  String? _validate() {
    if (_storeId == null) return context.l10n.bizPleaseSelectAStore2;
    if (_title.text.trim().length < 3) return context.l10n.bizEnterACampaignTitleAt;
    if (_objective == null) return context.l10n.bizSelectACampaignObjective;
    if (_message.text.trim().length < 10) return context.l10n.bizDescribeWhatTheCreatorShould;
    if (_content.isEmpty) return context.l10n.bizSelectTheContentYouNeed;
    if (_publishBy == null) return context.l10n.bizChooseAPublishByDate;
    if (_content.contains("Store visit") && _visit == null) return context.l10n.bizChooseAVisitDateFor;
    if (_visit != null && _visit!.isAfter(_publishBy!)) return context.l10n.bizVisitDateCanTBe;
    return null;
  }

  Future<void> _publish() async {
    final err = _validate();
    if (err != null) { _snack(context, err); return; }
    setState(() => _saving = true);
    try {
      await Api.collabCreateCampaign(widget.token, {
        "store_id": _storeId,
        "title": _title.text.trim(),
        "objective": _objective,
        "message": _message.text.trim(),
        "content_types": _contentTypes.where(_content.contains).toList(),
        "visit_date": _visit == null ? "" : _ymd(_visit!),
        "publish_by": _ymd(_publishBy!),
        "speciality": _speciality,
      });
      if (!mounted) return;
      _snack(context, context.l10n.bizBriefPublishedMatchingCreatorsCan);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) { setState(() => _saving = false); _snack(context, friendlyError(e, l10n: mounted ? context.l10n : null)); }
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: OffroText.body.copyWith(color: kMerchantMuted),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kMerchantPrimary, width: 2)),
      );

  Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 18),
      child: Text(t, style: OffroText.cardTitle));

  Widget _dropdown(String? value, List<String> items, ValueChanged<String?> on, String hint,
          {Map<String, String>? labels}) =>
      DropdownButtonFormField<String>(
        value: items.contains(value) ? value : null,
        isExpanded: true,
        decoration: _dec(hint),
        items: [for (final i in items) DropdownMenuItem(value: i, child: Text(labels?[i] ?? i, overflow: TextOverflow.ellipsis))],
        onChanged: on,
      );

  Widget _dateTile(String hint, DateTime? v, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kMerchantBorder)),
          child: Row(children: [
            const Icon(Icons.event_rounded, size: 18, color: kMerchantMuted),
            const SizedBox(width: 10),
            Expanded(
                child: Text(v == null ? hint : _pretty(_ymd(v)),
                    style: OffroText.body.copyWith(
                        color: v == null ? kMerchantMuted : kMerchantText, fontSize: 14))),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kMerchantBg,
      appBar: merchantHeaderBar(eyebrow: context.l10n.bizCreator, title: context.l10n.bizCampaignBrief),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kMerchantPrimary))
          : _loadErr != null
              ? Center(child: _loadError(_loadErr!, _init))
              : _stores.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(OffroSpacing.gutter),
                      child: Text(context.l10n.bizAddAndActivateAStore,
                          textAlign: TextAlign.center, style: OffroText.body)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(OffroSpacing.gutter, 0, OffroSpacing.gutter, 32),
                      children: [
                        _label(context.l10n.homeStoreWord),
                        _dropdown(_storeId,
                            [for (final s in _stores) (s["_id"] ?? "").toString()],
                            (v) => setState(() => _storeId = v), context.l10n.bizSelectStore2,
                            labels: {for (final s in _stores) (s["_id"] ?? "").toString(): (s["store_name"] ?? context.l10n.homeStoreWord).toString()}),
                        _label(context.l10n.bizCampaignTitle),
                        TextField(
                          controller: _title,
                          maxLength: 100,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _dec(context.l10n.bizExampleSeasonalMenuLaunch).copyWith(counterText: ""),
                        ),
                        _label(context.l10n.bizCampaignObjective),
                        _dropdown(_objective, _objectives, (v) => setState(() => _objective = v), context.l10n.bizSelectObjective),
                        _label(context.l10n.bizWhatShouldTheCreatorCommunicate),
                        TextField(
                          controller: _message,
                          minLines: 4,
                          maxLines: 7,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _dec(context.l10n.bizKeyMessageExperienceAndDetails),
                        ),
                        _label(context.l10n.bizRequestedContent),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final t in _contentTypes)
                            FilterChip(
                              label: Text(t),
                              selected: _content.contains(t),
                              showCheckmark: false,
                              selectedColor: kMerchantPrimary,
                              backgroundColor: Colors.white,
                              side: BorderSide(color: _content.contains(t) ? kMerchantPrimary : kMerchantBorder),
                              labelStyle: OffroText.body.copyWith(
                                  fontSize: 13,
                                  color: _content.contains(t) ? Colors.white : kMerchantText),
                              onSelected: (on) => setState(() => on ? _content.add(t) : _content.remove(t)),
                            ),
                        ]),
                        _label(context.l10n.bizVisitDate),
                        _dateTile(context.l10n.bizSelectDate, _visit, () => _pick(true)),
                        _label(context.l10n.bizPublishBy),
                        _dateTile(context.l10n.bizSelectDate, _publishBy, () => _pick(false)),
                        _label(context.l10n.bizPreferredCreatorSpeciality),
                        _dropdown(_speciality, _specialities, (v) => setState(() => _speciality = v ?? _any), context.l10n.bizSelectSpeciality),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: kMerchantLight,
                              borderRadius: BorderRadius.circular(OffroRadii.cardSm)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.l10n.bizNoPaymentProcessing, style: OffroText.cardTitle),
                            const SizedBox(height: 6),
                            Text(
                              context.l10n.bizOffrOConnectsYouWithCreators,
                              style: OffroText.body.copyWith(fontSize: 12.5)),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        OffroButton(
                          label: _saving ? context.l10n.bizPublishing : context.l10n.bizPublishBrief,
                          onPressed: _saving ? null : _publish,
                        ),
                      ],
                    ),
    );
  }
}

// ═════════════════════════════════════════════════════════
// 3. INFLUENCER — Opportunities tab body
// ═════════════════════════════════════════════════════════
class InfluencerOpportunitiesView extends StatefulWidget {
  final String token;
  final Widget? headerTrailing;
  const InfluencerOpportunitiesView({super.key, required this.token, this.headerTrailing});
  @override
  State<InfluencerOpportunitiesView> createState() => _InfluencerOpportunitiesViewState();
}

class _InfluencerOpportunitiesViewState extends State<InfluencerOpportunitiesView> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.influencerOpportunities(widget.token);
      if (!mounted) return;
      setState(() { _rows = _maps(d["opportunities"]); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e, l10n: mounted ? context.l10n : null); _loading = false; });
    }
  }

  Future<void> _open(Map<String, dynamic> r) async {
    await Navigator.push(context,
        appRoute(OpportunityDetailPage(token: widget.token, id: (r["id"] ?? "").toString())));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: OffroColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            OffroScreenHeader(
              eyebrow: context.l10n.bizMatchedLocally,
              title: context.l10n.navOpportunities,
              description: context.l10n.bizReviewCollaborationRequestsFromReleva,
              trailing: widget.headerTrailing,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: OffroSpacing.gutterH,
              child: _loading
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator(color: OffroColors.primary)))
                  : _error != null
                      ? _loadError(_error!, _load)
                      : _rows.isEmpty
                          ? _empty()
                          : Column(children: [
                              for (final r in _rows) ...[
                                OpportunityCard(r: r, onTap: () => _open(r)),
                                const SizedBox(height: 12),
                              ],
                            ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: OffroTones.fashion.background,
            borderRadius: BorderRadius.circular(OffroRadii.card)),
        child: Column(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            alignment: Alignment.center,
            child: OffroIcon(OffroIcons.sparkles, size: 22, color: OffroTones.fashion.foreground),
          ),
          const SizedBox(height: 14),
          Text(context.l10n.bizNoCollaborationRequestsYet,
              textAlign: TextAlign.center, style: OffroText.title.copyWith(fontSize: 16)),
          const SizedBox(height: 6),
          Text(context.l10n.bizRequestsFromMerchantsInYour,
              textAlign: TextAlign.center, style: OffroText.body.copyWith(fontSize: 12.5)),
        ]),
      );
}

/// Opportunity card (white OffrO card). Reused by the Opportunities tab and the
/// Influencer Home "Campaign opportunities" block. The ACCEPTED look is driven by the
/// backend `my_status`, never by local state.
class OpportunityCard extends StatelessWidget {
  final Map<String, dynamic> r;
  final VoidCallback onTap;
  const OpportunityCard({super.key, required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final my = (r["my_status"] ?? "new").toString();
    final accepted = my == "accepted";
    final label = accepted
        ? context.l10n.bizAccepted
        : my == "declined"
            ? context.l10n.bizDeclined
            : (r["campaign_state"] ?? "active") == "active"
                ? context.l10n.bizNewCollaborationRequest
                : context.l10n.homeClosed;
    return OffroCard(
      onTap: onTap,
      shadow: true,
      color: OffroColors.surface, // Accepted card is white too (was mint)
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (accepted) ...[
              const OffroIcon(OffroIcons.check, size: 12, color: OffroColors.success),
              const SizedBox(width: 5),
            ],
            Text(label.toUpperCase(),
                // Accepted: the TEXT itself is OffrO green (no filled background); bold.
                style: OffroText.eyebrow.copyWith(color: accepted ? OffroColors.success : OffroColors.sageStrong, fontWeight: accepted ? FontWeight.w700 : null)),
          ]),
          const SizedBox(height: 8),
          Text((r["title"] ?? "").toString(), style: OffroText.cardTitle.copyWith(fontSize: 16)),
          const SizedBox(height: 3),
          Text((r["store_name"] ?? "").toString(), style: OffroText.body.copyWith(fontSize: 12.5)),
          if ((r["content_summary"] ?? "").toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text((r["content_summary"]).toString(), style: OffroText.body.copyWith(fontSize: 12.5)),
          ],
          const SizedBox(height: 12),
          OffroButton.small(label: context.l10n.bizViewBrief, onPressed: onTap, trailingIcon: OffroIcons.arrow),
        ])),
        const SizedBox(width: 12),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: OffroColors.mint.withValues(alpha: .35), borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: const OffroIcon(OffroIcons.sparkles, size: 20, color: OffroColors.primary),
        ),
      ]),
    );
  }
}

/// Influencer Home "Campaign opportunities": ONLY pending (my_status == new, still open)
/// requests from the backend. Once accepted/declined a campaign is no longer pending, so it
/// drops out of here and shows (as ACCEPTED) in the Opportunities tab instead.
class CampaignOpportunitiesSection extends StatefulWidget {
  final String token;
  final VoidCallback? onSeeAll;
  const CampaignOpportunitiesSection({super.key, required this.token, this.onSeeAll});
  @override
  State<CampaignOpportunitiesSection> createState() => _CampaignOpportunitiesSectionState();
}

class _CampaignOpportunitiesSectionState extends State<CampaignOpportunitiesSection> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pending = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.influencerOpportunities(widget.token);
      if (!mounted) return;
      setState(() {
        _pending = _maps(d["opportunities"])
            .where((r) => r["my_status"] == "new" && r["campaign_state"] == "active")
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e, l10n: mounted ? context.l10n : null); _loading = false; });
    }
  }

  Future<void> _open(Map<String, dynamic> r) async {
    await Navigator.push(context,
        appRoute(OpportunityDetailPage(token: widget.token, id: (r["id"] ?? "").toString())));
    _load(); // accepted/declined -> no longer pending
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(color: OffroColors.primary)));
    }
    if (_error != null) return _loadError(_error!, _load);
    if (_pending.isEmpty) {
      return OffroCard(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Text(context.l10n.bizNoCampaignRequestsYet, style: OffroText.cardTitle),
          const SizedBox(height: 6),
          Text(context.l10n.bizNewBriefsFromMerchantsIn,
              textAlign: TextAlign.center, style: OffroText.body.copyWith(fontSize: 12.5)),
        ]),
      );
    }
    final shown = _pending.take(3).toList();
    return Column(children: [
      for (final r in shown) ...[
        OpportunityCard(r: r, onTap: () => _open(r)),
        const SizedBox(height: 12),
      ],
      if (_pending.length > shown.length && widget.onSeeAll != null)
        OffroButton.secondary(label: context.l10n.bizSeeAllRequests('${_pending.length}'), onPressed: widget.onSeeAll),
    ]);
  }
}

// ═════════════════════════════════════════════════════════
// 4. INFLUENCER — brief detail (accept / decline)
// ═════════════════════════════════════════════════════════
class OpportunityDetailPage extends StatefulWidget {
  final String token;
  final String id;
  const OpportunityDetailPage({super.key, required this.token, required this.id});
  @override
  State<OpportunityDetailPage> createState() => _OpportunityDetailPageState();
}

class _OpportunityDetailPageState extends State<OpportunityDetailPage> {
  bool _loading = true, _busy = false;
  String? _error;
  Map<String, dynamic> _d = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await Api.influencerOpportunity(widget.token, widget.id);
      if (mounted) setState(() { _d = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e, l10n: mounted ? context.l10n : null); _loading = false; });
    }
  }

  Future<void> _respond(bool accept) async {
    setState(() => _busy = true);
    try {
      await Api.influencerRespond(widget.token, widget.id, accept);
      if (!mounted) return;
      _snack(context, accept ? context.l10n.bizCollaborationAccepted : context.l10n.bizRequestDeclined);
      await _load();
    } catch (e) {
      if (mounted) _snack(context, friendlyError(e, l10n: mounted ? context.l10n : null));
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _call(String phone) async {
    final u = Uri(scheme: "tel", path: phone);
    try { await launchUrl(u); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OffroColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            OffroScreenHeader(
              eyebrow: context.l10n.bizCollaborationRequest,
              title: (_d["title"] ?? context.l10n.bizBrief).toString(),
              showBack: true,
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: OffroSpacing.gutterH,
              child: _loading
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator(color: OffroColors.primary)))
                  : _error != null
                      ? _loadError(_error!, _load)
                      : _body(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => v.trim().isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _eyebrow(k),
            const SizedBox(height: 4),
            Text(v, style: OffroText.body.copyWith(color: OffroColors.text, fontSize: 14)),
          ]),
        );

  Widget _body() {
    final store = (_d["store"] is Map) ? Map<String, dynamic>.from(_d["store"]) : <String, dynamic>{};
    final my = (_d["my_status"] ?? "new").toString();
    final canRespond = _d["can_respond"] == true;
    // Backend also enforces this; the app just shows it honestly.
    final canAccept = _d["can_accept"] != false;
    final blockedMsg = (_d["accept_blocked_message"] ?? "").toString().trim().isNotEmpty
        ? _d["accept_blocked_message"].toString()
        : context.l10n.bizCompleteYourProfileSubscriptionTo;
    final phone = (_d["merchant_phone"] ?? "").toString();
    final content = (_d["content_types"] is List)
        ? (_d["content_types"] as List).map((e) => e.toString()).join(", ") : "";
    final place = [store["area"], store["address"], store["city"]]
        .map((e) => (e ?? "").toString().trim()).where((e) => e.isNotEmpty).join(", ");
    final spec = (_d["speciality"] ?? "").toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OffroCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row(context.l10n.bizObjective, (_d["objective"] ?? "").toString()),
          _row(context.l10n.bizMessage, (_d["message"] ?? "").toString()),
          _row(context.l10n.bizRequestedContent, content),
          _row(context.l10n.bizVisitDate, _pretty(_d["visit_date"])),
          _row(context.l10n.bizPublishBy, _pretty(_d["publish_by"])),
          if (spec.isNotEmpty && spec != "Any") _row(context.l10n.bizPreferredSpeciality, spec),
        ]),
      ),
      const SizedBox(height: 12),
      OffroCard(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row(context.l10n.homeStoreWord, (store["name"] ?? "").toString()),
          _row(context.l10n.locTitle, place),
        ]),
      ),
      const SizedBox(height: 12),
      Text(
        context.l10n.bizThisCollaborationIsForPromotion,
        style: OffroText.body.copyWith(fontSize: 12.5)),
      const SizedBox(height: 20),
      if (my == "accepted") ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: OffroTones.grocery.background,
              borderRadius: BorderRadius.circular(OffroRadii.cardSm)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.l10n.bizYouAcceptedThisCollaboration, style: OffroText.cardTitle),
            const SizedBox(height: 6),
            Text(phone.isEmpty ? context.l10n.bizTheMerchantSContactNumber : context.l10n.bizContactTheMerchantToPlan,
                style: OffroText.body.copyWith(fontSize: 12.5)),
            if (phone.isNotEmpty) ...[
              const SizedBox(height: 12),
              OffroButton(label: context.l10n.bizCallPhone(ltrIsolate(context, phone)), onPressed: () => _call(phone)),
            ],
          ]),
        ),
      ] else if (!canRespond)
        Text(context.l10n.bizThisRequestIsNoLonger, style: OffroText.cardTitle)
      else ...[
        OffroButton(
          label: _busy ? context.l10n.bizPleaseWait : context.l10n.bizAcceptCollaboration,
          onPressed: (_busy || !canAccept) ? null : () => _respond(true),
        ),
        if (!canAccept) ...[
          const SizedBox(height: 8),
          Text(blockedMsg, textAlign: TextAlign.center, style: OffroText.body.copyWith(fontSize: 12.5)),
        ],
        if (my != "declined") ...[
          const SizedBox(height: 10),
          OffroButton.secondary(label: context.l10n.bizDecline, onPressed: _busy ? null : () => _respond(false)),
        ] else ...[
          const SizedBox(height: 10),
          Text((canAccept ? context.l10n.bizDeclinedCanAccept : context.l10n.bizDeclinedRequest),
              style: OffroText.body.copyWith(fontSize: 12.5)),
        ],
      ],
    ]);
  }
}
