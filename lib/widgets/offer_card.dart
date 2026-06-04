import 'package:flutter/material.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class OfferCard extends StatelessWidget {
  final OfferModel offer;
  const OfferCard({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 200, width: double.infinity,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(offer.imgs.isNotEmpty ? offer.imgs[0] : 'https://via.placeholder.com/400x200'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 15, right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.primaryGold, borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]),
                    child: Text('${offer.prc} ل.س', style: const TextStyle(color: AppTheme.deepBlack, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                Positioned(
                  bottom: 15, left: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryGold, width: 0.5)),
                    child: Text(offer.typ == 0 ? 'عقار' : 'سيارة', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 12)),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.ttl, style: const TextStyle(color: AppTheme.textWhite, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 16), const SizedBox(width: 4),
                    Text(offer.loc['d'] ?? '', style: const TextStyle(color: AppTheme.textGrey, fontSize: 14)),
                  ]),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: () => context.push('/offer/${offer.id}'), style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold, padding: EdgeInsets.zero),
                        child: const Text('التفاصيل ←', style: TextStyle(fontWeight: FontWeight.bold))),
                      const Icon(Icons.favorite_border, color: AppTheme.textGrey, size: 24),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
