import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../models/offer_model.dart';
import '../../models/user_model.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../core/services/business_service.dart';
import '../../core/services/local_cache_service.dart';
import '../../core/network/supabase_service.dart';
import '../../core/constants/db_constants.dart';
import '../../widgets/book_appointment_sheet.dart';
import '../../widgets/video_player_widget.dart';
import '../../widgets/location_picker.dart';
import '../../widgets/rating_dialog.dart';

import '../../providers/admin_provider.dart';

class OfferDetailScreen extends StatefulWidget {
  final String offerId;
  const OfferDetailScreen({super.key, required this.offerId});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  OfferModel? _offer;
  UserModel? _owner;
  double? _ownerAvgRating;
  int _ownerRatingCount = 0;
  bool _loading = true;
  bool _isFav = false;
  int _currentImg = 0;
  late final PageController _pageCtrl = PageController();

  @override
  void initState() {
    super.initState();
    _isFav = LocalCacheService().isFavorite(widget.offerId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<OfferProvider>();
    final userId = context.read<AuthProvider>().userModel?.uid;
    // محاولة من الذاكرة أولاً ثم جلب من السيرفر
    var offer = provider.getOfferById(widget.offerId);
    offer ??= await provider.fetchOfferById(widget.offerId, userId: userId);
    if (offer != null) {
      provider.incrementViews(widget.offerId);

      // جلب بيانات المالك لتوليد التسمية المهنية (لا يُعرض اسمه أبداً)
      try {
        final row = await SupabaseService()
            .client
            .from(DbTables.usersPublic)
            .select()
            .eq('id', offer.usrId)
            .maybeSingle();
        if (row != null) {
          _owner = UserModel.fromSupabase(
            Map<String, dynamic>.from(row),
            row['id'] as String,
          );
        }
      } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }

      // ⭐ جلب متوسط تقييم المالك (LOGIC_SPEC §3.3)
      try {
        final ratings = await SupabaseService()
            .client
            .from('ratings')
            .select('stars')
            .eq('target_uid', offer.usrId);
        final list = (ratings as List);
        if (list.isNotEmpty) {
          double sum = 0;
          for (final r in list) {
            sum += ((r['stars'] as num?) ?? 0).toDouble();
          }
          _ownerRatingCount = list.length;
          _ownerAvgRating = sum / list.length;
        }
      } catch (e) {
      // تم تجاهل الخطأ عمداً للحفاظ على التدفق الحالي.
    }
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
    await SharePlus.instance.share(
      ShareParams(text: text, subject: _offer!.ttl),
    );
  }

  void _showAdminPrioritySheet(BuildContext context, OfferModel offer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceBlack,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'تحديد أولوية النشر (للإدارة فقط)',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اختر مستوى الأولوية الذي سيظهر فيه العرض للمستخدمين. (لمدة 30 يوم)',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _priorityOption(ctx, offer.id, 'pin', 'مثبّت في الأعلى (أعلى أولوية)', Icons.push_pin, Colors.redAccent),
              _priorityOption(ctx, offer.id, 'fms', 'مميّز (ثاني أولوية)', Icons.star, Colors.orangeAccent),
              _priorityOption(ctx, offer.id, 'bst', 'مُرقّى (ثالث أولوية)', Icons.rocket_launch, Colors.blueAccent),
              _priorityOption(ctx, offer.id, 'normal', 'عادي (ترتيب حسب التاريخ)', Icons.format_list_bulleted, Colors.grey),
            ],
          ),
        );
      },
    );
  }

  Widget _priorityOption(BuildContext ctx, String offerId, String type, String label, IconData icon, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.w600)),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final adminProv = context.read<AdminProvider>();
        final authProv = context.read<AuthProvider>();

        Navigator.pop(ctx);
        // نعطي الـ bottom sheet وقتاً ليُغلق حتى لا تضيع الـ SnackBar خلفه/أثناء الإغلاق.
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;

        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('جاري تحديث أولوية العرض...'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );

        final ok = await adminProv.setOfferPriority(
          authProv.userModel!.uid,
          offerId,
          type,
        );

        if (mounted) {
          messenger.hideCurrentSnackBar();
          if (ok) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('تم تحديث أولوية العرض بنجاح'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            // Refresh to see updated state
            _load();
          } else {
            messenger.showSnackBar(
              SnackBar(
                content: Text('فشل التحديث: ${adminProv.error ?? "حدث خطأ"}'),
                backgroundColor: AppTheme.errorRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
    );
  }

  void _showAdminDeleteDialog(BuildContext context, OfferModel offer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
          SizedBox(width: 8),
          Text('حذف العرض (إدارة)', style: TextStyle(color: AppTheme.textWhite)),
        ]),
        content: const Text(
          'هل أنت متأكد من رغبتك في حذف هذا العرض؟ سيتم نقله إلى الأرشيف ولن يظهر للمستخدمين بعد الآن.',
          style: TextStyle(color: AppTheme.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final adminProv = context.read<AdminProvider>();
              final authProv = context.read<AuthProvider>();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري الحذف...')),
              );
              
              final ok = await adminProv.deleteOfferByAdmin(
                authProv.userModel!.uid,
                offer.id,
              );
              
              if (mounted) {
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف العرض بنجاح')),
                  );
                  Navigator.pop(context); // الرجوع للشاشة السابقة بعد الحذف
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('فشل الحذف: ${adminProv.error ?? "حدث خطأ"}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _reportOffer() async {
    if (_offer == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يجب تسجيل الدخول لتبليغ عن عرض'),
          action: SnackBarAction(
            label: 'دخول',
            onPressed: () => context.push('/login'),
          ),
        ),
      );
      return;
    }

    final config = context.read<ConfigProvider>().config;
    final reasons = (config?.reportReasons ?? const [
      'إعلان وهمي / غير موجود',
      'احتيال / نصب',
      'معلومات مضللة',
      'مضايقة / سلوك غير لائق',
      'عرض مكرر',
      'آخر',
    ]).cast<String>();

    String? selected;
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.surfaceBlack,
          title: const Row(children: [
            Icon(Icons.flag, color: Colors.red),
            SizedBox(width: 8),
            Text('تبليغ عن العرض',
                style: TextStyle(color: AppTheme.textWhite)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('اختر سبب التبليغ:',
                    style: TextStyle(color: AppTheme.textGrey, fontSize: 12)),
                const SizedBox(height: 6),
                RadioGroup<String>(
                  groupValue: selected,
                  onChanged: (value) => setS(() => selected = value),
                  child: Column(
                    children: reasons.map((r) => RadioListTile<String>(
                          value: r,
                          title: Text(r,
                              style:
                                  const TextStyle(color: AppTheme.textWhite)),
                          activeColor: AppTheme.primaryGold,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  style: const TextStyle(color: AppTheme.textWhite),
                  decoration: const InputDecoration(
                    hintText: 'تفاصيل إضافية (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: AppTheme.textGrey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (selected == null) return;
                Navigator.pop(ctx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('إرسال التبليغ',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != true || selected == null || !mounted) return;

    try {
      final rsnIndex = reasons.indexOf(selected!);
      final response = await SupabaseService().client.functions.invoke(
        'user-account',
        body: {
          'action': 'create_report',
          'user_uid': auth.userModel!.uid,
          'report': {
            'tgt_uid': _offer!.usrId,
            'tgt_tp': 1,
            'tgt_id': _offer!.id,
            'rsn': rsnIndex < 0 ? 0 : rsnIndex,
            'det': notesCtrl.text.trim(),
          },
        },
      );
      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? 'Report failed');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم إرسال التبليغ، شكراً لمساعدتنا'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فشل إرسال التبليغ، حاول مرة أخرى')),
      );
    }
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
                // الصور — عرض ثابت (بدون PageView) + ضغط يفتح العارض الكامل
                offer.imgs.isEmpty
                    ? Container(
                        color: AppTheme.surfaceBlack,
                        child: const Icon(Icons.home_work,
                            size: 80, color: AppTheme.textGrey))
                    : GestureDetector(
                        onTap: () => _openImageViewer(offer.imgs, _currentImg),
                        child: Image.network(
                          offer.imgs[_currentImg],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppTheme.surfaceBlack,
                              child: const Icon(Icons.image,
                                  size: 80, color: AppTheme.textGrey)),
                        ),
                      ),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppTheme.deepBlack]))),
                // مؤشر الصور (dots قابلة للضغط)
                if (offer.imgs.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0, right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(offer.imgs.length, (i) => GestureDetector(
                        onTap: () => setState(() => _currentImg = i),
                        child: Container(
                          width: _currentImg == i ? 18 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: _currentImg == i
                                ? AppTheme.primaryGold
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )),
                    ),
                  ),
                // أسهم التنقل + زر فتح الصورة
                if (offer.imgs.length > 1) ...[
                  Positioned(
                    left: 8, top: 0, bottom: 0,
                    child: Center(child: GestureDetector(
                      onTap: () { if (_currentImg > 0) setState(() => _currentImg--); },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                      ),
                    )),
                  ),
                  Positioned(
                    right: 8, top: 0, bottom: 0,
                    child: Center(child: GestureDetector(
                      onTap: () { if (_currentImg < offer.imgs.length - 1) setState(() => _currentImg++); },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      ),
                    )),
                  ),
                ],
                // زر فتح الصورة بملء الشاشة
                if (offer.imgs.isNotEmpty)
                  Positioned(
                    bottom: 12, right: 16,
                    child: GestureDetector(
                      onTap: () => _openImageViewer(offer.imgs, _currentImg),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.fullscreen, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('عرض الصور', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ]),
                      ),
                    ),
                  ),
                // عداد الصور (1/3)
                if (offer.imgs.length > 1)
                  Positioned(
                    top: 12, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentImg + 1}/${offer.imgs.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ]),
            ),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context)),
            actions: [
              IconButton(
                icon: const Icon(Icons.flag_outlined),
                tooltip: 'تبليغ',
                onPressed: _reportOffer,
              ),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (offer.offerNumber != null)
                                Text('عرض رقم #${offer.offerNumber}',
                                    style: TextStyle(color: AppTheme.primaryGold.withValues(alpha: 0.7), fontSize: 12)),
                              if (isOwner || auth.isAdmin)
                                Container(
                                  margin: const EdgeInsets.only(top: 4, bottom: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: offer.daysUntilExpiration <= 3 ? AppTheme.errorRed.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: offer.daysUntilExpiration <= 3 ? AppTheme.errorRed.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer_outlined, size: 14, color: offer.daysUntilExpiration <= 3 ? AppTheme.errorRed : Colors.green),
                                      const SizedBox(width: 4),
                                      Text(
                                        offer.daysUntilExpiration == 0 ? 'ينتهي اليوم (بانتظار التجديد)' : 'ينتهي بعد ${offer.daysUntilExpiration} يوم',
                                        style: TextStyle(
                                          color: offer.daysUntilExpiration <= 3 ? AppTheme.errorRed : Colors.green,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(offer.ttl,
                                  style: const TextStyle(
                                      color: AppTheme.textWhite,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            AppUtils.formatPrice(offer.prc, currency: offer.cur),
                            style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                      ]),

                  // 🏢 هوية المكتب — تسمية مهنية بدل اسم المالك (LOGIC_SPEC §1)
                  // تظهر دائماً: إذا لم يُجلب المالك تظهر "منشور بواسطة المكتب" كـ fallback
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_center,
                            color: AppTheme.primaryGold, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _owner != null
                                ? BusinessService().getUserPublicLabel(_owner!)
                                : (_offer?.ownerLabel?.isNotEmpty == true
                                    ? _offer!.ownerLabel!
                                    : 'منشور بواسطة المكتب العقاري الالكتروني'),
                            style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ⭐ متوسط تقييم المالك (إن وُجد)
                  if (_ownerAvgRating != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.star,
                          color: AppTheme.primaryGold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${_ownerAvgRating!.toStringAsFixed(1)} ($_ownerRatingCount تقييم)',
                        style: const TextStyle(
                            color: AppTheme.textWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ]),
                  ],

                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.location_on,
                        color: AppTheme.primaryGold, size: 20),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((offer.loc['city'] ?? '').toString().isNotEmpty)
                            Text((offer.loc['city'] ?? '').toString(),
                                style: const TextStyle(
                                    color: AppTheme.primaryGold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          Text(offer.loc['d'] ?? '',
                              style: const TextStyle(
                                  color: AppTheme.textGrey, fontSize: 15)),
                        ],
                      ),
                    ),
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
                  // المواصفات التقنية
                  // المواصفات التفصيلية — حسب نوع العرض
                  if (offer.specs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(offer.typ == 1 ? 'مواصفات السيارة' : 'مواصفات العقار',
                        style: const TextStyle(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      if (offer.typ == 0) ...[
                        if ((offer.specs['area'] ?? '').toString().isNotEmpty) _spec(Icons.square_foot, 'المساحة', '${offer.specs['area']} م²'),
                        if ((offer.specs['floor'] ?? '').toString().isNotEmpty) _spec(Icons.layers, 'الطابق', offer.specs['floor'].toString()),
                        if ((offer.specs['finishing'] ?? '').toString().isNotEmpty) _spec(Icons.format_paint, 'الإكساء', offer.specs['finishing'].toString()),
                        if ((offer.specs['direction'] ?? '').toString().isNotEmpty) _spec(Icons.explore, 'الاتجاه', offer.specs['direction'].toString()),
                      ],
                      if (offer.typ == 1) ...[
                        if ((offer.specs['brand'] ?? '').toString().isNotEmpty) _spec(Icons.directions_car, 'الماركة', offer.specs['brand'].toString()),
                        if ((offer.specs['model'] ?? '').toString().isNotEmpty) _spec(Icons.car_repair, 'الموديل', offer.specs['model'].toString()),
                        if ((offer.specs['year'] ?? '').toString().isNotEmpty) _spec(Icons.calendar_today, 'سنة الصنع', offer.specs['year'].toString()),
                        if ((offer.specs['color'] ?? '').toString().isNotEmpty) _spec(Icons.palette, 'اللون', offer.specs['color'].toString()),
                        if ((offer.specs['km'] ?? '').toString().isNotEmpty) _spec(Icons.speed, 'الكيلومترات', '${offer.specs['km']} كم'),
                        if ((offer.specs['fuel'] ?? '').toString().isNotEmpty) _spec(Icons.local_gas_station, 'الوقود', offer.specs['fuel'].toString()),
                        if ((offer.specs['transmission'] ?? '').toString().isNotEmpty) _spec(Icons.settings, 'ناقل الحركة', offer.specs['transmission'].toString()),
                        if ((offer.specs['plate'] ?? '').toString().isNotEmpty) _spec(Icons.confirmation_number, 'اللوحة', offer.specs['plate'].toString()),
                      ],
                    ]),
                    if ((offer.specs['legal_notes'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _spec(Icons.gavel, 'ملاحظات قانونية', offer.specs['legal_notes'].toString()),
                    ],
                    if ((offer.specs['details'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(offer.specs['details'].toString(), style: const TextStyle(color: AppTheme.textWhite, fontSize: 14, height: 1.5)),
                    ],
                  ],
                  const SizedBox(height: 20),

                  // فيديو العرض (إذا موجود)
                  if (offer.vdo.isNotEmpty) ...[
                    const Row(children: [
                      Icon(Icons.play_circle, color: AppTheme.primaryGold),
                      SizedBox(width: 8),
                      Text('فيديو العرض',
                          style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    OfferVideoPlayer(videoUrl: offer.vdo),
                    const SizedBox(height: 20),
                  ],

                  // الموقع على الخريطة (إذا exact_loc موجود)
                  if (offer.exactLoc.contains(',')) ...[
                    const Row(children: [
                      Icon(Icons.map, color: AppTheme.primaryGold),
                      SizedBox(width: 8),
                      Text('الموقع على الخريطة',
                          style: TextStyle(
                              color: AppTheme.primaryGold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 10),
                    Builder(builder: (_) {
                      final parts = offer.exactLoc.split(',');
                      final lat = double.tryParse(parts[0].trim());
                      final lng = double.tryParse(parts[1].trim());
                      if (lat == null || lng == null) return const SizedBox();
                      return LocationViewer(lat: lat, lng: lng);
                    }),
                    const SizedBox(height: 20),
                  ],
                  
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
                  if (isOwner) const SizedBox(height: 10),

                  // 🚀 زر ترقية بالنقاط للمالك أو تعيين أولوية للإدارة
                  if (isOwner && !auth.isAdmin)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            context.push('/user/boost-offer/${offer.id}'),
                        icon: const Icon(Icons.rocket_launch,
                            color: AppTheme.deepBlack),
                        label: const Text('ترقية العرض بالنقاط 🚀',
                            style: TextStyle(
                                color: AppTheme.deepBlack,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  
                  // خيار أولوية النشر للإدارة + زر الحذف
                  if (auth.isAdmin) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showAdminPrioritySheet(context, offer),
                            icon: const Icon(Icons.admin_panel_settings,
                                color: AppTheme.textWhite),
                            label: const Text('أولوية (إدارة)',
                                style: TextStyle(
                                    color: AppTheme.textWhite,
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _showAdminDeleteDialog(context, offer),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorRed.withValues(alpha: 0.8),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          ),
                          child: const Icon(Icons.delete_forever, color: AppTheme.textWhite),
                        ),
                      ],
                    ),
                  ],

                  if (isOwner || auth.isAdmin) const SizedBox(height: 14),

                  // زر الحجز — مخفي عن المالك والإدارة
                  if (!isOwner && !auth.isAdmin)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: offer.avl.isEmpty
                          ? null // تعطيل إذا لا مواعيد
                          : () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) =>
                                  BookAppointmentSheet(offer: offer)),
                      style: offer.avl.isEmpty
                          ? ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceBlack,
                              disabledForegroundColor: AppTheme.textGrey,
                            )
                          : null,
                      child: Text(
                        offer.avl.isEmpty
                            ? 'لا توجد مواعيد متاحة حالياً'
                            : 'حجز موعد للمعاينة',
                      ),
                    ),
                  ),
                  // ⭐ تقييم المالك (لغير المالك والإدارة) — LOGIC_SPEC §3.3
                  if (auth.isLoggedIn && !isOwner && !auth.isAdmin) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => RatingDialog.show(
                          context: context,
                          targetUid: offer.usrId,
                          targetName: offer.ownerLabel ?? 'مالك العرض',
                          refLabel: 'تجربتك مع هذا العرض',
                        ),
                        icon: const Icon(Icons.star_border,
                            color: AppTheme.primaryGold),
                        label: const Text('تقييم تجربتك مع هذا العرض',
                            style: TextStyle(color: AppTheme.primaryGold)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.primaryGold),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
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
    final messenger = ScaffoldMessenger.of(context);
    final config = context.read<ConfigProvider>().config;
    final auth = context.read<AuthProvider>();
    final text = BusinessService().generateSocialPost(_offer!, config: config);
    final result = await SharePlus.instance.share(
      ShareParams(text: text, subject: _offer!.ttl),
    );

    // منح النقاط فقط إذا تمت المشاركة فعلياً
    if (result.status == ShareResultStatus.success) {
      await BusinessService().markSocialPublished(
        _offer!.id,
        text,
        userId: auth.userModel?.uid,
      );
      if (auth.userModel != null) {
        final pts = config?.socialSharePoints ?? 100;
        await BusinessService()
            .awardEvent(auth.userModel!.uid, config, 'soc', fallback: 100);
        if (mounted) {
          messenger.showSnackBar(
              SnackBar(content: Text('تم مشاركة العرض ✅ (+$pts نقطة)')));
        }
      }
    } else {
      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('لم تتم المشاركة')));
      }
    }
  }

  void _openImageViewer(List<String> images, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullScreenImageViewer(images: images, initialIndex: initialIndex),
    ));
  }

  Widget _spec(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.2))),
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

/// عارض صور بملء الشاشة — تصفح + زوم + إغلاق
class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_current + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              widget.images[i],
              fit: BoxFit.contain,
              width: double.infinity,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image, color: Colors.grey, size: 80),
            ),
          ),
        ),
      ),
    );
  }
}
