import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../core/utils/app_utils.dart';

/// شاشة طلبات المستخدم (شراء / إيجار)
class MyRequestsScreen extends StatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  State<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends State<MyRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final userId = auth.userModel?.uid;
      if (userId != null) {
        Provider.of<RequestProvider>(context, listen: false).fetchMyRequests(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final reqProv = Provider.of<RequestProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: const Text('طلباتي', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.primaryGold),
            onPressed: () => context.push('/user/add-request'),
          ),
        ],
      ),
      body: reqProv.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : reqProv.myRequests.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: reqProv.myRequests.length,
                  itemBuilder: (context, index) {
                    final req = reqProv.myRequests[index];
                    return _requestCard(req);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/user/add-request'),
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: AppTheme.deepBlack,
        icon: const Icon(Icons.add),
        label: const Text('طلب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 1),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: AppTheme.textGrey.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text('ما عندك طلبات حالياً', style: TextStyle(color: AppTheme.textGrey, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => context.push('/user/add-request'),
            icon: const Icon(Icons.add),
            label: const Text('أضف طلبك الأول'),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(dynamic req) {
    final typeText = req.typ == 0 ? 'شراء' : 'استئجار';
    final elementText = req.elm == 0 ? 'عقار' : 'سيارة';
    final statusColors = {0: Colors.green, 1: Colors.orange, 2: Colors.blue, 3: Colors.grey, 4: Colors.deepOrange};
    final statusTexts = {0: 'نشط', 1: 'قيد المعالجة', 2: 'تمت تلبيته', 3: 'ملغي', 4: 'منتهي الصلاحية'};

    return Card(
      color: AppTheme.surfaceBlack,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
          child: Icon(req.elm == 0 ? Icons.home : Icons.directions_car, color: AppTheme.primaryGold),
        ),
        title: Text(
          // اسم العميل وهاتفه للإدارة وصاحب الطلب فقط — لا يظهر في القائمة
          '$typeText $elementText',
          style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('$typeText — $elementText', style: const TextStyle(color: AppTheme.textGrey)),
            if (req.prc > 0)
              Text('الميزانية: ${AppUtils.formatPrice(req.prc, currency: req.cur)}',
                  style: const TextStyle(color: AppTheme.primaryGold)),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: (statusColors[req.sts] ?? Colors.grey).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            statusTexts[req.sts] ?? 'غير معروف',
            style: TextStyle(color: statusColors[req.sts] ?? Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        onTap: () => context.push('/user/request/${req.id}'),
      ),
    );
  }
}
