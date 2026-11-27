// Қосымшаның ағыны (серверсіз бөлігі) және сандарды пішімдеу.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dalacarbon_mobile/main.dart';
import 'package:dalacarbon_mobile/screens/login_screen.dart';
import 'package:dalacarbon_mobile/screens/splash_screen.dart';
import 'package:dalacarbon_mobile/util/format.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({})); // сақталған токен жоқ

  testWidgets('заставка → кіру → бос форманың қателері', (tester) async {
    await tester.pumpWidget(const DalaCarbonApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Қош келдіңіз!'), findsOneWidget);
    expect(find.text('Тіркелу'), findsOneWidget);

    await tester.tap(find.text('Кіру'));
    await tester.pump();
    expect(find.text('Логин немесе email өрісін толтырыңыз'), findsOneWidget);
    expect(find.text('Құпиясөзді енгізіңіз'), findsOneWidget);
  });

  test('сандар сайттағыдай пішімделеді', () {
    expect(fmtInt(38250), '38 250');
    expect(fmtInt(5000), '5 000');
    expect(fmtInt(999), '999');
    expect(money(38250), r'$38 250');
    expect(fmtNum(268.0875), '268,1');
    expect(fmtNum(0.6375, 4), '0,6375');
    expect(fmtNum(12.0), '12');
    expect(isoDate(DateTime(2026, 11, 7)), '2026-11-07');
    expect(roundHalfEven(1912.5), 1912); // сервердегі Python round() сияқты
    expect(roundHalfEven(1913.5), 1914);
    expect(roundHalfEven(10.2), 10);
  });
}
