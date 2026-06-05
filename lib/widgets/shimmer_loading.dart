import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

/// ويدجتات التحميل الوهمية (Shimmer) — تحاكي شكل المحتوى أثناء الجلب
class ShimmerLoading {
  static Shimmer _wrap(Widget child) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBlack,
        highlightColor: const Color(0xFF2A2A2A),
        child: child,
      );

  static Widget _box(
          {double? w, double h = 14, double radius = 8, EdgeInsets? margin}) =>
      Container(
        width: w,
        height: h,
        margin: margin,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  /// بطاقة عرض وهمية تحاكي OfferCard
  static Widget offerCard() {
    return _wrap(
      Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(w: 180, h: 18),
                  const SizedBox(height: 10),
                  _box(w: 120, h: 14),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _box(w: 80, h: 14),
                      _box(w: 24, h: 24, radius: 12),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// قائمة بطاقات عروض وهمية
  static Widget offerList({int count = 4}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (_, __) => offerCard(),
    );
  }

  /// عنصر قائمة وهمي (ListTile) — للطلبات/المواعيد/الإشعارات
  static Widget listTile() {
    return _wrap(
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _box(w: double.infinity, h: 14),
                  const SizedBox(height: 8),
                  _box(w: 140, h: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// قائمة عناصر وهمية
  static Widget tileList({int count = 6}) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: count,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (_, __) => listTile(),
    );
  }

  /// شبكة بطاقات إحصائيات وهمية (للوحات)
  static Widget statsGrid({int count = 4}) {
    return _wrap(
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.5,
        padding: const EdgeInsets.all(16),
        children: List.generate(
          count,
          (_) => Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceBlack,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
