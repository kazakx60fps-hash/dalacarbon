// Қосымшаның негізгі ағыны: заставка → кіру → (демо) → басты бет.
import 'package:flutter_test/flutter_test.dart';

import 'package:dalacarbon_mobile/main.dart';
import 'package:dalacarbon_mobile/screens/home_screen.dart';
import 'package:dalacarbon_mobile/screens/login_screen.dart';
import 'package:dalacarbon_mobile/screens/splash_screen.dart';

void main() {
  testWidgets('заставка → кіру → демо → басты бет', (tester) async {
    await tester.pumpWidget(const DalaCarbonApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // Заставка ~4,7 с, сосын fade-пен кіру экраны
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Қош келдіңіз!'), findsOneWidget);

    // Бос форма — қате хабарлары
    await tester.tap(find.text('Кіру'));
    await tester.pump();
    expect(find.text('Логин немесе email енгізіңіз'), findsOneWidget);
    expect(find.text('Құпиясөзді енгізіңіз'), findsOneWidget);

    // Демо режим → жүктелу → басты бет
    await tester.ensureVisible(find.text('Демо режимде көру'));
    await tester.tap(find.text('Демо режимде көру'));
    await tester.pump();
    expect(find.text('Спутник деректері жүктелуде…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Демо фермер'), findsOneWidget);
    expect(find.textContaining('38 250', findRichText: true), findsWidgets);
  });
}
