import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';

class OffersReviewScreen extends StatelessWidget {
  const OffersReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final admin = Provider.of<AdminProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('مراجعة العروض الجديدة'), backgroundColor: Colors.transparent),
      body: FutureBuilder<List<OfferModel>>(
        future: admin.getPendingOffers(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
          if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text('لا توجد عروض بانتظار المراجعة', style: TextStyle(color: AppTheme.textGrey)));
          return ListView.builder(
            padding: const EdgeInsets.all(15), itemCount: snap.data!.length,
            itemBuilder: (context, i) {
              final o = snap.data![i];
              return Card(color: AppTheme.surfaceBlack, margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(contentPadding: const EdgeInsets.all(15),
                  title: Text(o.ttl, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                  subtitle: Text('بواسطة: ${o.usrId}\nالسعر: ${o.prc}', style: const TextStyle(color: AppTheme.textGrey)),
                  isThreeLine: true,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                      onPressed: () async {
                        if (await admin.reviewOffer(o.id, true)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول ونشر العرض')));
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OffersReviewScreen()));
                        }
                      }),
                    const SizedBox(width: 10),
                    IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                      onPressed: () async {
                        if (await admin.reviewOffer(o.id, false)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض العرض')));
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OffersReviewScreen()));
                        }
                      }),
                  ]),
                ));
            },
          );
        },
      ),
    );
  }
}
