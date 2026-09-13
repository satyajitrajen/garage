import 'package:flutter_test/flutter_test.dart';
import 'package:garage_manager/theme/app_text.dart';

void main() {
  test('AppText token scale has the approved values', () {
    expect(AppText.micro, 10);
    expect(AppText.label, 12);
    expect(AppText.caption, 13);
    expect(AppText.body, 14);
    expect(AppText.subtitle, 15.5);
    expect(AppText.title, 17);
    expect(AppText.headline, 20);
    expect(AppText.display, 26);
  });
}
