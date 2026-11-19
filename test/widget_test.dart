import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('config example keeps placeholders', () {
    final text = File('lib/config.example.dart').readAsStringSync();
    expect(text, contains('YOUR_SUPABASE_HOST'));
    expect(text, contains('REPLACE_WITH_ANON_OR_PUBLISHABLE_KEY'));
  });
}
