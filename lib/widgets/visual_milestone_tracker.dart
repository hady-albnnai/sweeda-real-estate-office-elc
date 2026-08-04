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
      padding: AppTheme.paddingAllLarge,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlack,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: AppTheme.primaryGold, size: 22),
              AppTheme.gapWidthSmall,
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
          AppTheme.gapHeightLarge,
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
                          color: isDone ? AppTheme.successGreen : AppTheme.deepBlack,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone ? AppTheme.successGreen : AppTheme.textGrey.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check, color: Colors.white, size: 16)
                              : Text('${i + 1}', style: const TextStyle(color: AppTheme.textGrey, fontSize: AppTheme.fontSizeCaption)),
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: isDone ? AppTheme.successGreen : Colors.white12,
                          ),
                        ),
                    ],
                  ),
                  AppTheme.gapWidthMedium,
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
                              fontSize: AppTheme.fontSizeMedium,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            steps[i]['sub']!,
                            style: TextStyle(color: AppTheme.textGrey.withOpacity(0.8), fontSize: AppTheme.fontSizeCaption),
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
            AppTheme.gapHeightSmall,
            Container(
              padding: AppTheme.paddingAllMedium,
              decoration: BoxDecoration(color: AppTheme.successGreen.withOpacity(0.1), borderRadius: AppTheme.borderRadiusMedium),
              child: Row(
                children: [
                  const Icon(Icons.folder_shared, color: AppTheme.successGreen),
                  AppTheme.gapWidthSmall,
                  const Expanded(
                    child: Text('خزنة المستندات المعتمدة جاهزة للمعاينة والتنزيل', style: TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.bold, fontSize: AppTheme.fontSizeSmall)),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successGreen, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    child: const Text('استعراض 📁', style: TextStyle(fontSize: AppTheme.fontSizeCaption)),
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
