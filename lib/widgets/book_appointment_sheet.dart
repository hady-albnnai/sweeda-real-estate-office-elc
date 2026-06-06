import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/auth_provider.dart';
import '../models/offer_model.dart';
import '../core/theme/app_theme.dart';

class BookAppointmentSheet extends StatefulWidget {
  final OfferModel offer;
  const BookAppointmentSheet({super.key, required this.offer});

  @override
  State<BookAppointmentSheet> createState() => _BookAppointmentSheetState();
}

class _BookAppointmentSheetState extends State<BookAppointmentSheet> {
  @override
  Widget build(BuildContext context) {
    final apptProvider = Provider.of<AppointmentProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: AppTheme.deepBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: AppTheme.primaryGold, borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          const Text('حجز موعد معاينة', style: TextStyle(color: AppTheme.textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('اختر يوماً ووقتاً مناسباً من المواعيد المتاحة', style: TextStyle(color: AppTheme.textGrey, fontSize: 14)),
          const SizedBox(height: 20),
          widget.offer.avl.isEmpty
              ? const Center(child: Text('لا توجد مواعيد متاحة حالياً', style: TextStyle(color: AppTheme.textGrey)))
              : _buildGrid(context, apptProvider, authProvider),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, AppointmentProvider provider, AuthProvider auth) {
    return ListView(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      children: widget.offer.avl.entries.map((entry) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_dayName(entry.key), style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Wrap(spacing: 10,
            children: entry.value.map((time) => ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceBlack, foregroundColor: AppTheme.primaryGold, side: const BorderSide(color: AppTheme.primaryGold)),
              onPressed: () async {
                bool s = await provider.bookAppointment(userId: auth.userModel?.uid ?? '', offerId: widget.offer.id, ownerId: widget.offer.usrId);
                if (!mounted) return; // الحل هنا: التأكد من أن الوجت لا يزال موجوداً
                if (s) { 
                  Navigator.pop(context); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم طلب الموعد بنجاح، بانتظار موافقة المالك'))); 
                }
              },
              child: Text(time),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ]);
      }).toList(),
    );
  }

  String _dayName(String d) => {'mon':'الاثنين','tue':'الثلاثاء','wed':'الأربعاء','thu':'الخميس','fri':'الجمعة','sat':'السبت','sun':'الأحد'}[d] ?? d;
}
