import 'package:flutter_test/flutter_test.dart';
import 'package:qr_order_app/api.dart';

void main() {
  test('dinh dang tien VND', () {
    expect(vnd(55000), '55.000đ');
    expect(vnd(1250000), '1.250.000đ');
    expect(vnd(0), '0đ');
  });
}
