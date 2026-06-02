import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offer_provider.dart';
import '../../widgets/offer_card.dart';

/// الشاشة الرئيسية — يراها الزائر والمستخدم
/// تعرض آخر العروض مع شريط بحث
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OfferProvider>().loadPublishedOffers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عقارات السويداء'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
        ],
      ),
      body: Consumer<OfferProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.offers.isEmpty) {
            return const Center(
              child: Text('لا توجد عروض حالياً'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadPublishedOffers(),
            child: ListView.builder(
              itemCount: provider.offers.length,
              itemBuilder: (context, index) {
                return OfferCard(offer: provider.offers[index]);
              },
            ),
          );
        },
      ),
      bottomNavigationBar: const _MainNavBar(),
    );
  }
}

/// شريط التنقل السفلي — 3 تبويبات رئيسية
class _MainNavBar extends StatelessWidget {
  const _MainNavBar();

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite_outline),
          activeIcon: Icon(Icons.favorite),
          label: 'المفضلة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'حسابي',
        ),
      ],
      currentIndex: 0,
      onTap: (index) {
        // التنقل حسب index
      },
    );
  }
}