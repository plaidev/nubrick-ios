import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class NativebrikProvider extends StatelessWidget {
  final Widget child;
  const NativebrikProvider({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [child, _render(context)],
    );
  }

  Widget _render(BuildContext context) {
    const String viewType = "nativebrik-overlay-view";
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return const SizedBox.shrink();
      case TargetPlatform.android:
        return const SizedBox(
          height: 1,
          width: 1,
          child: AndroidView(
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: <String, dynamic>{},
            creationParamsCodec: StandardMessageCodec(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
