import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';

class NativebrikEvent {
  final String name;
  NativebrikEvent(this.name);
}

class NativebrikDispatcher {
  Future<void> dispatch(NativebrikEvent event) {
    return NativebrikBridgePlatform.instance.dispatch(event.name);
  }
}
