import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/broker_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';

/// 🏠 عروض الوسيط — العروض الخاصة به + المُسندة إليه
class BrokerOffersScreen extends StatefulWidget {
  const BrokerOffersScreen({super.key});

  @override
  State<BrokerOffersScreen> createState() => _BrokerOffersScreenState();
}

class _BrokerOffersScreenState extends State<BrokerOffersScreen> {
  int _filter = 0; // 0=الكل, 1=منشور, 2=قيد المراجعة

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final id = context.read<AuthProvider>().userModel?.uid ?? '';
    if (id.isNotEmpty) context.read<BrokerProvider>().fetchBrokerOffers(id);
  }

  List<OfferModel> _apply(List<OfferModel> offers) {
    switch (_filter) {
      case 1:
        return offers.where((o) => o.sts == 2).toList();
      case 2:
        return offers.where((o) => o.sts == 1).toList();
      default:
        return offers;
    }
  }

  @override
  Widget build(BuildContext context) {
    final broker = context.watch<BrokerProvider>();
    final offers = _apply(broker.offers);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text('عروضي'),
        backgroundColor: AppTheme.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // فلاتر الحالة
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                _chip('الكل', 0),
                const SizedBox(width: 8),
                _chip('منشور', 1),
                const SizedBox(width: 8),
                _chip('قيد المراجعة', 2),
              ],
            ),
          ),
          Expanded(
            child: broker.isLoading && broker.offers.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGold))
                : offers.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        color: AppTheme.primaryGold,
                        onRefresh: () async => _load(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: offers.length,
                          itemBuilder: (_, i) => _offerTile(offers[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_work,
                size: 72, color: AppTheme.textGrey.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('لا توجد عروض مرتبطة بك',
                style: TextStyle(color: AppTheme.textGrey, fontSize: 15)),
          ],
        ),
      );

  Widget _chip(String label, int value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label,
          style: TextStyle(
            color: selected ? AppTheme.deepBlack : AppTheme.textWhite,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          )),
      selected: selected,
      selectedColor: AppTheme.primaryGold,
      backgroundColor: AppTheme.surfaceBlack,
      checkmarkColor: AppTheme.deepBlack,
      side: BorderSide(color: AppTheme.primaryGold.withOpacity(0.3)),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _offerTile(OfferModel o) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: o.imgs.isNotEmpty
              ? Image.network(o.imgs[0],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder())
              : _imgPlaceholder(),
        ),
        title: Text(o.ttl,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${o.prc.toStringAsFixed(0)} ${o.cur == 0 ? '\$' : 'ل.س'}',
                style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                _statusBadge(o.sts),
                const SizedBox(width: 8),
                Icon(Icons.visibility,
                    size: 13, color: AppTheme.textGrey.withOpacity(0.7)),
                const SizedBox(width: 2),
                Text('${o.vws}',
                    style: TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
                const SizedBox(width: 8),
                Icon(Icons.favorite,
                    size: 13, color: AppTheme.textGrey.withOpacity(0.7)),
                const SizedBox(width: 2),
                Text('${o.fvs}',
                    style: TextStyle(
                        color: AppTheme.textGrey, fontSize: 11)),
              ],
            ),
          ],
        ),
        onTap: () => context.push('/offer/${o.id}'),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 60,
        height: 60,
        color: AppTheme.deepBlack,
        child: Icon(Icons.image, color: AppTheme.textGrey),
      );

  Widget _statusBadge(int sts) {
    late String label;
    late Color color;
    switch (sts) {
      case 0:
        label = 'مسودة';
        color = AppTheme.textGrey;
        break;
      case 1:
        label = 'قيد المراجعة';
        color = Colors.orange;
        break;
      case 2:
        label = 'منشور';
        color = Colors.green;
        break;
      case 3:
        label = 'مرفوض';
        color = AppTheme.errorRed;
        break;
      case 4:
        label = 'منتهٍ';
        color = AppTheme.textGrey;
        break;
      case 5:
        label = 'محجوز';
        color = Colors.blueAccent;
        break;
      case 6:
        label = 'مكتمل';
        color = AppTheme.primaryGold;
        break;
      default:
        label = '—';
        color = AppTheme.textGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10)),
    );
  }
}
