import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/offer_model.dart';
import '../../providers/offer_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/book_appointment_sheet.dart';

class OfferDetailScreen extends StatelessWidget {
  final String offerId;
  const OfferDetailScreen({super.key, required this.offerId});

  @override
  Widget build(BuildContext context) {
    final offerProvider = Provider.of<OfferProvider>(context);
    final offer = offerProvider.getOfferById(offerId);
    if (offer == null) return const Scaffold(body: Center(child: Text('العرض غير موجود')));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300, pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Image.network(offer.imgs.isNotEmpty ? offer.imgs[0] : 'https://via.placeholder.com/400x300', fit: BoxFit.cover),
                const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppTheme.deepBlack]))),
              ]),
            ),
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => Navigator.pop(context)),
            actions: [IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {})],
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppTheme.deepBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(offer.ttl, style: const TextStyle(color: AppTheme.textWhite, fontSize: 24, fontWeight: FontWeight.bold)),
                    Text('${offer.prc} ل.س', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 22, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 20), const SizedBox(width: 5),
                    Text(offer.loc['d'] ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 16)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('الوصف التفصيلي', style: TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(offer.descript, style: const TextStyle(color: AppTheme.textWhite, fontSize: 16, height: 1.5)),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 3,
                    children: [
                      _spec(Icons.category, 'النوع', offer.typ == 0 ? 'عقار' : 'سيارة'),
                      _spec(Icons.swap_horiz, 'المعاملة', offer.trx == 0 ? 'بيع' : 'إيجار'),
                      _spec(Icons.info, 'الفئة', offer.cat.toString()),
                      _spec(Icons.verified, 'السند', 'متوفر'),
                    ],
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                        builder: (context) => BookAppointmentSheet(offer: offer)),
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

  Widget _spec(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, color: AppTheme.primaryGold, size: 18), const SizedBox(width: 8),
        Expanded(child: Text('$label: $value', style: const TextStyle(color: AppTheme.textWhite, fontSize: 14), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
