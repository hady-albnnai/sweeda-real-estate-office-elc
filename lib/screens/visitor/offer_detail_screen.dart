import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/offer_model.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/business_service.dart';
import '../../core/services/local_cache_service.dart';
import '../../widgets/book_appointment_sheet.dart';

class OfferDetailScreen extends StatefulWidget {
  final String offerId;
  const OfferDetailScreen({super.key, required this.offerId});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  OfferModel? _offer;
  bool _loading = true;
  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _isFav = LocalCacheService().isFavorite(widget.offerId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<OfferProvider>();
    // محاولة من الذاكرة أولاً ثم جلب من السيرفر
    var offer = provider.getOfferById(widget.offerId);
    offer ??= await provider.fetchOfferById(widget.offerId);
    if (offer != null) {
      provider.incrementViews(widget.offerId);
    }
    if (mounted) {
      setState(() {
        _offer = offer;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFav() async {
    final added = await LocalCacheService().toggleFavorite(widget.offerId);
    setState(() => _isFav = added);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added ? 'أُضيف للمفضلة ❤️' : 'أُزيل من المفضلة'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _share() async {
    if (_offer == null) return;
    final config = context.read<ConfigProvider>().config;
    final text = BusinessService().generateSocialPost(_offer!, config: config);
    await Share.share(text, subject: _offer!.ttl);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }
    final offer = _offer;
    if (offer == null) {
      return const Scaffold(
        backgroundColor: AppTheme.deepBlack,
        body: Center(
            child: Text('العرض غير موجود',
                style: TextStyle(color: AppTheme.textGrey))),
      );
    }

    final auth = context.watch<AuthProvider>();
    final isOwner = auth.userModel?.uid == offer.usrId;

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                offer.imgs.isNotEmpty
                    ? Image.network(offer.imgs[0],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: AppTheme.surfaceBlack,
                            child: const Icon(Icons.image,
                                size: 80, color: AppTheme.textGrey)))
                    : Container(
                        color: AppTheme.surfaceBlack,
                        child: const Icon(Icons.home_work,
                            size: 80, color: AppTheme.textGrey)),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppTheme.deepBlack]))),
              ]),
            ),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: _share,
              ),
              IconButton(
                icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                    color: _isFav ? AppTheme.errorRed : null),
                onPressed: _toggleFav,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: AppTheme.deepBlack,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(offer.ttl,
                              style: const TextStyle(
                                  color: AppTheme.textWhite,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '${offer.prc.toStringAsFixed(0)} ${offer.cur == 0 ? '\$' : 'ل.س'}',
                            style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.location_on,
                        color: AppTheme.primaryGold, size: 20),
                    const SizedBox(width: 5),
                    Text(offer.loc['d'] ?? '',
                        style: const TextStyle(
                            color: AppTheme.textGrey, fontSize: 16)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('الوصف التفصيلي',
                      style: TextStyle(
                          color: AppTheme.primaryGold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(offer.descript.isEmpty ? 'لا يوجد وصف' : offer.descript,
                      style: const TextStyle(
                          color: AppTheme.textWhite, fontSize: 16, height: 1.5)),
                  const SizedBox(height: 20),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 3,
                    children: [
                      _spec(Icons.category, 'النوع',
                          offer.typ == 0 ? 'عقار' : 'سيارة'),
                      _spec(Icons.swap_horiz, 'المعاملة',
                          offer.trx == 0 ? 'بيع' : 'إيجار'),
                      _spec(Icons.visibility, 'المشاهدات', '${offer.vws}'),
                      _spec(Icons.favorite, 'الإعجابات', '${offer.fvs}'),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // زر مشاركة على السوشال (للمالك خصوصاً)
                  if (isOwner)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _shareAndMark,
                        icon: const Icon(Icons.campaign,
                            color: AppTheme.primaryGold),
                        label: const Text('نشر على وسائل التواصل',
                            style: TextStyle(color: AppTheme.primaryGold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryGold),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  if (isOwner) const SizedBox(height: 14),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              BookAppointmentSheet(offer: offer)),
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

  Future<void> _shareAndMark() async {
    if (_offer == null) return;
    final config = context.read<ConfigProvider>().config;
    final text = BusinessService().generateSocialPost(_offer!, config: config);
    await Share.share(text, subject: _offer!.ttl);
    await BusinessService().markSocialPublished(_offer!.id, text);
    // منح نقاط النشر على السوشال (pts.soc)
    final auth = context.read<AuthProvider>();
    if (auth.userModel != null) {
      await BusinessService()
          .awardEvent(auth.userModel!.uid, config, 'soc', fallback: 100);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تجهيز المنشور ✅ (+نقاط)')));
    }
  }

  Widget _spec(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, color: AppTheme.primaryGold, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text('$label: $value',
                style: const TextStyle(color: AppTheme.textWhite, fontSize: 14),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
