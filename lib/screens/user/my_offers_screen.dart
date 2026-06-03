import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/offer_card.dart';
import '../../core/theme/app_theme.dart';

class MyOffersScreen extends StatelessWidget {
  const MyOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final offerProvider = Provider.of<OfferProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    final myOffers = offerProvider.offers.where((o) => o.uId == authProvider.currentUser?.uid).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('عروضي الخاصة'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: myOffers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 80, color: AppTheme.primaryGold.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  const Text(
                    'ليس لديك عروض منشورة حالياً',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to add offer
                    },
                    child: const Text('أضف عرضك الأول'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: myOffers.length,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    OfferCard(offer: myOffers[index]),
                    // Status Badge for My Offers
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBlack,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      border: Border(bottom: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3))),
                    ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('حالة العرض:', style: TextStyle(color: AppTheme.textGrey)),
                          Text(
                            _getStatusText(myOffers[index].sts),
                            style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
    );
  }

  String _getStatusText(int sts) {
    switch (sts) {
      case 0: return 'قيد المراجعة';
      case 1: return 'منشور';
      case 2: return 'محجوز مؤقتاً';
      case 3: return 'ملغي';
      case 4: return 'منتهي';
      case 5: return 'مباع / مؤجر';
      default: return 'غير معروف';
    }
  }
}
