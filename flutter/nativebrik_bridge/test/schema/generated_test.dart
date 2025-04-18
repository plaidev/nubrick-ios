import 'package:flutter_test/flutter_test.dart';
import 'package:nativebrik_bridge/schema/generated.dart';

void main() {
  group('Enum encode/decode', () {
    test('AlignItems encode/decode', () {
      // Encode
      expect(AlignItems.START.encode(), 'START');
      expect(AlignItems.CENTER.encode(), 'CENTER');
      expect(AlignItems.END.encode(), 'END');
      expect(AlignItems.UNKNOWN.encode(), null);
      // Decode
      expect(AlignItemsExtension.decode('START'), AlignItems.START);
      expect(AlignItemsExtension.decode('CENTER'), AlignItems.CENTER);
      expect(AlignItemsExtension.decode('END'), AlignItems.END);
      expect(AlignItemsExtension.decode('something_else'), AlignItems.UNKNOWN);
      expect(AlignItemsExtension.decode(null), null);
    });
  });

  group('Struct encode/decode', () {
    test('Color encode/decode', () {
      final color = Color(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.4);
      final encoded = color.encode();
      expect(encoded['__typename'], 'Color');
      final decoded = Color.decode(encoded);
      expect(decoded?.red, color.red);
      expect(decoded?.green, color.green);
      expect(decoded?.blue, color.blue);
      expect(decoded?.alpha, color.alpha);
    });
    test('BoxShadow encode/decode', () {
      final color = Color(red: 1, green: 0, blue: 0, alpha: 1);
      final boxShadow =
          BoxShadow(color: color, offsetX: 2, offsetY: 3, radius: 4);
      final encoded = boxShadow.encode();
      expect(encoded['__typename'], 'BoxShadow');
      final decoded = BoxShadow.decode(encoded);
      expect(decoded?.color?.red, color.red);
      expect(decoded?.color?.green, color.green);
      expect(decoded?.color?.blue, color.blue);
      expect(decoded?.color?.alpha, color.alpha);
      expect(decoded?.offsetX, boxShadow.offsetX);
      expect(decoded?.offsetY, boxShadow.offsetY);
      expect(decoded?.radius, boxShadow.radius);
    });
  });

  group('Union encode/decode', () {
    test('UIBlock as UIRootBlock encode/decode', () {
      final rootBlock = UIRootBlock(id: 'root', data: null);
      final union = UIBlock.asUIRootBlock(rootBlock);
      final encoded = union.encode();
      final decoded = UIBlock.decode(encoded);
      expect(decoded != null, true);
      expect(encoded?['__typename'], 'UIRootBlock');
      switch (decoded) {
        case UIBlockUIRootBlock(data: var data):
          expect(data.id, rootBlock.id);
          expect(data.data, rootBlock.data);
          break;
        default:
          fail('Decoded UIBlock is not a UIRootBlock');
      }
    });
  });
}
