import 'package:flutter/material.dart';
import '../models/offer_model.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../core/services/local_cache_service.dart';
import 'package:go_router/go_router.dart';

class OfferCard extends StatefulWidget {
  final OfferModel offer;
  const OfferCard({super.key, required this.offer});

  @override
  State<OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<OfferCard> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = LocalCacheService().isFavorite(widget.offer.id);
  }

  Future<void> _toggleFav() async {
    final added = await LocalCacheService().toggleFavorite(widget.offer.id);
    if (mounted) setState(() => _isFav = added);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added ? 'أُضيف للمفضلة ❤️' : 'أُزيل من المفضلة'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  static Widget _boostBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(0, 1))
        ],
      ),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;

    // FIX 1+2: السعر مع العملة الصحيحة + تنسيق NumberFormat
    final priceLabel = AppUtils.formatPrice(offer.prc, currency: offer.cur);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primaryGold.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(offer.imgs.isNotEmpty
                        ? offer.imgs[0]
                        : 'https://via.placeholder.com/400x200'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // شارات الترقيات (spd)
              Positioned(
                top: 15, left: 15,
                child: Wrap(
                  spacing: 4, runSpacing: 4,
                  children: [
                    if (offer.iPin == 1)
                      _boostBadge('📌 مثبّت', Colors.orange),
                    if (offer.iFms == 1)
                      _boostBadge('⭐ مميّز', AppTheme.primaryGold),
                    if (offer.iBst == 1)
                      _boostBadge('🚀 Boost', Colors.purple),
                  ],
                ),
              ),
              // FIX: السعر مع العملة الصحيحة
              Positioned(
                top: 15, right: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                    ],
                  ),
                  child: Text(priceLabel,
                      style: const TextStyle(
                          color: AppTheme.deepBlack,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ),
              ),
              Positioned(
                bottom: 15, left: 15,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primaryGold, width: 0.5),
                  ),
                  child: Text(offer.typ == 0 ? 'عقار' : 'سيارة',
                      style: const TextStyle(
                          color: AppTheme.primaryGold, fontSize: 12)),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.ttl,
                      style: const TextStyle(
                          color: AppTheme.textWhite,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  // 🏢 هوية المكتب
                  if (offer.ownerLabel != null && offer.ownerLabel!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.business_center,
                            color: AppTheme.primaryGold, size: 12),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(offer.ownerLabel!,
                              style: const TextStyle(
                                  color: AppTheme.primaryGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                  Row(children: [
                    const Icon(Icons.location_on,
                        color: AppTheme.primaryGold, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(offer.loc['d'] ?? '',
                          style: const TextStyle(
                              color: AppTheme.textGrey, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => context.push('/offer/${offer.id}'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryGold,
                            padding: EdgeInsets.zero),
                        child: const Text('التفاصيل ←',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      // FIX 7: المفضلة تعمل
                      GestureDetector(
                        onTap: _toggleFav,
                        child: Icon(
                          _isFav ? Icons.favorite : Icons.favorite_border,
                          color: _isFav ? Colors.red : AppTheme.textGrey,
                          size: 24,
                        ),
                      ),
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
