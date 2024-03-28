import 'package:nativebrik_bridge/embedding.dart';

EventPayloadType _parseEventPayloadType(dynamic type) {
  switch (type) {
    case "INTEGER":
      return EventPayloadType.integer;
    case "STRING":
      return EventPayloadType.string;
    case "TIMESTAMPZ":
      return EventPayloadType.timestamp;
    default:
      return EventPayloadType.unknown;
  }
}

Event parseEvent(dynamic arguments) {
  final map = arguments;
  final name = map["name"] as String?;
  final deepLink = map["deepLink"] as String?;
  final rawPayload = map["payload"] as List<dynamic>? ?? [];
  final payload = rawPayload
      .map((e) => EventPayload(e["name"] as String? ?? "",
          e["value"] as String? ?? "", _parseEventPayloadType(e["type"])))
      .toList();
  return Event(name, deepLink, payload);
}
