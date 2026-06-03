import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/offer_model.dart';
import '../../providers/offer_provider.dart';
import '../../core/theme/app_theme.dart';

class OfferDetailScreen extends StatelessWidget {
  final String offerId;

  const OfferDetailScreen({super.key, required this.offerId});

  @override
  Widget build(BuildContext context) {
    final offerProvider = Provider.of<OfferProvider>(context);
    final offer = offerProvider.getOfferById(offerId);

    if (offer == null) {
      return const Scaffold(body: Center(child: Text('العرض غير موجود')));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image Header
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    offer.imgs.isNotEmpty ? offer.imgs[0] : 'https://via.placeholder.com/400x300',
                    fit: BoxFit.cover,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppTheme.deepBlack],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.deepBlack,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        offer.title,
                        style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${offer.prc} ل.س',
                        style: const TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 20),
                      const SizedBox(width: 5),
                      Text(
                        offer.loc,
                        style: const TextStyle(color: AppTheme.textGrey, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'الوصف التفصيلي',
                    style: TextStyle(
                      color: AppTheme.primaryGold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    offer.desc,
                    style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  // Specs Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3,
                    children: [
                      _buildSpecItem(Icons.category, 'النوع', offer.type == 1 ? 'عقار' : 'سيارة'),
                      _buildSpecItem(Icons.swap_horiz, 'المعاملة', offer.trans == 1 ? 'بيع' : 'إيجار'),
                      _buildSpecItem(Icons.info, 'الفئة', offer.cat.toString()),
                      _buildSpecItem(Icons.verified, 'السند', 'متوفر'),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle booking
                      },
                      child: const Text('حجز موعد للمعاينة'),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
