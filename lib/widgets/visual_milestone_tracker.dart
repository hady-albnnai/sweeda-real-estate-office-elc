import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class VisualMilestoneTracker extends StatelessWidget {
  final int currentStep; // 0: استلام الطلب والاعتماد، 1: استخراج المعقب، 2: تدقيق المحامي، 3: جاهز للتوقيع
  final List<String>? documentUrls;

  const VisualMilestoneTracker({
    super.key,
    required this.currentStep,
    this.documentUrls,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'title': 'تم استلام الرسوم وتعيين المحامي', 'sub': 'تم الربط بالمستشار القانوني'},
      {'title': 'المعقب الميداني يستخرج الثبوتيات', 'sub': 'جلب الطابو وكشوفات المرور'},
      {'title': 'المحامي يدقق الوثائق ويصوغ العقد', 'sub': 'التأكد من خلو الإشارات وصياغة البنود'},
      {'title': 'المعاملة مدققة وجاهزة للتوقيع القطعي', 'sub': 'عقد معتمد وجاهز للإتمام'},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.primaryGold, size: 22),
              SizedBox(width: 8),
              Text(
                'شريط تتبع إنجاز باقة التوثيق 📜⚖️',
                style: TextStyle(
                  color: AppTheme.primaryGold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(steps.length, (i) {
            final isDone = i <= currentStep;
            final isCurrent = i == currentStep;
            final isLast = i == steps.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isDone ? Colors.green : AppTheme.deepBlack,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone ? Colors.green : AppTheme.textGrey.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text('${i + 1}', style: TextStyle(color: AppTheme.textGrey, fontSize: 11)),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isDone ? Colors.green : Colors.white12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i]['title']!,
                            style: TextStyle(
                              color: isCurrent ? AppTheme.primaryGold : (isDone ? AppTheme.textWhite : AppTheme.textGrey),
                              fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            steps[i]['sub']!,
                            style: TextStyle(color: AppTheme.textGrey.withOpacity(0.8), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (currentStep >= 2 && documentUrls != null && documentUrls!.isNotEmpty) ...[
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.folder_shared, color: Colors.green),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('خزنة المستندات المعتمدة جاهزة للمعاينة والتنزيل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: const Text('استعراض 📁', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
