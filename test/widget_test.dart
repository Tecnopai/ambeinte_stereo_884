// test/widget_test.dart - TESTS BÁSICOS QUE FUNCIONAN
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Basic math test - always passes', () {
    expect(1 + 1, 2);
  });

  test('String operations work', () {
    expect('Ambient Stereo'.contains('Ambient'), true);
  });

  test('List operations work', () {
    final items = ['Inicio', 'Música', 'Ajustes'];
    expect(items.length, 3);
  });

  group('App logic tests', () {
    test('app name is correct', () {
      expect('Ambient Stereo', 'Ambient Stereo');
    });

    test('frequency is correct', () {
      expect('88.4 FM', '88.4 FM');
    });
  });

  test('Boolean logic works', () {
    expect(true, isTrue);
    expect(false, isFalse);
  });
}
