import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leitorkids/main.dart';

void main() {
  testWidgets('abre a tela de login real do LeitorKids', (tester) async {
    final store = DemoStore()..authReady = true;
    await tester.pumpWidget(MaterialApp(home: LoginView(store: store)));
    expect(find.text('Entrar no LeitorKids'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Criar conta do responsável'), findsOneWidget);
    store.dispose();
  });

  test(
      'cronômetro exclui o tempo pausado no ciclo iniciar-pausar-retomar-finalizar',
      () {
    final store = DemoStore();
    store.startTimer();
    store.tickOnceForTest();
    store.tickOnceForTest();
    expect(store.timerSeconds, 2);
    store.pauseTimer();
    store.tickOnceForTest();
    store.tickOnceForTest();
    expect(store.timerSeconds, 2, reason: 'tempo pausado não pode avançar');
    store.startTimer();
    store.tickOnceForTest();
    expect(store.timerSeconds, 3);
    store.stopTimer();
    store.dispose();
  });
}
