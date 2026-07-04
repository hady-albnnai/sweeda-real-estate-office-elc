import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/offer_model.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../core/services/local_cache_service.dart';
import '../core/services/business_service.dart';
import '../providers/auth_provider.dart';
import '../providers/config_provider.dart';

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
    if (added && mounted) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        final config = context.read<ConfigProvider>().config;
        final awarded = await BusinessService().registerEventPoints(
          auth.userModel!.uid,
          'like',
          config,
          fallback: 10,
        );
        if (awarded && mounted) {
          auth.refreshUser();
          AppUtils.showPointsAwarded(context, 10, label: 'نقطة إعجاب');
        }
      }
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

  Widget _buildSpecItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primaryGold.withOpacity(0.7), size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final priceLabel = AppUtils.formatPrice(offer.prc, currency: offer.cur);
    final isProperty = offer.typ == 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: AppTheme.primaryGold.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8))
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/offer/${offer.id}'),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // 🖼️ الصورة الرئيسية مع Gradient خفيف
                Hero(
                  tag: 'off_${offer.id}',
                  child: Container(
                    height: 220,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      color: AppTheme.surfaceBlack,
                      image: offer.imgs.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(offer.imgs[0]),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                      child: offer.imgs.isEmpty
                          ? Center(
                              child: Icon(Icons.apartment_outlined,
                                  color: AppTheme.primaryGold.withOpacity(0.2),
                                  size: 64),
                            )
                          : null,
                    ),
                  ),
                ),

                // 🏷️ شارات الحالة (للبيع / للإيجار)
                Positioned(
                  top: 15,
                  right: 15,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: offer.trx == 0 ? Colors.green : Colors.blue,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      offer.trx == 0 ? 'للبيع' : 'للإيجار',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),

                // 🏷️ شارات الترقية (spd)
                Positioned(
                  top: 15,
                  left: 15,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      if (offer.iPin == 1) _boostBadge('📌 مثبت', Colors.orange),
                      if (offer.iFms == 1) _boostBadge('⭐ مميز', AppTheme.primaryGold),
                    ],
                  ),
                ),

                // 💰 السعر (بتصميم عصري أسفل الصورة)
                Positioned(
                  bottom: 12,
                  right: 15,
                  child: Text(
                    priceLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                ),

                // ⏱️ الوقت (منذ متى أضيف)
                Positioned(
                  bottom: 12,
                  left: 15,
                  child: Text(
                    AppUtils.formatTimestamp(offer.tsCrt.toIso8601String()),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🏠 العنوان + رقم العرض
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.ttl,
                          style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (offer.offerNumber != null)
                        Text(
                          '#${offer.offerNumber}',
                          style: TextStyle(
                              color: AppTheme.primaryGold.withOpacity(0.6),
                              fontSize: 12,
                              fontFamily: 'monospace'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 📊 المواصفات السريعة (أيقونات)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildSpecItem(Icons.location_on_outlined, offer.loc['city'] ?? 'السويداء'),
                        const SizedBox(width: 15),
                        if (isProperty) ...[
                          if (offer.specs['area'] != null)
                            _buildSpecItem(Icons.straighten, '${offer.specs['area']} م²'),
                          if (offer.specs['rooms'] != null) ...[
                            const SizedBox(width: 15),
                            _buildSpecItem(Icons.bed_outlined, '${offer.specs['rooms']} غرف'),
                          ],
                        ] else ...[
                          if (offer.specs['brand'] != null)
                            _buildSpecItem(Icons.directions_car_outlined, '${offer.specs['brand']}'),
                          if (offer.specs['year'] != null) ...[
                            const SizedBox(width: 15),
                            _buildSpecItem(Icons.calendar_today_outlined, '${offer.specs['year']}'),
                          ],
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),

                  // 🛡️ هوية المكتب (التصميم الاحترافي)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon((offer.ownerLabel ?? '').contains('✓') ? Icons.verified_rounded : Icons.storefront_outlined,
                                color: (offer.ownerLabel ?? '').contains('✓') ? Colors.green : AppTheme.primaryGold, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              offer.ownerLabel ?? 'إدارة المكتب العقاري',
                              style: const TextStyle(
                                  color: AppTheme.primaryGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      
                      // زر المفضلة
                      GestureDetector(
                        onTap: _toggleFav,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _isFav ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isFav ? Icons.favorite : Icons.favorite_border,
                            color: _isFav ? Colors.red : AppTheme.textGrey,
                            size: 20,
                          ),
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
