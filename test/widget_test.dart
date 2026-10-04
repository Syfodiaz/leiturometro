import 'package:flutter_test/flutter_test.dart';
import 'package:leitorkids/main.dart';

void main() {
  testWidgets('abre a tela inicial do LeitorKids', (tester) async {
    await tester.pumpWidget(const LeitorKidsApp());
    expect(find.text('LeitorKids'), findsOneWidget);
    expect(find.text('Começar a ler'), findsOneWidget);
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
