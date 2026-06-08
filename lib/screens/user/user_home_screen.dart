import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/offer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/config_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/error_widget.dart';
import '../../core/theme/app_theme.dart';

/// الشاشة الرئيسية للمستخدم بعد تسجيل الدخول
/// تحتوي على: بحث + فلتر + عروض + BottomNavigationBar
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedCategory = 0; // 0=الكل, 1=عقارات, 2=سيارات
  // 🔒 Fix: نحتفظ بمرجع OfferProvider لاستخدامه في dispose بأمان
  // (لا يمكن استدعاء Provider.of في dispose بعد deactivation)
  OfferProvider? _offerProvRef;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final config = Provider.of<ConfigProvider>(context, listen: false);
      await config.loadConfig();
      if (!mounted) return;
      final offerProv = Provider.of<OfferProvider>(context, listen: false);
      _offerProvRef = offerProv; // حفظ المرجع
      offerProv.fetchOffers();
      offerProv.subscribeRealtime(); // تحديث فوري للعروض

      // تسجيل سلسلة الدخول اليومي (Streak) + منح النقاط + جلب الإشعارات
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isLoggedIn) {
        final uid = auth.userModel?.uid ?? '';
        if (uid.isNotEmpty) {
          Provider.of<NotificationProvider>(context, listen: false)
              .fetchNotifications(uid);
        }
        final res = await auth.registerStreak(config.config);
        if (mounted && res['awarded'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔥 سلسلة دخولك: ${res['streak']} يوم — حصلت على نقاط!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    // 🔒 Fix: نستخدم المرجع المحفوظ بدل Provider.of (الذي يفشل في dispose)
    _offerProvRef?.unsubscribeRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final offerProv = Provider.of<OfferProvider>(context);
    final userName = auth.userModel?.nm ?? 'مستخدم';

    return Scaffold(
      backgroundColor: AppTheme.deepBlack,
      appBar: AppBar(
        backgroundColor: AppTheme.deepBlack,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً، $userName 👋',
              style: const TextStyle(
                color: AppTheme.textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'شو بدك اليوم؟',
              style: TextStyle(
                color: AppTheme.primaryGold.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          // أيقونة الإشعارات مع badge لعدد غير المقروء
          Consumer<NotificationProvider>(
            builder: (context, notif, _) {
              final count = notif.unreadCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none,
                        color: AppTheme.primaryGold),
                    onPressed: () => context.push('/user/notifications'),
                  ),
                  if (count > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: const BoxDecoration(
                          color: AppTheme.errorRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count > 9 ? '9+' : '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppTheme.primaryGold, size: 28),
            onPressed: () => context.push('/user/add-offer'),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن عقار أو سيارة...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGold),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, color: AppTheme.primaryGold),
                  onPressed: () => context.push('/search'),
                ),
                filled: true,
                fillColor: AppTheme.surfaceBlack,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // فئات العروض
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              children: [
                _buildChip('الكل', _selectedCategory == 0),
                const SizedBox(width: 8),
                _buildChip('🏠 عقارات', _selectedCategory == 1),
                const SizedBox(width: 8),
                _buildChip('🚗 سيارات', _selectedCategory == 2),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // قائمة العروض
          // مؤشّر العمل دون اتصال
          if (offerProv.fromCache && offerProv.offers.isNotEmpty)
            Container(
              width: double.infinity,
              color: Colors.orange.withValues(alpha: 0.15),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text('📡 وضع دون اتصال — عرض بيانات محفوظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.orange, fontSize: 11)),
            ),
          Expanded(
            child: offerProv.isLoading && offerProv.offers.isEmpty
                ? ShimmerLoading.offerList()
                : (offerProv.error != null && offerProv.offers.isEmpty)
                    ? AppErrorWidget(
                        message: offerProv.error!,
                        onRetry: () => offerProv.fetchOffers(),
                      )
                    : offerProv.offers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.home_work,
                                    size: 80,
                                    color: AppTheme.textGrey.withValues(alpha: 0.3)),
                                const SizedBox(height: 20),
                                const Text(
                                  'لا توجد عروض متاحة حالياً',
                                  style: TextStyle(
                                      color: AppTheme.textGrey, fontSize: 16),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      context.push('/user/add-offer'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('أضف عرضك الأول'),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => offerProv.fetchOffers(),
                            color: AppTheme.primaryGold,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 15),
                              itemCount:
                                  _filteredOffers(offerProv.offers).length,
                              itemBuilder: (context, index) {
                                final offer =
                                    _filteredOffers(offerProv.offers)[index];
                                return OfferCard(offer: offer);
                              },
                            ),
                          ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(currentIndex: 0),
    );
  }

  List<dynamic> _filteredOffers(List<dynamic> offers) {
    if (_selectedCategory == 0) return offers;
    return offers.where((o) => o.typ == (_selectedCategory - 1)).toList();
  }

  Widget _buildChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label, style: TextStyle(
        color: isSelected ? AppTheme.deepBlack : AppTheme.textWhite,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      selected: isSelected,
      selectedColor: AppTheme.primaryGold,
      backgroundColor: AppTheme.surfaceBlack,
      checkmarkColor: AppTheme.deepBlack,
      side: BorderSide(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _selectedCategory =
          label == 'الكل' ? 0 : label.contains('عقار') ? 1 : 2),
    );
  }
}
