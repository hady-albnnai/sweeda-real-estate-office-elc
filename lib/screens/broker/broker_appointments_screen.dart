import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/broker_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/appointment_model.dart';
import '../../core/theme/app_theme.dart';

class BrokerAppointmentsScreen extends StatelessWidget {
  const BrokerAppointmentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final brokerProv = Provider.of<BrokerProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final brokerId = auth.userModel?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('طلبات المعاينة'), backgroundColor: Colors.transparent),
      body: FutureBuilder<List<AppointmentModel>>(
        future: brokerProv.getBrokerAppointments(brokerId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
          if (!snap.hasData || snap.data!.isEmpty) return const Center(child: Text('لا توجد طلبات مواعيد حالياً', style: TextStyle(color: AppTheme.textGrey)));
          return ListView.builder(
            padding: const EdgeInsets.all(15), itemCount: snap.data!.length,
            itemBuilder: (context, i) {
              final a = snap.data![i];
              return Card(color: AppTheme.surfaceBlack, margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  title: Text('طلب معاينة - عرض #${a.offId.substring(0, 8)}', style: const TextStyle(color: AppTheme.textWhite)),
                  subtitle: Text('التاريخ: ${a.dt.toString().split('.').first}', style: const TextStyle(color: AppTheme.textGrey)),
                  trailing: a.sts == 0 ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.check, color: AppTheme.primaryGold),
                      onPressed: () async {
                        await brokerProv.handleAppointment(a.id, 1);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم قبول الموعد')));
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BrokerAppointmentsScreen()));
                      }),
                    IconButton(icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await brokerProv.handleAppointment(a.id, 2);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الموعد')));
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const BrokerAppointmentsScreen()));
                      }),
                  ]) : Text('الحالة: ${a.sts}', style: const TextStyle(color: AppTheme.primaryGold)),
                ));
            },
          );
        },
      ),
    );
  }
}
