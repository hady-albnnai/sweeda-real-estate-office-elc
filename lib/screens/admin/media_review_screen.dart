import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/offer_model.dart';
import '../../providers/admin_provider.dart';

/// إدارة وسائط العروض — بديل متوافق مع نموذج المشروع الحالي لفكرة إدارة التصوير.
/// لا ينشئ جدول تصوير جديد، بل يراجع حالة الصور/الفيديو/السند ضمن offers.
class MediaReviewScreen extends StatefulWidget {
  const MediaReviewScreen({super.key});

  @override
  State<MediaReviewScreen> createState() => _MediaReviewScreenState();
}

class _MediaReviewScreenState extends State<MediaReviewScreen> {
  List<OfferModel> _offers = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final offers = await context.read<AdminProvider>().getOffersForMediaReview();
    if (!mounted) return;
    setState(() {
      _offers = offers;
      _loading = false;
    });
  }

  List<OfferModel> get _filtered {
    switch (_filter) {
      case 'missing_images':
        return _offers.where((offer) => offer.imgs.isEmpty).toList();
      case 'missing_doc':
        return _offers.where((offer) => offer.docImg.isEmpty).toList();
      case 'with_video':
        return _offers.where((offer) => offer.vdo.isNotEmpty).toList();
      case 'published':
        return _offers.where((offer) => offer.iPub == 1).toList();
      case 'pending':
        return _offers.where((offer) => offer.sts == 0).toList();
      default:
        return _offers;
    }
  }

  int get _missingImages => _offers.where((offer) => offer.imgs.isEmpty).length;
  int get _missingDocs => _offers.where((offer) => offer.docImg.isEmpty).length;
  int get _withVideo => _offers.where((offer) => offer.vdo.isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        title: const Text('إدارة الوسائط والتصوير'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _summaryCard(),
                  const SizedBox(height: 14),
                  _filters(),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text('لا توجد عروض مطابقة', style: TextStyle(color: AppTheme.textGrey)),
                      ),
                    )
                  else
                    ..._filtered.map(_offerTile),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library_outlined, color: AppTheme.primaryGold),
              SizedBox(width: 8),
              Text('ملخص الوسائط', style: TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat('العروض', _offers.length, AppTheme.primaryGold)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('بلا صور', _missingImages, Colors.orange)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('بلا سند', _missingDocs, AppTheme.errorRed)),
              const SizedBox(width: 8),
              Expanded(child: _miniStat('فيديو', _withVideo, Colors.blue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textGrey, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _filters() {
    final filters = <(String, String)>[
      ('الكل', 'all'),
      ('قيد المراجعة', 'pending'),
      ('منشور', 'published'),
      ('بلا صور', 'missing_images'),
      ('بلا سند', 'missing_doc'),
      ('مع فيديو', 'with_video'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter.$2;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(filter.$1),
              selected: selected,
              selectedColor: AppTheme.primaryGold,
              backgroundColor: AppTheme.surfaceBlack,
              labelStyle: TextStyle(color: selected ? AppTheme.deepBlack : AppTheme.textWhite),
              side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.25)),
              onSelected: (_) => setState(() => _filter = filter.$2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _offerTile(OfferModel offer) {
    final hasImages = offer.imgs.isNotEmpty;
    final hasDoc = offer.docImg.isNotEmpty;
    final hasVideo = offer.vdo.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.14)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 58,
            height: 58,
            child: hasImages
                ? Image.network(
                    offer.imgs.first,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  )
                : _placeholder(),
          ),
        ),
        title: Text(
          offer.ttl.isEmpty ? 'عرض بدون عنوان' : offer.ttl,
          style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _badge('${offer.imgs.length} صور', hasImages ? Colors.green : Colors.orange),
              _badge(hasDoc ? 'سند موجود' : 'بلا سند', hasDoc ? Colors.green : AppTheme.errorRed),
              if (hasVideo) _badge('فيديو', Colors.blue),
              _badge(_statusLabel(offer.sts), AppTheme.primaryGold),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_left, color: AppTheme.primaryGold),
        onTap: () => context.push('/offer/${offer.id}'),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: AppTheme.deepBlack,
      child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.textGrey),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  String _statusLabel(int status) {
    switch (status) {
      case 0:
        return 'قيد المراجعة';
      case 1:
        return 'مقبول';
      case 2:
        return 'منشور';
      case 3:
        return 'مرفوض';
      case 4:
        return 'منتهي';
      case 5:
        return 'محجوز';
      case 6:
        return 'مكتمل';
      default:
        return 'غير معروف';
    }
  }
}
