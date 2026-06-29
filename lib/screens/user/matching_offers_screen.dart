import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/offer_model.dart';
import '../../core/services/business_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/offer_provider.dart';

class MatchingOffersScreen extends StatefulWidget {
  final Map<String, dynamic> requestData;

  const MatchingOffersScreen({super.key, required this.requestData});

  @override
  State<MatchingOffersScreen> createState() => _MatchingOffersScreenState();
}

class _MatchingOffersScreenState extends State<MatchingOffersScreen> {
  List<OfferModel> _matchingOffers = [];
  List<OfferModel> _filteredOffers = [];
  bool _loading = true;

  // فلاتر
  double _minPrice = 0;
  double _maxPrice = 1000000;
  String _sortBy = 'match_score';
  String? _selectedCity;
  int? _minRooms;
  int? _maxKm;

  @override
  void initState() {
    super.initState();
    _loadMatchingOffers();
  }

  Future<void> _loadMatchingOffers() async {
    setState(() => _loading = true);

    final offerProvider = context.read<OfferProvider>();
    await offerProvider.fetchOffers();

    final List<OfferModel> matches = [];

    for (final offer in offerProvider.offers) {
      final scoreData = BusinessService().calculateMatchScore(
        request: widget.requestData,
        offer: offer,
      );

      if (scoreData['score'] >= 40) {
        offer.matchScore = scoreData['score'];
        offer.matchBreakdown = scoreData['breakdown'];
        matches.add(offer);
      }
    }

    matches.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));

    setState(() {
      _matchingOffers = matches;
      _filteredOffers = List.from(matches);
      _loading = false;
    });
  }

  void _applyFilters() {
    List<OfferModel> filtered = List.from(_matchingOffers);

    // فلتر السعر
    filtered = filtered.where((o) => o.prc >= _minPrice && o.prc <= _maxPrice).toList();

    // فلتر الموقع (للعقارات)
    if (_selectedCity != null && widget.requestData['typ'] == 0) {
      filtered = filtered.where((o) {
        final city = o.loc['city']?.toString().toLowerCase();
        return city == _selectedCity!.toLowerCase();
      }).toList();
    }

    // فلتر عدد الغرف (للعقارات)
    if (_minRooms != null && widget.requestData['typ'] == 0) {
      filtered = filtered.where((o) {
        final rooms = (o.specs['rooms'] as num?)?.toInt() ?? 0;
        return rooms >= _minRooms!;
      }).toList();
    }

    // فلتر الكيلومترات (للسيارات)
    if (_maxKm != null && widget.requestData['typ'] == 1) {
      filtered = filtered.where((o) {
        final km = (o.specs['km'] as num?)?.toInt() ?? 999999;
        return km <= _maxKm!;
      }).toList();
    }

    // ترتيب
    if (_sortBy == 'match_score') {
      filtered.sort((a, b) => (b.matchScore ?? 0).compareTo(a.matchScore ?? 0));
    } else if (_sortBy == 'price_low') {
      filtered.sort((a, b) => a.prc.compareTo(b.prc));
    } else if (_sortBy == 'price_high') {
      filtered.sort((a, b) => b.prc.compareTo(a.prc));
    }

    setState(() {
      _filteredOffers = filtered;
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      isScrollControlled: true,
      builder: (_) => _buildFilterSheet(),
    );
  }

  Widget _buildFilterSheet() {
    final isProperty = widget.requestData['typ'] == 0;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('فلاتر البحث', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _buildPriceSlider(),

          if (isProperty) ...[
            const SizedBox(height: 16),
            _buildCityFilter(),
            const SizedBox(height: 12),
            _buildRoomsFilter(),
          ] else ...[
            const SizedBox(height: 16),
            _buildKmFilter(),
          ],

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyFilters();
            },
            child: const Text('تطبيق الفلاتر'),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('نطاق السعر', style: TextStyle(color: AppTheme.textWhite)),
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 1000000,
          divisions: 20,
          onChanged: (values) {
            setState(() {
              _minPrice = values.start;
              _maxPrice = values.end;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCityFilter() {
    final cities = ['السويداء', 'صلخد', 'شهبا', 'المزرعة', 'الكفر', 'قنوات'];
    return DropdownButtonFormField<String>(
      value: _selectedCity,
      decoration: const InputDecoration(labelText: 'الموقع', border: OutlineInputBorder()),
      items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (v) => setState(() => _selectedCity = v),
    );
  }

  Widget _buildRoomsFilter() {
    return DropdownButtonFormField<int>(
      value: _minRooms,
      decoration: const InputDecoration(labelText: 'عدد الغرف (الحد الأدنى)', border: OutlineInputBorder()),
      items: [1, 2, 3, 4].map((r) => DropdownMenuItem(value: r, child: Text('$r غرف فأكثر'))).toList(),
      onChanged: (v) => setState(() => _minRooms = v),
    );
  }

  Widget _buildKmFilter() {
    return DropdownButtonFormField<int>(
      value: _maxKm,
      decoration: const InputDecoration(labelText: 'الكيلومترات (الحد الأقصى)', border: OutlineInputBorder()),
      items: [50000, 100000, 150000].map((k) => DropdownMenuItem(value: k, child: Text('أقل من ${k ~/ 1000} ألف كم'))).toList(),
      onChanged: (v) => setState(() => _maxKm = v),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: Text('العروض المطابقة (${_filteredOffers.length})'),
        backgroundColor: AppTheme.deepBlack,
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilters),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تفعيل التنبيهات لهذا البحث')),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredOffers.isEmpty
              ? const Center(child: Text('لا توجد عروض مطابقة حالياً', style: TextStyle(color: AppTheme.textGrey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredOffers.length,
                  itemBuilder: (context, index) {
                    final offer = _filteredOffers[index];
                    return _buildOfferCard(offer);
                  },
                ),
    );
  }

  Widget _buildOfferCard(OfferModel offer) {
    final score = offer.matchScore ?? 0;

    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$score% مطابق', style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text('${offer.prc.toStringAsFixed(0)} ${offer.cur == 0 ? '\$' : 'ل.س'}',
                    style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Text(offer.ttl, style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(offer.loc['d'] ?? '', style: const TextStyle(color: AppTheme.textGrey)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // TODO: الانتقال إلى تفاصيل العرض
                    },
                    child: const Text('عرض التفاصيل'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: حجز موعد
                    },
                    child: const Text('حجز موعد'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
