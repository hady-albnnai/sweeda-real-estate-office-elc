import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/offer_model.dart';
import '../../core/theme/app_theme.dart';

class BookAppointmentSheet extends StatelessWidget {
  final OfferModel offer;

  const BookAppointmentSheet({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.primaryGold,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'حجز موعد معاينة',
            style: TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'اختر يوماً ووقتاً مناسباً من المواعيد المتاحة',
            style: TextStyle(color: AppTheme.textGrey, fontSize: 14),
          ),
          const SizedBox(height: 20),
          // Availability Grid
          offer.avl.isEmpty
              ? const Center(child: Text('لا توجد مواعيد متاحة حالياً', style: TextStyle(color: AppTheme.textGrey)))
              : _buildAvailabilityGrid(context, appointmentProvider, authProvider),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildAvailabilityGrid(BuildContext context, AppointmentProvider provider, AuthProvider auth) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: offer.avl.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getDayName(entry.key),
              style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: entry.value.map((time) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.surfaceBlack,
                    foregroundColor: AppTheme.primaryGold,
                    side: const BorderSide(color: AppTheme.primaryGold),
                  ),
                  onPressed: () async {
                    bool success = await provider.bookAppointment(
                      uId: auth.currentUser?.uid ?? '',
                      oId: offer.id,
                      day: entry.key,
                      time: time,
                    );
                    if (success) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم طلب الموعد بنجاح، بانتظار موافقة المالك')),
                      );
                    }
                  },
                  child: Text(time),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        );
      }).toList(),
    );
  }

  String _getDayName(String day) {
    final days = {
      'mon': 'الاثنين',
      'tue': 'الثلاثاء',
      'wed': 'الأربعاء',
      'thu': 'الخميس',
      'fri': 'الجمعة',
      'sat': 'السبت',
      'sun': 'الأحد',
    };
    return days[day] ?? day;
  }
}
