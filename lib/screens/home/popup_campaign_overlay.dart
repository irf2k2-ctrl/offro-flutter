import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/api_service.dart';

const kPrimary = Color(0xFF3E5F55);
const _prefKeyPrefix = 'popup_shown_';

// ─── Top-level helpers (shared by widget + orchestrator) ─────────────────────

bool _isWithinDateRange(Map<String, dynamic> c) {
  final startStr = c['start_dt']?.toString() ?? '';
  final endStr   = c['end_dt']?.toString() ?? '';
  if (startStr.isEmpty || endStr.isEmpty) return true;
  final now = DateTime.now();
  try {
    final start = DateTime.parse(startStr);
    final end   = DateTime.parse(endStr);
    return now.isAfter(start) && now.isBefore(end);
  } catch (_) {
    return true;
  }
}

Future<bool> _shouldShowCampaign(Map<String, dynamic> c) async {
  if (!_isWithinDateRange(c)) return false;
  final id        = c['id']?.toString() ?? '';
  final frequency = c['frequency']?.toString() ?? 'once_per_day';
  if (id.isEmpty) return false;

  final prefs = await SharedPreferences.getInstance();

  if (frequency == 'show_once') {
    return !(prefs.getBool('${_prefKeyPrefix}once_$id') ?? false);
  }
  if (frequency == 'once_per_day') {
    final lastShownStr = prefs.getString('${_prefKeyPrefix}day_$id') ?? '';
    if (lastShownStr.isEmpty) return true;
    try {
      final last = DateTime.parse(lastShownStr);
      final now  = DateTime.now();
      return !(last.year == now.year &&
               last.month == now.month &&
               last.day == now.day);
    } catch (_) {
      return true;
    }
  }
  // every_open — always show
  return true;
}

Future<void> _recordShown(Map<String, dynamic> c) async {
  final id        = c['id']?.toString() ?? '';
  final frequency = c['frequency']?.toString() ?? 'once_per_day';
  if (id.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  if (frequency == 'show_once') {
    await prefs.setBool('${_prefKeyPrefix}once_$id', true);
  } else if (frequency == 'once_per_day') {
    await prefs.setString(
        '${_prefKeyPrefix}day_$id', DateTime.now().toIso8601String());
  }
}

// ─── PopupCampaignOverlay ─────────────────────────────────────────────────────
// Receives a pre-loaded campaign map — no internal API fetch.
// showPopupCampaignIfNeeded is the orchestrator that queues them.

class PopupCampaignOverlay extends StatefulWidget {
  final Map<String, dynamic> campaign;
  final String token;
  final Function(Map<String, dynamic> store)? onOpenStore;
  final Function(Map<String, dynamic> product)? onOpenProduct;
  final Function(Map<String, dynamic> deal)? onOpenDeal;
  final Function(String category)? onOpenCategory;

  const PopupCampaignOverlay({
    super.key,
    required this.campaign,
    this.token = '',
    this.onOpenStore,
    this.onOpenProduct,
    this.onOpenDeal,
    this.onOpenCategory,
  });

  @override
  State<PopupCampaignOverlay> createState() => _PopupCampaignOverlayState();
}

class _PopupCampaignOverlayState extends State<PopupCampaignOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ac   = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    // Campaign is already pre-loaded — show immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ac.forward();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ac.reverse();
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  Future<void> _handleTap() async {
    final c      = widget.campaign;
    final action = c['click_action']?.toString() ?? 'none';
    final value  = c['action_value']?.toString() ?? '';
    await _dismiss();
    if (!mounted) return;
    switch (action) {
      case 'open_url':
        if (value.isNotEmpty) {
          final uri = Uri.tryParse(value);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
        break;
      case 'open_store':
        if (value.isNotEmpty && widget.onOpenStore != null) {
          widget.onOpenStore!({'_id': value, 'id': value});
        }
        break;
      case 'open_product':
        if (value.isNotEmpty && widget.onOpenProduct != null) {
          widget.onOpenProduct!({'_id': value, 'id': value});
        }
        break;
      case 'open_deal':
        if (value.isNotEmpty && widget.onOpenDeal != null) {
          widget.onOpenDeal!({'_id': value, 'id': value});
        }
        break;
      case 'open_category':
        if (value.isNotEmpty && widget.onOpenCategory != null) {
          widget.onOpenCategory!(value);
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c        = widget.campaign;
    final imageUrl = c['image_url']?.toString() ?? '';
    final fullUrl  = imageUrl.startsWith('http')
        ? imageUrl
        : imageUrl.startsWith('/popup-image')
            ? '$kBaseUrl$imageUrl'
            : '';

    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _handleTap,
          child: Container(
            color: Colors.black.withOpacity(0.6),
            alignment: Alignment.center,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Popup card
                GestureDetector(
                  onTap: _handleTap,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 28),
                    constraints: BoxConstraints(
                      maxWidth: 360,
                      maxHeight:
                          MediaQuery.of(context).size.height * 0.75,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: fullUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: fullUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            placeholder: (_, __) => const AspectRatio(
                              aspectRatio: 9 / 16,
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation(kPrimary),
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) =>
                                const AspectRatio(
                              aspectRatio: 9 / 16,
                              child: Center(
                                child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                    color: Colors.black26),
                              ),
                            ),
                          )
                        : const AspectRatio(
                            aspectRatio: 9 / 16,
                            child: Center(
                              child: Icon(Icons.campaign_outlined,
                                  size: 64, color: kPrimary),
                            ),
                          ),
                  ),
                ),

                // Close button
                Positioned(
                  top: 0,
                  right: 28,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, right: 8),
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Orchestrator ─────────────────────────────────────────────────────────────
/// Fetches ALL active campaigns eligible for this city + user, then shows them
/// one after another — each dialog is awaited so the next only opens after the
/// user closes the current one.
Future<void> showPopupCampaignIfNeeded({
  required BuildContext context,
  required String city,
  String token = '',
  Function(Map<String, dynamic>)? onOpenStore,
  Function(Map<String, dynamic>)? onOpenProduct,
  Function(Map<String, dynamic>)? onOpenDeal,
  Function(String)? onOpenCategory,
}) async {
  if (!context.mounted) return;

  // Fetch full list from backend (already filtered by active + city on server)
  List raw;
  try {
    raw = await Api.get(
      '/public/popup-campaigns?city=${Uri.encodeComponent(city)}',
    ) as List;
  } catch (_) {
    return;
  }
  if (raw.isEmpty) return;

  // Build eligible queue: check date range + frequency on device
  final queue = <Map<String, dynamic>>[];
  for (final item in raw) {
    final campaign = Map<String, dynamic>.from(item as Map);
    if (await _shouldShowCampaign(campaign)) {
      queue.add(campaign);
    }
  }
  if (queue.isEmpty) return;

  // Show each popup in sequence — await ensures the next only opens after close
  for (final campaign in queue) {
    if (!context.mounted) break;

    // Record before showing so frequency is tracked even if app is killed mid-popup
    await _recordShown(campaign);

    await showDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopupCampaignOverlay(
        campaign:       campaign,
        token:          token,
        onOpenStore:    onOpenStore,
        onOpenProduct:  onOpenProduct,
        onOpenDeal:     onOpenDeal,
        onOpenCategory: onOpenCategory,
      ),
    );

    // Small gap between consecutive popups
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
