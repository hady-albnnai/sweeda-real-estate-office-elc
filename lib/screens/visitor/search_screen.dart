import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offer_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/shimmer_loading.dart';

/// 🔎 شاشة البحث — بحث نصّي + فلترة بالنوع والمعاملة
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchCtrl = TextEditingController();
  int? _type; // 0=عقار, 1=سيارة
  int? _trx; // 0=بيع, 1=إيجار

  List<OfferModel> _results = [];
  bool _loading = false;
  bool _searched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    setState(() {
      _loading = true;
      _searched = true;
    });
    final results = await context.read<OfferProvider>().searchOffers(
          query: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
          type: _type,
          transaction: _trx,
        );
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('بحث'),
      ),
      body: Column(
        children: [
          // ── شريط البحث ──
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 6),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppTheme.textWhite),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _doSearch(),
              decoration: InputDecoration(
                hintText: 'ابحث عن عقار أو سيارة...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_circle_left,
                      color: AppTheme.primaryGold),
                  onPressed: _doSearch,
                ),
                filled: true,
                fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── الفلاتر ──
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              children: [
                _chip('🏠 عقار', _type == 0, () {
                  setState(() => _type = _type == 0 ? null : 0);
                }),
                const SizedBox(width: 8),
                _chip('🚗 سيارة', _type == 1, () {
                  setState(() => _type = _type == 1 ? null : 1);
                }),
                const SizedBox(width: 8),
                _chip('بيع', _trx == 0, () {
                  setState(() => _trx = _trx == 0 ? null : 0);
                }),
                const SizedBox(width: 8),
                _chip('إيجار', _trx == 1, () {
                  setState(() => _trx = _trx == 1 ? null : 1);
                }),
              ],
            ),
          ),

          // ── زر البحث ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _doSearch,
                icon: const Icon(Icons.search),
                label: Text(_loading ? 'جارٍ البحث...' : 'بحث'),
              ),
            ),
          ),

          // ── النتائج ──
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading) return ShimmerLoading.offerList();

    if (!_searched) {
      return _hint(
          Icons.search, 'ابحث عن عقارات وسيارات\nاستخدم الكلمات أو الفلاتر بالأعلى');
    }

    if (_results.isEmpty) {
      return _hint(Icons.search_off, 'لا توجد نتائج مطابقة\nجرّب كلمات أو فلاتر مختلفة');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: _results.length,
      itemBuilder: (_, i) => OfferCard(offer: _results[i]),
    );
  }

  Widget _hint(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppTheme.textGrey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textGrey, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(
            color: selected ? AppTheme.deepBlack : AppTheme.textWhite,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
      selected: selected,
      selectedColor: AppTheme.primaryGold,
      backgroundColor: AppTheme.surfaceBlack,
      checkmarkColor: AppTheme.deepBlack,
      side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
      onSelected: (_) => onTap(),
    );
  }
}
