import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../core/network/supabase_service.dart';
import '../providers/auth_provider.dart';

/// ⭐ Dialog لتقييم طرف آخر بعد صفقة/موعد مكتمل.
///
/// يكتب في جدول `ratings` (reviewer_uid, target_uid, stars, comment).
/// Trigger في DB يمنح 200 نقطة للمستهدف إذا كانت 5 نجوم.
///
/// مرجع: docs/LOGIC_SPEC.md §3.3 + supabase/migrations/2026_06_06_points_refinement.sql
class RatingDialog extends StatefulWidget {
  final String targetUid;
  final String targetName; // اسم للعرض فقط (لا يُحفظ — الخصوصية)
  final String? refLabel; // مثلاً "بعد موعد المعاينة"

  const RatingDialog({
    super.key,
    required this.targetUid,
    required this.targetName,
    this.refLabel,
  });

  /// عرض الـ dialog مع التحقق من تسجيل الدخول. يُعيد true إذا تم الإرسال.
  static Future<bool> show({
    required BuildContext context,
    required String targetUid,
    required String targetName,
    String? refLabel,
  }) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('سجّل دخولك أولاً لإرسال تقييم')),
      );
      return false;
    }
    if (auth.userModel!.uid == targetUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكنك تقييم نفسك')),
      );
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialog(
        targetUid: targetUid,
        targetName: targetName,
        refLabel: refLabel,
      ),
    );
    return result == true;
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _stars = 0;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر عدد النجوم من 1 إلى 5')),
      );
      return;
    }
    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    try {
      await SupabaseService().client.rpc(
        'create_rating_internal',
        params: {
          'p_reviewer_uid': auth.userModel!.uid,
          'p_target_uid': widget.targetUid,
          'p_stars': _stars,
          'p_comment': _commentCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_stars == 5
              ? '⭐ شكراً! تم منح الطرف الآخر 200 نقطة مكافأة'
              : '✅ تم إرسال تقييمك'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      final raw = e.toString();
      String userMsg = '❌ فشل الإرسال';
      if (raw.contains('completed a deal/appointment')) {
        userMsg = 'لا يمكن التقييم قبل إتمام موعد أو صفقة مع هذا الطرف.';
      } else if (raw.contains('ratings_unique_reviewer_target') ||
          raw.contains('duplicate key')) {
        userMsg = 'لقد قيّمت هذا الطرف مسبقاً (تقييم واحد فقط مسموح).';
      } else if (raw.contains('ratings_no_self')) {
        userMsg = 'لا يمكنك تقييم نفسك.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userMsg)),
      );
    }
  }

  String _starLabel(int s) {
    switch (s) {
      case 1: return 'سيء جداً';
      case 2: return 'سيء';
      case 3: return 'متوسط';
      case 4: return 'جيد';
      case 5: return 'ممتاز';
      default: return 'اختر تقييماً';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceBlack,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.star_rate, color: AppTheme.primaryGold),
            SizedBox(width: 8),
            Text('تقييم تجربتك',
                style: TextStyle(color: AppTheme.textWhite)),
          ]),
          const SizedBox(height: 4),
          Text(
            widget.refLabel != null
                ? '${widget.refLabel} • مع: ${widget.targetName}'
                : 'مع: ${widget.targetName}',
            style: const TextStyle(color: AppTheme.textGrey, fontSize: 12),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // نجوم تفاعلية
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _stars;
              return IconButton(
                onPressed: _sending ? null : () => setState(() => _stars = i + 1),
                icon: Icon(
                  filled ? Icons.star : Icons.star_border,
                  color: filled ? AppTheme.primaryGold : AppTheme.textGrey,
                  size: 36,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                constraints: const BoxConstraints(),
              );
            }),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _starLabel(_stars),
              style: TextStyle(
                  color: _stars > 0
                      ? AppTheme.primaryGold
                      : AppTheme.textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 200,
            enabled: !_sending,
            style: const TextStyle(color: AppTheme.textWhite),
            decoration: const InputDecoration(
              hintText: 'تعليقك (اختياري)',
              hintStyle: TextStyle(color: AppTheme.textGrey),
              border: OutlineInputBorder(),
              counterStyle: TextStyle(color: AppTheme.textGrey, fontSize: 11),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: const Text('لاحقاً',
              style: TextStyle(color: AppTheme.textGrey)),
        ),
        ElevatedButton.icon(
          onPressed: _sending ? null : _submit,
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.deepBlack))
              : const Icon(Icons.send, color: AppTheme.deepBlack, size: 18),
          label: const Text('إرسال',
              style: TextStyle(
                  color: AppTheme.deepBlack, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold),
        ),
      ],
    );
  }
}
