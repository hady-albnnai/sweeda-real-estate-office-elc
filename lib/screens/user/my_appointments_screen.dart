import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../core/utils/app_utils.dart';

/// شاشة مواعيد المستخدم (المعاينات)
class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userModel?.uid;
      if (userId != null) {
        Provider.of<AppointmentProvider>(context, listen: false).fetchMyAppointments(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apptProv = Provider.of<AppointmentProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: const Text('مواعيدي', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
      ),
      body: apptProv.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : apptProv.myAppointments.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: apptProv.myAppointments.length,
                  itemBuilder: (context, index) {
                    final appt = apptProv.myAppointments[index];
                    return _appointmentCard(appt, apptProv);
                  },
                ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 2),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: AppTheme.textGrey.withValues(alpha: 0.3)),
          const SizedBox(height: 20),
          const Text('ما عندك مواعيد حالياً', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _appointmentCard(dynamic appt, AppointmentProvider provider) {
    final statusColors = {0: Colors.orange, 1: Colors.blue, 2: Colors.green, 3: Colors.red};
    final statusTexts = {0: 'قيد الانتظار', 1: 'مؤكد', 2: 'منتهي', 3: 'ملغي'};
    final sts = appt.sts ?? 0;
    final apptDate = appt.dt != null ? AppUtils.formatTimestamp(appt.dt) : 'غير محدد';

    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: AppTheme.primaryGold, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('معاينة عرض #${appt.offId?.toString().substring(0, 8) ?? "..."}',
                      style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (statusColors[sts] ?? Colors.grey).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusTexts[sts] ?? 'غير معروف',
                    style: TextStyle(color: statusColors[sts] ?? Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey, height: 20),
            Row(children: [
              const Icon(Icons.calendar_today, size: 16, color: AppTheme.textGrey),
              const SizedBox(width: 8),
              Text(apptDate, style: const TextStyle(color: AppTheme.textGrey)),
            ]),
            if (sts <= 1) ...[
              const SizedBox(height: 15),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelDialog(context, appt, provider),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    label: const Text('إلغاء الموعد', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, dynamic appt, AppointmentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceBlack,
        title: const Text('إلغاء الموعد', style: TextStyle(color: AppTheme.textWhite)),
        content: const Text('هل أنت متأكد من إلغاء هذا الموعد؟', style: TextStyle(color: AppTheme.textGrey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لا', style: TextStyle(color: AppTheme.textGrey))),
          TextButton(
            onPressed: () async {
              await provider.cancelAppointment(appt.id, context.read<AuthProvider>().userModel?.uid ?? '', 'إلغاء من المستخدم');
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إلغاء الموعد')));
            },
            child: const Text('نعم، إلغاء', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
