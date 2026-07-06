import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// علامات اختبار لا تظهر للمستخدم النهائي.
///
/// في وضع debug فقط نضيف Semantics label ثابت بالإنكليزية حتى يستطيع Maestro
/// التعامل مع التطبيق بدون الاعتماد على OCR للنصوص العربية.
class E2E extends StatelessWidget {
  final String id;
  final Widget child;
  final bool button;

  const E2E({super.key, required this.id, required this.child, this.button = false});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return Semantics(
      container: true,
      label: id,
      button: button,
      child: child,
    );
  }
}

class E2EMarker extends StatelessWidget {
  final String id;
  const E2EMarker(this.id, {super.key});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: id,
      child: const SizedBox(width: 1, height: 1),
    );
  }
}

String e2eRouteId(String route) {
  final clean = route
      .replaceAll(RegExp(r'^/+'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'e2e_route_${clean.isEmpty ? 'root' : clean}';
}
