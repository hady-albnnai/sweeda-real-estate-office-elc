import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offer_provider.dart';
import '../../widgets/offer_card.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final offerProvider = Provider.of<OfferProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المكتب العقاري الالكتروني'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/login'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عقار أو سيارة...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.tune, color: AppTheme.primaryGold),
                      onPressed: () => context.push('/search'),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Quick Categories
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCategoryChip('الكل', true),
                      _buildCategoryChip('شقق', false),
                      _buildCategoryChip('فلل', false),
                      _buildCategoryChip('أراضي', false),
                      _buildCategoryChip('سيارات', false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Offers List
          Expanded(
            child: offerProvider.offers.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد عروض متاحة حالياً',
                      style: TextStyle(color: AppTheme.textGrey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: offerProvider.offers.length,
                    itemBuilder: (context, index) {
                      return OfferCard(offer: offerProvider.offers[index]);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppTheme.deepBlack,
        selectedItemColor: AppTheme.primaryGold,
        unselectedItemColor: AppTheme.textGrey,
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'بحث'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'المفضلة'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'حسابي'),
        ],
        onTap: (index) {
          if (index == 1) context.push('/search');
          if (index == 3) context.push('/login');
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? AppTheme.primaryGold : AppTheme.surfaceBlack,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.deepBlack : AppTheme.textWhite,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(color: AppTheme.primaryGold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
