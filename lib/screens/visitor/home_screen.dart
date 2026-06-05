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
            onPressed: () {
              // الزائر بحاجة تسجيل دخول لرؤية الإشعارات
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('سجّل دخولك لرؤية الإشعارات'),
                  action: SnackBarAction(
                    label: 'دخول',
                    onPressed: () => context.push('/login'),
                  ),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.person_outline), onPressed: () => context.push('/login')),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث عن عقار أو سيارة...',
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                    suffixIcon: IconButton(icon: const Icon(Icons.tune, color: AppTheme.primaryGold), onPressed: () => context.push('/search')),
                  ),
                ),
                const SizedBox(height: 20),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _buildChip('الكل', true), _buildChip('شقق', false),
                    _buildChip('فلل', false), _buildChip('أراضي', false), _buildChip('سيارات', false),
                  ]),
                ),
              ],
            ),
          ),
          Expanded(
            child: offerProvider.offers.isEmpty
                ? const Center(child: Text('لا توجد عروض متاحة حالياً', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: offerProvider.offers.length,
                    itemBuilder: (context, index) => OfferCard(offer: offerProvider.offers[index]),
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

  Widget _buildChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(left: 10),
      child: Chip(
        label: Text(label),
        backgroundColor: isSelected ? AppTheme.primaryGold : AppTheme.surfaceBlack,
        labelStyle: TextStyle(color: isSelected ? AppTheme.deepBlack : AppTheme.textWhite, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
        side: BorderSide(color: AppTheme.primaryGold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
