import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/offer_provider.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/local_cache_service.dart';

/// شاشة المفضلة — تحفظ محلياً بـ Hive (LocalCacheService)
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<String> _favIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    _favIds = LocalCacheService().getFavorites();
    setState(() => _isLoading = false);
    // جلب بيانات العروض المفضلة
    if (_favIds.isNotEmpty) {
      await Provider.of<OfferProvider>(context, listen: false).fetchOffers();
    }
  }

  Future<void> _toggleFavorite(String offerId) async {
    await LocalCacheService().toggleFavorite(offerId);
    _favIds = LocalCacheService().getFavorites();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final offerProv = Provider.of<OfferProvider>(context);
    final favOffers = offerProv.offers.where((o) => _favIds.contains(o.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        title: Text(
          'المفضلة (${favOffers.length})',
          style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : favOffers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: AppTheme.textGrey.withOpacity(0.3)),
                      const SizedBox(height: 20),
                      Text('ما عندك عروض مفضلة حالياً',
                          style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.search),
                        label: const Text('تصفح العروض'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: favOffers.length,
                  itemBuilder: (context, index) {
                    final offer = favOffers[index];
                    return Stack(
                      children: [
                        OfferCard(offer: offer),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: GestureDetector(
                            onTap: () => _toggleFavorite(offer.id),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 3),
    );
  }
}
