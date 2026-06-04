import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../core/theme/app_theme.dart';

/// شاشة المفضلة — تحفظ محلياً بـ SharedPreferences
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
    final prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.userModel?.uid ?? '';
    final favJson = prefs.getString('favorites_$userId') ?? '[]';
    setState(() {
      _favIds = List<String>.from(jsonDecode(favJson));
      _isLoading = false;
    });
    // جلب بيانات العروض المفضلة
    if (_favIds.isNotEmpty) {
      await Provider.of<OfferProvider>(context, listen: false).fetchOffers();
    }
  }

  Future<void> _toggleFavorite(String offerId) async {
    final prefs = await SharedPreferences.getInstance();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.userModel?.uid ?? '';

    if (_favIds.contains(offerId)) {
      _favIds.remove(offerId);
    } else {
      _favIds.add(offerId);
    }
    await prefs.setString('favorites_$userId', jsonEncode(_favIds));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final offerProv = Provider.of<OfferProvider>(context);
    final favOffers = offerProv.offers.where((o) => _favIds.contains(o.id)).toList();

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
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
                      const Text('ما عندك عروض مفضلة حالياً',
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
