// Pure-Dart checks for the generic share link and the share captions.
// Run:  flutter test test/smart_link_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:offro_user/core/widgets/product_share_card.dart';

void main() {
  group('captions', () {
    final product = ProductShareData.fromProduct({
      '_id': '6acf7a50e73ef4790061e0b7',
      'title': 'test analytic',
      'price': '299',
      'original_price': '400',
      'offer_text': '25% OFF',
      'store_name': 'store 2',
      'city': 'Ballari',
    });
    test('product caption', () {
      expect(
        ProductShare.caption(product),
        '*test analytic*\n\nStore: store 2\nLocation: Ballari\nOffer Price: ₹299\n'
        'Original Price: ₹400\nSave: ₹101\n\n*View on OffrO*\nhttps://offro.app/open',
      );
    });
    test('store data + caption', () {
      final store = ProductShareData.fromStore({
        '_id': '65a000000000000000000001',
        'store_name': 'Store 2',
        'area': '',
        'city': 'Ballari',
        'image_url': 'https://x/s.jpg',
      });
      expect(store.link, 'https://offro.app/open');
      expect(store.imageSrc, 'https://x/s.jpg');
      expect(store.discountBadge, isEmpty); // no green offer band for stores
      expect(
        ProductShare.storeCaption(store),
        '*Store 2*\n\nLocation: Ballari\n\n*View Store on OffrO*\nhttps://offro.app/open',
      );
    });
    test('product and store use the same generic link', () {
      expect(product.link, ProductLink.open);
      expect(ProductLink.open, 'https://offro.app/open');
      expect(ProductShareData.fromStore({'_id': 'x', 'store_name': 'S'}).link, ProductLink.open);
      // a product without an id still gets the link
      expect(ProductShareData.fromProduct({'title': 'a'}).link, ProductLink.open);
    });
    test('no emojis in either caption', () {
      final emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);
      expect(emoji.hasMatch(ProductShare.caption(product)), isFalse);
    });
  });
}
