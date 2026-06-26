// lib/screens/store/widgets/store_reviews_section.dart
// Fix: Invalid store_id error — guard against empty storeId before API calls.
// Fix: Broken string interpolation on _total review count.
// Empty state: clean "No reviews yet. Be the first to review." — no large icons.
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/api_service.dart';

class StoreReviewsSection extends StatefulWidget {
  final String storeId;
  final String token;
  final String userName;

  const StoreReviewsSection({
    super.key,
    required this.storeId,
    required this.token,
    this.userName = '',
  });

  @override
  State<StoreReviewsSection> createState() =>
      _StoreReviewsSectionState();
}

class _StoreReviewsSectionState extends State<StoreReviewsSection> {
  List<Map<String, dynamic>> _reviews = [];
  int    _total     = 0;
  double _avgRating = 0.0;
  bool   _loading   = true;
  bool   _showForm  = false;
  double _draftRating = 0;
  final _textCtrl = TextEditingController();
  bool   _submitting = false;
  String _msg = '';
  Map<String, dynamic>? _userReview; // FIX4: this user's existing review

  @override
  void initState() {
    super.initState();
    // Guard: only load if storeId is valid
    if (widget.storeId.isNotEmpty) {
      _loadReviews();
      if (widget.token.isNotEmpty) _loadUserReview();
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// FIX4: Fetch this user's own review for the store
  Future<void> _loadUserReview() async {
    try {
      final d = await Api.getUserReview(widget.token, widget.storeId);
      final r = d['review'];
      if (mounted && r != null) {
        setState(() {
          _userReview = Map<String, dynamic>.from(r);
          _draftRating = (_userReview!['rating'] as num?)?.toDouble() ?? 0;
          _textCtrl.text = _userReview!['text']?.toString() ?? '';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    if (widget.storeId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final d =
          await Api.getReviews(widget.storeId, limit: 3);
      if (mounted) {
        setState(() {
          _reviews = List<Map<String, dynamic>>.from(
              (d['reviews'] as List? ?? [])
                  .map((r) => Map<String, dynamic>.from(r)));
          _total     = (d['total'] as num?)?.toInt() ?? 0;
          _avgRating =
              (d['avg_rating'] as num?)?.toDouble() ?? 0.0;
          if (_avgRating == 0.0 && _reviews.isNotEmpty) {
            final sum = _reviews.fold<double>(
                0,
                (acc, r) =>
                    acc +
                    ((r['rating'] as num?)?.toDouble() ?? 0.0));
            _avgRating = sum / _reviews.length;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    // Guard: never submit if storeId is empty
    if (widget.storeId.isEmpty) {
      setState(() => _msg = 'Store not found. Cannot submit review.');
      return;
    }
    final text = _textCtrl.text.trim();
    if (_draftRating == 0) {
      setState(() => _msg = 'Please select a star rating');
      return;
    }
    if (text.length < 5) {
      setState(() => _msg = 'Write at least 5 characters');
      return;
    }
    setState(() {
      _submitting = true;
      _msg = '';
    });
    try {
      await Api.submitReview(
        widget.token,
        widget.storeId,
        _draftRating,
        text,
        userName: widget.userName,
      );
      _textCtrl.clear();
      setState(() {
        _showForm = false;
        _draftRating = 0;
        _submitting = false;
      });
      await _loadReviews();
      if (widget.token.isNotEmpty) await _loadUserReview(); // FIX4: refresh own review
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⭐ Review submitted! Thank you.'),
            backgroundColor: kPrimary,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _msg = e.toString().replaceAll('Exception: ', '');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard: if storeId is empty, show clean message
    if (widget.storeId.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Text('Store information unavailable.',
            style: const TextStyle(color: kMuted, fontSize: 13)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // ── Header ──
        Row(children: [
          const Text('Reviews',
              style: TextStyle(
                  color: kText,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          if (_avgRating > 0) ...[
            const Icon(Icons.star_rounded,
                color: Color(0xFFFFB300), size: 16),
            const SizedBox(width: 3),
            Text(_avgRating.toStringAsFixed(1),
                style: const TextStyle(
                    color: kText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
          ],
          if (_total > 0)
            Text(
              '($_total review${_total == 1 ? "" : "s"})',
              style: const TextStyle(
                  color: kMuted, fontSize: 12),
            ),
          if (_total == 0 && !_loading)
            const Text('No reviews yet',
                style:
                    TextStyle(color: kMuted, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        const Text('What customers are saying',
            style:
                TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 14),

        // ── FIX4: Smart write / edit review UI ──
        if (!_showForm) ...[
          if (_userReview != null) ...[
            // Existing review card with Edit button
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kLight.withValues(alpha: .4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kAccent.withValues(alpha: .6)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.person_rounded, color: kPrimary, size: 15),
                  const SizedBox(width: 6),
                  const Text("Your Review",
                      style: TextStyle(color: kText, fontSize: 13, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _showForm = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: kPrimary, borderRadius: BorderRadius.circular(10)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text("Edit",
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: List.generate(5, (i) => Icon(
                  i < (_userReview!['rating'] as num? ?? 0).toInt()
                      ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < (_userReview!['rating'] as num? ?? 0).toInt()
                      ? const Color(0xFFFFD700) : kMuted,
                  size: 16))),
                const SizedBox(height: 6),
                Text(_userReview!['text']?.toString() ?? '',
                    style: const TextStyle(color: kText, fontSize: 13, height: 1.4),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ] else if (widget.token.isNotEmpty) ...[
            GestureDetector(
              onTap: () => setState(() => _showForm = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: kLight.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kAccent.withValues(alpha: .5)),
                ),
                child: const Row(children: [
                  Icon(Icons.rate_review_rounded, color: kPrimary, size: 18),
                  SizedBox(width: 10),
                  Text('Write a review…',
                      style: TextStyle(color: kMuted, fontSize: 13)),
                ]),
              ),
            ),
          ],
        ],

        // ── Review form ──
        if (_showForm) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .06),
                    blurRadius: 12,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              const Text('Your Rating',
                  style: TextStyle(
                      color: kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => GestureDetector(
                    onTap: () => setState(
                        () => _draftRating = i + 1.0),
                    child: Padding(
                      padding:
                          const EdgeInsets.only(right: 4),
                      child: Icon(
                        i < _draftRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: i < _draftRating
                            ? const Color(0xFFFFD700)
                            : kMuted,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _textCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Share your experience…',
                  hintStyle: const TextStyle(
                      color: kMuted, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFFDFBF6),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: kBorder)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: kBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: kPrimary, width: 1.5)),
                ),
              ),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(_msg,
                    style: const TextStyle(
                        color: Colors.red, fontSize: 11)),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _showForm = false;
                      _msg = '';
                    }),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kMuted,
                      side: const BorderSide(color: kBorder),
                      padding: const EdgeInsets.symmetric(
                          vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 11),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                        : const Text('Submit',
                            style: TextStyle(
                                fontWeight:
                                    FontWeight.w800)),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        // ── Review list or empty state ──
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kPrimary),
            ),
          )
        else if (_reviews.isEmpty && !_showForm)
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 12),
            child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              const Text(
                'No reviews yet.',
                style: TextStyle(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              const Text(
                'Be the first to review.',
                style: TextStyle(
                    color: kMuted, fontSize: 13),
              ),
            ]),
          )
        else
          Column(
            children: _reviews
                .map((r) => _ReviewCard(review: r))
                .toList(),
          ),

        // View All
        if (_total > 3 && _reviews.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GestureDetector(
              onTap: () => _showAllReviews(context),
              child: const Text(
                'View all reviews →',
                style: TextStyle(
                    color: kPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ]),
    );
  }

  void _showAllReviews(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: .75,
        maxChildSize: .95,
        minChildSize: .4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(
                  top: 12, bottom: 12),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('All Reviews',
                  style: TextStyle(
                      color: kText,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: _AllReviewsList(
                storeId: widget.storeId,
                controller: ctrl,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Review card ─────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name    = review['user_name']?.toString() ?? 'Anonymous';
    final rating  = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final text    = review['text']?.toString() ?? '';
    final dateStr = review['created_at']?.toString() ?? '';
    String dateLabel = '';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec',
      ];
      dateLabel =
          '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
        border:
            Border.all(color: kBorder.withValues(alpha: .5)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: kLight,
            child: Text(
              name.isNotEmpty
                  ? name[0].toUpperCase()
                  : 'A',
              style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
              Text(name,
                  style: const TextStyle(
                      color: kText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              if (dateLabel.isNotEmpty)
                Text(dateLabel,
                    style: const TextStyle(
                        color: kMuted, fontSize: 10)),
            ]),
          ),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating.round()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: const Color(0xFFFFD700),
                size: 14,
              ),
            ),
          ),
        ]),
        if (text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(text,
              style: const TextStyle(
                  color: kMuted, fontSize: 12, height: 1.6)),
        ],
      ]),
    );
  }
}

// ─── All Reviews List ─────────────────────────────────────────
class _AllReviewsList extends StatefulWidget {
  final String storeId;
  final ScrollController controller;
  const _AllReviewsList(
      {required this.storeId, required this.controller});

  @override
  State<_AllReviewsList> createState() =>
      _AllReviewsListState();
}

class _AllReviewsListState extends State<_AllReviewsList> {
  final List<Map<String, dynamic>> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.storeId.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final d =
          await Api.getReviews(widget.storeId, limit: 50);
      if (mounted) {
        setState(() {
          _all.addAll(List<Map<String, dynamic>>.from(
              (d['reviews'] as List? ?? []).map(
                  (r) => Map<String, dynamic>.from(r))));
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: kPrimary));
    }
    if (_all.isEmpty) {
      return const Center(
          child: Text('No reviews yet',
              style: TextStyle(color: kMuted)));
    }
    return ListView.builder(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: _all.length,
      itemBuilder: (_, i) => _ReviewCard(review: _all[i]),
    );
  }
}
