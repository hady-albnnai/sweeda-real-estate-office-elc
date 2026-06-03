import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';

class OffersReviewScreen extends StatelessWidget {
  const OffersReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مراجعة العروض الجديدة'),
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<List<OfferModel>>(
        future: adminProvider.getPendingOffers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('لا توجد عروض بانتظار المراجعة', style: TextStyle(color: AppTheme.textGrey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final offer = snapshot.data![index];
              return Card(
                color: AppTheme.surfaceBlack,
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  title: Text(offer.title, style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold)),
                  subtitle: Text('بواسطة: ${offer.uId}\nالسعر: ${offer.prc}', style: const TextStyle(color: AppTheme.textGrey)),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                        onPressed: () async {
                          bool success = await adminProvider.reviewOffer(offer.id, true);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول ونشر العرض')));
                            // Refresh page
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OffersReviewScreen()));
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                        onPressed: () async {
                          bool success = await adminProvider.reviewOffer(offer.id, false);
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض العرض')));
                            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OffersReviewScreen()));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
