import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';

/// شاشة عروضي — تعرض كل عروض المستخدم مع فلترة بالحالة
/// + إمكانية التعديل/الترقية/مشاهدة التفاصيل.
class MyOffersScreen extends StatefulWidget {
  const MyOffersScreen({super.key});

  @override
  State<MyOffersScreen> createState() => _MyOffersScreenState();
}

class _MyOffersScreenState extends State<MyOffersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<OfferModel> _myOffers = [];
  bool _loading = true;

  final List<_FilterTab> _filters = const [
    _FilterTab('الكل', -1),
    _FilterTab('قيد المراجعة', 1),
    _FilterTab('منشور', 2),
    _FilterTab('مرفوض', 3),
    _FilterTab('منتهي', 4),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _filters.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final uid = context.read<AuthProvider>().userModel?.uid;
    if (uid == null || uid.isEmpty) return;
    setState(() => _loading = true);
    final offers = await context.read<OfferProvider>().fetchUserOffers(uid);
    if (!mounted) return;
    setState(() {
      _myOffers = offers;
      _loading = false;
    });
  }

  List<OfferModel> _filterOffers(List<OfferModel> offers, int status) {
    if (status == -1) return offers;
    return offers.where((o) => o.sts == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        title: const Text('عروضي'),
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: AppTheme.primaryGold,
          labelColor: AppTheme.primaryGold,
          unselectedLabelColor: AppTheme.textGrey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: _filters
              .map((f) => Tab(
                    text:
                        '${f.label} (${_filterOffers(_myOffers, f.status).length})',
                  ))
              .toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('عرض جديد'),
        onPressed: () async {
          await context.push('/user/add-offer');
          if (mounted) _refresh();
        },
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGold),
            )
          : RefreshIndicator(
              color: AppTheme.primaryGold,
              onRefresh: _refresh,
              child: TabBarView(
                controller: _tab,
                children: _filters
                    .map((f) => _offersList(_filterOffers(_myOffers, f.status)))
                    .toList(),
              ),
            ),
    );
  }

  Widget _offersList(List<OfferModel> offers) {
    if (offers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open,
                size: 80, color: AppTheme.primaryGold.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            const Text('لا توجد عروض في هذه الحالة',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await context.push('/user/add-offer');
                if (mounted) _refresh();
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text('أضف عرضك الأول'),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: offers.length,
      itemBuilder: (context, i) => _offerCard(offers[i]),
    );
  }

  Widget _offerCard(OfferModel o) {
    final status = _statusInfo(o.sts);
    final hasImage = o.imgs.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: status.$2.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/offer/${o.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status.$2.withValues(alpha: 0.15),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(
                children: [
                  Icon(status.$3, color: status.$2, size: 16),
                  const SizedBox(width: 6),
                  Text(status.$1,
                      style: TextStyle(
                          color: status.$2,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  const Spacer(),
                  if (o.sts == 3 && o.rsn.isNotEmpty)
                    Tooltip(
                      message: 'سبب الرفض: ${o.rsn}',
                      child: const Icon(Icons.info_outline,
                          color: Colors.red, size: 16),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: hasImage
                          ? Image.network(o.imgs.first.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPlaceholder())
                          : _imgPlaceholder(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.ttl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatPrice(o.prc)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                          style: const TextStyle(
                              color: AppTheme.primaryGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.remove_red_eye,
                                color: AppTheme.textGrey, size: 13),
                            const SizedBox(width: 3),
                            Text('${o.vws}',
                                style: const TextStyle(
                                    color: AppTheme.textGrey, fontSize: 11)),
                            const SizedBox(width: 10),
                            const Icon(Icons.favorite,
                                color: AppTheme.textGrey, size: 13),
                            const SizedBox(width: 3),
                            Text('${o.fvs}',
                                style: const TextStyle(
                                    color: AppTheme.textGrey, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppTheme.deepBlack, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _actionBtn(
                      icon: Icons.edit,
                      label: 'تعديل',
                      color: AppTheme.primaryGold,
                      onTap: () async {
                        final changed = await context.push('/user/edit-offer/${o.id}');
                        if (changed == true && mounted) _refresh();
                      },
                    ),
                  ),
                  Container(width: 1, height: 30, color: AppTheme.deepBlack),
                  Expanded(
                    child: _actionBtn(
                      icon: Icons.rocket_launch,
                      label: 'ترقية',
                      color: Colors.purple,
                      onTap: () async {
                        final result = await context.push('/user/boost-offer/${o.id}');
                        if (result == true && mounted) _refresh();
                      },
                    ),
                  ),
                  Container(width: 1, height: 30, color: AppTheme.deepBlack),
                  Expanded(
                    child: _actionBtn(
                      icon: Icons.visibility,
                      label: 'عرض',
                      color: AppTheme.textWhite,
                      onTap: () => context.push('/offer/${o.id}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: AppTheme.deepBlack,
        child: const Icon(Icons.image_not_supported,
            color: AppTheme.textGrey, size: 30),
      );

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(0);
  }

  (String, Color, IconData) _statusInfo(int s) {
    switch (s) {
      case 0:
        return ('مسودة', Colors.grey, Icons.edit_note);
      case 1:
        return ('قيد المراجعة', Colors.orange, Icons.hourglass_empty);
      case 2:
        return ('منشور', Colors.green, Icons.check_circle);
      case 3:
        return ('مرفوض', Colors.red, Icons.cancel);
      case 4:
        return ('منتهي', Colors.grey, Icons.timer_off);
      case 5:
        return ('محجوز', Colors.blue, Icons.lock_clock);
      case 6:
        return ('مكتمل', Colors.teal, Icons.done_all);
      default:
        return ('غير معروف', Colors.grey, Icons.help);
    }
  }
}

class _FilterTab {
  final String label;
  final int status;
  const _FilterTab(this.label, this.status);
}
