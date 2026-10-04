import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

void main() => runApp(const LeitorKidsApp());

const navy = Color(0xFF172554);
const purple = Color(0xFF7C3AED);
const mint = Color(0xFF10B981);
const yellow = Color(0xFFFACC15);

class Session {
  Session(
      {required this.id,
      required this.child,
      required this.minutes,
      required this.summary,
      this.photoName,
      this.photoBytes,
      this.approved = false,
      this.rejected = false,
      this.rejectionReason,
      this.joinedValid = false,
      this.inVacation = false,
      this.createdBy = 'criança',
      this.origin = 'manual',
      DateTime? date})
      : date = date ?? DateTime.now();
  final String id, child, summary;
  final int minutes;
  final String? photoName;
  final Uint8List? photoBytes;
  final bool approved, rejected;
  final String? rejectionReason;
  final bool joinedValid, inVacation;
  final String createdBy, origin;
  final DateTime date;
  bool get isManual => origin == 'manual';
  bool get isPending => !approved && !rejected;
  Session copyWith({bool? approved, bool? rejected, String? rejectionReason}) =>
      Session(
          id: id,
          child: child,
          minutes: minutes,
          summary: summary,
          photoName: photoName,
          photoBytes: photoBytes,
          approved: approved ?? this.approved,
          rejected: rejected ?? this.rejected,
          rejectionReason: rejectionReason ?? this.rejectionReason,
          joinedValid: joinedValid,
          inVacation: inVacation,
          createdBy: createdBy,
          origin: origin,
          date: date);
}

class AppNotification {
  AppNotification(
      {required this.type, required this.message, this.child, DateTime? date})
      : date = date ?? DateTime.now();
  final String type, message;
  final String? child;
  final DateTime date;
  bool read = false;
}

class Multiplier {
  const Multiplier(this.value, this.reason);
  final double value;
  final String reason;
  String get label =>
      '${value.toStringAsFixed(value == 1.5 ? 1 : 0)}x — $reason';
}

class DemoStore extends ChangeNotifier {
  final children = ['Lia', 'Davi', 'Bia'];
  final Map<String, Color> colors = {
    'Lia': const Color(0xFFFF8A65),
    'Davi': const Color(0xFF60A5FA),
    'Bia': const Color(0xFFA78BFA)
  };
  final List<Session> sessions = [
    Session(
        id: '1',
        child: 'Lia',
        minutes: 25,
        summary: 'A personagem encontrou uma porta secreta na biblioteca.',
        approved: true,
        origin: 'cronometro'),
    Session(
        id: '2',
        child: 'Davi',
        minutes: 18,
        summary: 'Li sobre os planetas e descobri que Saturno tem anéis.',
        approved: true,
        origin: 'manual'),
    Session(
        id: '3',
        child: 'Bia',
        minutes: 30,
        summary: 'O dragão ajudou a vila a encontrar água.',
        rejected: true,
        rejectionReason:
            'O resumo precisa contar um pouco mais sobre o que você leu.',
        origin: 'manual'),
  ];
  final List<AppNotification> notifications = [
    AppNotification(
        type: 'Lembrete',
        message: 'Não esqueça de registrar sua leitura de hoje!',
        child: 'Lia')
  ];
  String currentChild = 'Lia';
  bool loggedIn = true;
  String authenticatedRole = 'crianca';
  bool isResponsible = false;
  int weeklyGoal = 60;
  double rewardRatio = 2;
  double qualityMultiplier = 1.5;
  double joinedMultiplier = 1.2;
  double vacationMultiplier = 2.0;
  DateTime? vacationStart;
  DateTime? vacationEnd;
  String familyRules =
      'Ler com atenção, contar o que descobriu e cuidar dos livros.';
  int? timerSeconds;
  Timer? ticker;
  bool running = false;
  void loginAsChild(String child) {
    currentChild = child;
    authenticatedRole = 'crianca';
    loggedIn = true;
    isResponsible = false;
    notifyListeners();
  }

  void loginAsResponsible() {
    authenticatedRole = 'responsavel';
    loggedIn = true;
    isResponsible = true;
    notifyListeners();
  }

  void logout() {
    loggedIn = false;
    isResponsible = false;
    notifyListeners();
  }

  List<Session> get pending => sessions.where((s) => s.isPending).toList();
  List<Session> rejectedFor(String child) =>
      sessions.where((s) => s.child == child && s.rejected).toList();
  int get unreadNotifications => notifications
      .where((n) =>
          !n.read &&
          (n.child == null || isResponsible || n.child == currentChild))
      .length;
  Multiplier multiplierFor(Session session) {
    final options = <Multiplier>[const Multiplier(1, 'base')];
    if (session.photoBytes != null && session.summary.trim().length >= 50) {
      options.add(Multiplier(qualityMultiplier, 'qualidade'));
    }
    if (session.joinedValid) {
      options.add(Multiplier(joinedMultiplier, 'Ler Junto'));
    }
    final inConfiguredVacation = session.inVacation ||
        (vacationStart != null &&
            vacationEnd != null &&
            !session.date.isBefore(vacationStart!) &&
            !session.date.isAfter(vacationEnd!));
    if (inConfiguredVacation) {
      options.add(Multiplier(vacationMultiplier, 'férias'));
    }
    options.sort((a, b) => b.value.compareTo(a.value));
    return options.first;
  }

  double approvedPoints(String child) => sessions
      .where((s) => s.child == child && s.approved && !s.rejected)
      .fold(0, (a, s) => a + s.minutes * multiplierFor(s).value);
  int approvedMinutes(String child) => sessions
      .where((s) => s.child == child && s.approved && !s.rejected)
      .fold(0, (a, s) => a + s.minutes);
  int rank(String child) {
    final values = children.map((c) => approvedMinutes(c)).toList()
      ..sort((a, b) => b.compareTo(a));
    return values.indexOf(approvedMinutes(child)) + 1;
  }

  int streak(String child) {
    final days = sessions
        .where((s) => s.child == child && s.approved)
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet();
    int count = 0;
    var d = DateTime.now();
    while (days.contains(
        DateTime(d.year, d.month, d.day).subtract(Duration(days: count)))) {
      count++;
    }
    return count;
  }

  List<int> dailyMinutes(String child) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      return sessions
          .where((s) =>
              s.child == child &&
              s.approved &&
              s.date.year == day.year &&
              s.date.month == day.month &&
              s.date.day == day.day)
          .fold(0, (a, s) => a + s.minutes);
    });
  }

  void markNotificationsRead() {
    for (final n in notifications) {
      if (n.child == null || isResponsible || n.child == currentChild) {
        n.read = true;
      }
    }
    notifyListeners();
  }

  void addNotification(String type, String message, {String? child}) {
    notifications.insert(
        0, AppNotification(type: type, message: message, child: child));
    notifyListeners();
  }

  void startTimer() {
    timerSeconds ??= 0;
    running = true;
    ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (running) {
        timerSeconds = (timerSeconds ?? 0) + 1;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void pauseTimer() {
    running = false;
    notifyListeners();
  }

  void tickOnceForTest() {
    if (running) {
      timerSeconds = (timerSeconds ?? 0) + 1;
      notifyListeners();
    }
  }

  void stopTimer() {
    ticker?.cancel();
    ticker = null;
    running = false;
    notifyListeners();
  }

  void addSession(
      {required int minutes,
      required String summary,
      String? photo,
      Uint8List? photoBytes,
      String? child,
      String createdBy = 'criança',
      String origin = 'manual',
      bool joinedValid = false,
      bool inVacation = false}) {
    sessions.add(Session(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        child: child ?? currentChild,
        minutes: minutes,
        summary: summary,
        photoName: photo,
        photoBytes: photoBytes,
        createdBy: createdBy,
        origin: origin,
        joinedValid: joinedValid,
        inVacation: inVacation));
    timerSeconds = null;
    stopTimer();
    addNotification(
        'Registro enviado', 'Sua leitura foi enviada para aprovação.',
        child: child ?? currentChild);
  }

  void approve(Session session, bool ok, {String? reason}) {
    final i = sessions.indexOf(session);
    if (i >= 0) {
      sessions[i] = session.copyWith(
          approved: ok, rejected: !ok, rejectionReason: reason);
      addNotification(
          ok ? 'Registro aprovado' : 'Registro rejeitado',
          ok
              ? 'Sua leitura foi aprovada!'
              : 'Sua leitura foi rejeitada: $reason',
          child: session.child);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }
}

class LeitorKidsApp extends StatefulWidget {
  const LeitorKidsApp({super.key});
  @override
  State<LeitorKidsApp> createState() => _LeitorKidsAppState();
}

class _LeitorKidsAppState extends State<LeitorKidsApp> {
  final store = DemoStore();
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: store,
      builder: (_, __) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LeitorKids',
          theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                  seedColor: purple, brightness: Brightness.light),
              fontFamily: 'Arial'),
          home: Home(store: store)));
}

class Home extends StatelessWidget {
  const Home({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 760;
    return Scaffold(
        backgroundColor: const Color(0xFFF7F7FC),
        appBar: AppBar(
            toolbarHeight: 74,
            backgroundColor: navy,
            foregroundColor: Colors.white,
            title: const Text('LeitorKids',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
            actions: [
              if (store.isResponsible)
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white),
                        onPressed: () => store.loginAsChild(store.currentChild),
                        icon: const Icon(Icons.child_care),
                        label: const Text('Modo criança')))
              else
                Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white),
                        onPressed: () => store.loginAsResponsible(),
                        icon: const Icon(Icons.shield_rounded),
                        label: const Text('Responsável'))),
              NotificationBell(store: store),
              IconButton(
                  tooltip: 'Sair',
                  onPressed: () => store.logout(),
                  icon: const Icon(Icons.logout))
            ]),
        body: wide
            ? Row(children: [
                NavigationRail(
                    backgroundColor: Colors.white,
                    selectedIndex: 0,
                    onDestinationSelected: (_) {},
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home),
                          label: Text('Início')),
                      NavigationRailDestination(
                          icon: Icon(Icons.emoji_events_outlined),
                          selectedIcon: Icon(Icons.emoji_events),
                          label: Text('Ranking')),
                      NavigationRailDestination(
                          icon: Icon(Icons.history),
                          selectedIcon: Icon(Icons.history),
                          label: Text('Histórico'))
                    ]),
                Expanded(child: _body(context))
              ])
            : _body(context));
  }

  Widget _body(BuildContext context) => !store.loggedIn
      ? LoginView(store: store)
      : (store.isResponsible
          ? ResponsibleView(store: store)
          : ChildView(store: store));
}

class LoginView extends StatelessWidget {
  const LoginView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => Center(
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Entrar no LeitorKids',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: navy)),
                const SizedBox(height: 16),
                const Text(
                    'Escolha a conta da criança para esta demonstração.'),
                const SizedBox(height: 16),
                ...store.children.map((child) => SizedBox(
                    width: 260,
                    child: OutlinedButton.icon(
                        onPressed: () => store.loginAsChild(child),
                        icon: const Icon(Icons.child_care),
                        label: Text('Entrar como $child')))),
                const Divider(height: 28),
                SizedBox(
                    width: 260,
                    child: FilledButton.icon(
                        onPressed: store.loginAsResponsible,
                        icon: const Icon(Icons.shield),
                        label: const Text('Entrar como responsável')))
              ]))));
}

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => Stack(children: [
        IconButton(
            tooltip: 'Notificações',
            onPressed: () {
              store.markNotificationsRead();
              showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                          title: const Text('Notificações'),
                          content: SizedBox(
                              width: 420,
                              child: store.notifications.isEmpty
                                  ? const Text('Nenhuma notificação.')
                                  : ListView(
                                      shrinkWrap: true,
                                      children: store.notifications
                                          .where((n) =>
                                              n.child == null ||
                                              store.isResponsible ||
                                              n.child == store.currentChild)
                                          .map((n) => ListTile(
                                              leading: const Icon(
                                                  Icons.notifications_active,
                                                  color: purple),
                                              title: Text(n.type),
                                              subtitle: Text(
                                                  '${n.message}\n${DateFormat('dd/MM HH:mm').format(n.date)}')))
                                          .toList())),
                          actions: [
                            TextButton(
                                onPressed: () {
                                  store.markNotificationsRead();
                                  Navigator.pop(context);
                                },
                                child: const Text('Marcar todas como lidas'))
                          ]));
            },
            icon: const Icon(Icons.notifications_none)),
        if (store.unreadNotifications > 0)
          Positioned(
              right: 8,
              top: 8,
              child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle)))
      ]);
}

class HouseRulesView extends StatelessWidget {
  const HouseRulesView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Regras da casa')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Card(
            child: ListTile(
                leading: const Icon(Icons.timer, color: purple),
                title: const Text('Meta e recompensa'),
                subtitle: Text(
                    '${store.weeklyGoal} min de leitura = ${store.rewardRatio.toStringAsFixed(0)}h de jogo'))),
        Card(
            child: const ListTile(
                leading: Icon(Icons.verified_user, color: mint),
                title: Text('Quem aprova?'),
                subtitle:
                    Text('O responsável confere e aprova cada comprovação.'))),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Combinados da família',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: navy)),
                      const SizedBox(height: 8),
                      Text(store.familyRules)
                    ])))
      ]));
}

class WeeklyChart extends StatefulWidget {
  const WeeklyChart({super.key, required this.store});
  final DemoStore store;
  @override
  State<WeeklyChart> createState() => _WeeklyChartState();
}

class _WeeklyChartState extends State<WeeklyChart> {
  String child = 'Lia';
  @override
  Widget build(BuildContext context) {
    final values = widget.store.dailyMinutes(child);
    final max = values.fold<int>(1, (a, b) => a > b ? a : b);
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Minutos aprovados na semana',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: navy)),
                DropdownButton<String>(
                    value: child,
                    items: widget.store.children
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => child = v ?? child))
              ]),
              const SizedBox(height: 12),
              SizedBox(
                  height: 150,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: values
                          .asMap()
                          .entries
                          .map((e) => Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('${e.value}'),
                                    const SizedBox(height: 4),
                                    Container(
                                        width: 24,
                                        height: 100 * e.value / max,
                                        decoration: BoxDecoration(
                                            color: purple,
                                            borderRadius:
                                                BorderRadius.circular(6))),
                                    const SizedBox(height: 4),
                                    Text([
                                      'S',
                                      'T',
                                      'Q',
                                      'Q',
                                      'S',
                                      'S',
                                      'D'
                                    ][e.key])
                                  ]))
                          .toList()))
            ])));
  }
}

class ChildView extends StatelessWidget {
  const ChildView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) {
    final child = store.currentChild;
    final minutes = store.approvedMinutes(child);
    final progress = (minutes / store.weeklyGoal).clamp(0, 1).toDouble();
    return ListView(padding: const EdgeInsets.all(20), children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Olá, $child!',
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900, color: navy)),
              const SizedBox(height: 4),
              const Text('Este é o seu espaço de leitura.',
                  style: TextStyle(fontSize: 16, color: Colors.black54))
            ]),
            Chip(
                avatar: const Icon(Icons.lock_outline, size: 17),
                label: Text('Perfil de $child'))
          ]),
      const SizedBox(height: 20),
      _hero(context, minutes, progress),
      const SizedBox(height: 16),
      Row(children: [
        _stat(Icons.local_fire_department, '3 dias', 'streak', Colors.orange),
        const SizedBox(width: 12),
        _stat(Icons.emoji_events, '#${store.rank(child)}', 'ranking semanal',
            purple),
        const SizedBox(width: 12),
        _stat(
            Icons.videogame_asset,
            '${(minutes / store.weeklyGoal * store.rewardRatio).floor()}h',
            'liberadas',
            mint)
      ]),
      const SizedBox(height: 18),
      Card(
          elevation: 0,
          color: const Color(0xFFFFF7ED),
          child: ListTile(
              leading: const Text('🔥', style: TextStyle(fontSize: 28)),
              title: Text(
                  store.streak(child) > 0
                      ? '${store.streak(child)} dias seguidos'
                      : 'Comece uma nova sequência hoje!',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: navy)),
              subtitle: const Text('Sua sequência de leitura'))),
      const SizedBox(height: 10),
      OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => HouseRulesView(store: store))),
          icon: const Icon(Icons.home_work_outlined),
          label: const Text('Regras da casa')),
      const SizedBox(height: 18),
      const Text('Suas últimas leituras',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
      const SizedBox(height: 8),
      ...store.sessions
          .where((s) => s.child == child)
          .take(4)
          .map((s) => _sessionTile(context, s)),
      const SizedBox(height: 24),
      _podium(context)
    ]);
  }

  Widget _hero(BuildContext context, int minutes, double progress) {
    return Card(
      color: const Color(0xFFEDE9FE),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meta da semana',
                      style:
                          TextStyle(color: navy, fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text('60 minutos = 2h de diversão',
                      style: TextStyle(color: Colors.black54)),
                ]),
            CircleAvatar(
                radius: 28,
                backgroundColor: yellow,
                child: const Text('📚', style: TextStyle(fontSize: 26))),
          ]),
          const SizedBox(height: 18),
          Text('$minutes / ${store.weeklyGoal} min',
              style: const TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, color: navy)),
          const SizedBox(height: 8),
          ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                  minHeight: 14,
                  value: progress,
                  color: mint,
                  backgroundColor: Colors.white)),
          const SizedBox(height: 18),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: purple,
                    padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () => _timerSheet(context),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Começar a ler',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              )),
          const SizedBox(height: 8),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                  onPressed: () => _manualSheet(context),
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Registrar leitura manualmente'))),
        ]),
      ),
    );
  }

  Widget _stat(IconData icon, String value, String label, Color color) =>
      Expanded(
          child: Card(
              elevation: 0,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: navy)),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black54))
                  ]))));
  Widget _sessionTile(BuildContext context, Session s) => Card(
      elevation: 0,
      child: ListTile(
          leading: CircleAvatar(
              backgroundColor: s.approved
                  ? const Color(0xFFD1FAE5)
                  : (s.rejected
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFFEF3C7)),
              child:
                  Icon(s.approved ? Icons.check : (s.rejected ? Icons.close : Icons.hourglass_top),
                      color: s.approved
                          ? mint
                          : (s.rejected ? Colors.red : Colors.orange))),
          title: Text('${s.minutes} min • ${DateFormat('dd/MM').format(s.date)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.summary, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            _originBadge(s),
          ]),
          trailing: s.rejected
              ? TextButton(
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                              title: const Text('Justificativa da rejeição'),
                              content:
                                  Text(s.rejectionReason ?? 'Sem justificativa.'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Fechar'))
                              ])),
                  child: const Text('Ver justificativa'))
              : Text(s.approved ? 'Aprovada' : 'Pendente',
                  style: TextStyle(color: s.approved ? mint : Colors.orange, fontWeight: FontWeight.bold))));
  Widget _originBadge(Session s) => Chip(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      avatar: Icon(s.isManual ? Icons.edit_note : Icons.timer_outlined,
          size: 15, color: s.isManual ? purple : mint),
      label: Text(s.isManual ? 'Registro manual' : 'Cronômetro',
          style: TextStyle(fontSize: 11, color: s.isManual ? purple : mint)));
  Widget _podium(BuildContext context) {
    final sorted = [...store.children]..sort(
        (a, b) => store.approvedMinutes(b).compareTo(store.approvedMinutes(a)));
    return Card(
        elevation: 0,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ranking semanal',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: navy)),
              const SizedBox(height: 10),
              ...sorted.asMap().entries.map((e) => ListTile(
                  dense: true,
                  leading: Text(['🥇', '🥈', '🥉'][e.key],
                      style: const TextStyle(fontSize: 24)),
                  title: Text(e.value),
                  trailing: Text('${store.approvedMinutes(e.value)} min',
                      style: const TextStyle(fontWeight: FontWeight.bold))))
            ])));
  }

  void _timerSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => AnimatedBuilder(
            animation: store,
            builder: (_, __) {
              final sec = store.timerSeconds ?? 0;
              return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Momento de leitura',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: navy)),
                    const SizedBox(height: 18),
                    Text(
                        '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            color: purple)),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      FilledButton.icon(
                          onPressed: store.running
                              ? store.pauseTimer
                              : store.startTimer,
                          icon: Icon(
                              store.running ? Icons.pause : Icons.play_arrow),
                          label: Text(store.running
                              ? 'Pausar'
                              : (sec == 0 ? 'Iniciar' : 'Retomar'))),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                          onPressed: sec < 1
                              ? null
                              : () {
                                  final elapsed = sec;
                                  store.stopTimer();
                                  Navigator.pop(context);
                                  _proofSheet(context, (elapsed / 60).ceil(),
                                      origin: 'cronometro');
                                },
                          icon: const Icon(Icons.stop),
                          label: const Text('Finalizar'))
                    ])
                  ]));
            }));
  }

  void _manualSheet(BuildContext context) {
    final min = TextEditingController();
    final summary = TextEditingController();
    Uint8List? photoBytes;
    String? photoName;
    bool picking = false;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(builder: (context, set) {
              Future<void> pickPhoto(ImageSource source) async {
                if (kIsWeb && source == ImageSource.camera) return;
                set(() => picking = true);
                final file = await ImagePicker().pickImage(
                    source: source,
                    imageQuality: 75,
                    maxWidth: 1600,
                    maxHeight: 1600);
                if (file != null) {
                  final bytes = await file.readAsBytes();
                  if (bytes.length > 5 * 1024 * 1024) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'A foto ultrapassa 5 MB mesmo após compressão. Escolha uma imagem menor.')));
                    }
                  } else {
                    set(() {
                      photoBytes = bytes;
                      photoName = file.name;
                    });
                  }
                }
                set(() => picking = false);
              }

              final canSubmit = (int.tryParse(min.text) ?? 0) > 0 &&
                  (summary.text.trim().length >= 20 || photoBytes != null);
              return Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Registrar leitura manual',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: navy)),
                        const SizedBox(height: 8),
                        const Text(
                            'Adicione um resumo com pelo menos 20 caracteres ou uma foto. O PIN não é pedido nesta etapa.'),
                        const SizedBox(height: 16),
                        TextField(
                            controller: min,
                            keyboardType: TextInputType.number,
                            onChanged: (_) => set(() {}),
                            decoration: const InputDecoration(
                                labelText: 'Duração em minutos',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 12),
                        TextField(
                            controller: summary,
                            minLines: 3,
                            maxLines: 5,
                            onChanged: (_) => set(() {}),
                            decoration: const InputDecoration(
                                labelText:
                                    'O que foi lido? (opcional se houver foto)',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 14),
                        if (photoBytes != null) ...[
                          ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(photoBytes!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true)),
                          const SizedBox(height: 6),
                          Row(children: [
                            Expanded(
                                child: Text(photoName ?? 'Foto anexada',
                                    overflow: TextOverflow.ellipsis)),
                            TextButton.icon(
                                onPressed: () => set(() {
                                      photoBytes = null;
                                      photoName = null;
                                    }),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remover'))
                          ]),
                        ] else ...[
                          SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                  onPressed: picking
                                      ? null
                                      : () => showModalBottomSheet(
                                          context: context,
                                          builder: (_) => SafeArea(
                                                  child: Wrap(children: [
                                                if (!kIsWeb)
                                                  ListTile(
                                                      leading: const Icon(
                                                          Icons.camera_alt),
                                                      title: const Text(
                                                          'Tirar foto'),
                                                      onTap: () {
                                                        Navigator.pop(context);
                                                        pickPhoto(
                                                            ImageSource.camera);
                                                      }),
                                                ListTile(
                                                    leading: const Icon(
                                                        Icons.photo_library),
                                                    title: const Text(
                                                        'Escolher da galeria'),
                                                    onTap: () {
                                                      Navigator.pop(context);
                                                      pickPhoto(
                                                          ImageSource.gallery);
                                                    })
                                              ]))),
                                  icon: const Icon(Icons.attach_file),
                                  label: Text(picking
                                      ? 'Processando foto...'
                                      : 'Anexar foto (máx. 5 MB)'))),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                                onPressed: canSubmit
                                    ? () {
                                        store.addSession(
                                            minutes: int.parse(min.text),
                                            summary: summary.text.trim().isEmpty
                                                ? 'Comprovação por foto anexada.'
                                                : summary.text.trim(),
                                            photo: photoName,
                                            photoBytes: photoBytes,
                                            origin: 'manual');
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Leitura enviada para aprovação!')));
                                      }
                                    : null,
                                icon: const Icon(Icons.send),
                                label: const Text('Enviar para aprovação'))),
                      ])));
            }));
  }

  void _proofSheet(BuildContext context, int minutes,
      {String? summary, String origin = 'manual'}) {
    final c = TextEditingController(text: summary);
    String? photo;
    Uint8List? photoBytes;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(
            builder: (context, set) => Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Comprovação • $minutes min',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: navy)),
                        const SizedBox(height: 8),
                        const Text(
                            'Escreva pelo menos 20 caracteres ou anexe uma foto.'),
                        const SizedBox(height: 16),
                        TextField(
                            controller: c,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                                labelText: 'O que você leu?',
                                border: OutlineInputBorder())),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                            onPressed: () async {
                              final file = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80);
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                set(() {
                                  photo = file.name;
                                  photoBytes = bytes;
                                });
                              }
                            },
                            icon: const Icon(Icons.photo_camera),
                            label: Text(photo == null
                                ? 'Adicionar foto'
                                : 'Foto: $photo')),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                                onPressed:
                                    c.text.trim().length < 20 && photo == null
                                        ? null
                                        : () {
                                            store.addSession(
                                                minutes: minutes,
                                                summary: c.text.trim().isEmpty
                                                    ? 'Comprovação por foto anexada.'
                                                    : c.text.trim(),
                                                photo: photo,
                                                photoBytes: photoBytes,
                                                origin: origin);
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Leitura enviada para aprovação!')));
                                          },
                                child: const Text('Enviar comprovação'))),
                      ]),
                )));
  }
}

class _PhotoPreview extends StatefulWidget {
  const _PhotoPreview({this.bytes, this.fileName, required this.onRetry});
  final Uint8List? bytes;
  final String? fileName;
  final VoidCallback onRetry;
  @override
  State<_PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends State<_PhotoPreview> {
  bool failed = false;
  void _openFullscreen(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(children: [
              Center(
                  child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 5,
                      child: Image.memory(widget.bytes!, fit: BoxFit.contain))),
              SafeArea(
                  child: Align(
                      alignment: Alignment.topRight,
                      child: IconButton.filled(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white24,
                              foregroundColor: Colors.white)))),
            ])));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.bytes == null || failed) {
      return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          color: const Color(0xFFF1F5F9),
          child: Column(children: [
            const Icon(Icons.broken_image_outlined,
                size: 52, color: Colors.orange),
            const SizedBox(height: 8),
            Text(failed
                ? 'Não foi possível carregar a foto.'
                : 'A foto está indisponível offline.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: () {
                  setState(() => failed = false);
                  widget.onRetry();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'))
          ]));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
          height: 280,
          width: double.infinity,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(widget.bytes!,
                  fit: BoxFit.contain,
                  gaplessPlayback: true, errorBuilder: (_, __, ___) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => failed = true);
                });
                return const SizedBox.shrink();
              }))),
      const SizedBox(height: 8),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
              onPressed: () => _openFullscreen(context),
              icon: const Icon(Icons.zoom_in),
              label: const Text('Abrir foto em tela cheia'))),
    ]);
  }
}

class ResponsibleView extends StatelessWidget {
  const ResponsibleView({super.key, required this.store});
  final DemoStore store;
  @override
  Widget build(BuildContext context) {
    final total = store.children
        .fold<int>(0, (sum, child) => sum + store.approvedMinutes(child));
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Painel do responsável',
          style: TextStyle(
              fontSize: 30, fontWeight: FontWeight.w900, color: navy)),
      const Text('Acompanhe e aprove as leituras da turma.',
          style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 24),
      Row(children: [
        _card(Icons.pending_actions, '${store.pending.length}', 'pendentes',
            Colors.orange),
        const SizedBox(width: 12),
        _card(Icons.timer, '$total', 'min aprovados', mint),
        const SizedBox(width: 12),
        _card(Icons.groups, '${store.children.length}', 'crianças', purple)
      ]),
      const SizedBox(height: 18),
      WeeklyChart(store: store),
      const SizedBox(height: 12),
      FilledButton.icon(
          onPressed: () => _exportReport(context),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Exportar relatório do mês')),
      const SizedBox(height: 24),
      Card(
          elevation: 0,
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Comprovações pendentes',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: navy)),
                    const SizedBox(height: 10),
                    if (store.pending.isEmpty)
                      const Text(
                          'Tudo em dia! Nenhuma leitura aguardando aprovação.'),
                    ...store.pending.map((s) => _pending(context, s)),
                  ]))),
      const SizedBox(height: 18),
      Card(
          elevation: 0,
          child: ListTile(
              leading: const Icon(Icons.tune, color: purple),
              title: const Text('Meta semanal'),
              subtitle: Text(
                  '${store.weeklyGoal} min → ${store.rewardRatio.toStringAsFixed(0)}h liberadas'),
              trailing: IconButton(
                  onPressed: () => _config(context),
                  icon: const Icon(Icons.edit)))),
    ]);
  }

  Widget _card(IconData icon, String value, String label, Color color) =>
      Expanded(
          child: Card(
              elevation: 0,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Icon(icon, color: color),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: navy)),
                    Text(label, style: const TextStyle(fontSize: 11))
                  ]))));
  Widget _pending(BuildContext context, Session s) => Card(
      color: const Color(0xFFFFFBEB),
      child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showDetails(context, s),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                CircleAvatar(
                    backgroundColor: store.colors[s.child],
                    child: Text(s.child[0])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${s.child} • ${s.minutes} minutos',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(s.summary,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      _originBadge(s),
                      Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.auto_awesome, size: 15),
                          label: Text(store.multiplierFor(s).label)),
                      TextButton.icon(
                          onPressed: () => _showDetails(context, s),
                          icon: const Icon(Icons.visibility_outlined, size: 17),
                          label: const Text('Ver detalhes')),
                    ])),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      tooltip: 'Rejeitar',
                      onPressed: () => _rejectWithReason(context, s),
                      icon: const Icon(Icons.close, color: Colors.red)),
                  IconButton(
                      tooltip: 'Aprovar com PIN',
                      onPressed: () => _approveWithPin(context, s),
                      icon: const Icon(Icons.check_circle, color: mint)),
                ]),
              ]))));
  void _showDetails(BuildContext context, Session s) {
    showDialog(
        context: context,
        builder: (_) => Dialog(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text('Detalhes da leitura',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        color: navy,
                                        fontWeight: FontWeight.bold))),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))
                      ]),
                      Text(
                          '${s.child} • ${s.minutes} min • ${DateFormat('dd/MM/yyyy').format(s.date)}'),
                      const SizedBox(height: 8),
                      _originBadge(s),
                      const SizedBox(height: 12),
                      Text(s.summary, style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 16),
                      if (s.photoBytes != null || s.photoName != null)
                        _PhotoPreview(
                            bytes: s.photoBytes,
                            fileName: s.photoName,
                            onRetry: () {}),
                      if (s.photoBytes == null && s.photoName == null)
                        const Text('Nenhuma foto anexada.',
                            style: TextStyle(color: Colors.black54)),
                    ])),
              ),
            )));
  }

  void _rejectWithReason(BuildContext context, Session session) {
    final reason = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Justificar rejeição'),
                content: TextField(
                    controller: reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Motivo (mín. 10 caracteres)',
                        border: OutlineInputBorder())),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        if (reason.text.trim().length >= 10) {
                          store.approve(session, false,
                              reason: reason.text.trim());
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Rejeitar'))
                ]));
  }

  void _approveWithPin(BuildContext context, Session session) {
    final pin = TextEditingController();
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Validar leitura'),
                content: TextField(
                    controller: pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'PIN do responsável',
                        hintText: 'Demonstração: 2468')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar')),
                  FilledButton(
                      onPressed: () {
                        if (pin.text == '2468') {
                          store.approve(session, true);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Aprovar'))
                ]));
  }

  Widget _originBadge(Session s) => Chip(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      avatar: Icon(s.isManual ? Icons.edit_note : Icons.timer_outlined,
          size: 15, color: s.isManual ? purple : mint),
      label: Text(s.isManual ? 'Registro manual' : 'Cronômetro',
          style: TextStyle(fontSize: 11, color: s.isManual ? purple : mint)));
  Future<void> _exportReport(BuildContext context) async {
    int month = DateTime.now().month;
    int year = DateTime.now().year;
    String selected = 'Todas';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (context, set) => AlertDialog(
                    title: const Text('Relatório mensal'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          value: month,
                          decoration: const InputDecoration(labelText: 'Mês'),
                          items: List.generate(
                              12,
                              (i) => DropdownMenuItem(
                                  value: i + 1,
                                  child: Text(DateFormat.MMMM('pt_BR')
                                      .format(DateTime(2024, i + 1))))),
                          onChanged: (v) => set(() => month = v ?? month)),
                      DropdownButtonFormField<String>(
                          value: selected,
                          decoration:
                              const InputDecoration(labelText: 'Criança'),
                          items: ['Todas', ...store.children]
                              .map((c) =>
                                  DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) => set(() => selected = v ?? selected))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Gerar PDF'))
                    ])));
    if (confirmed != true || !context.mounted) return;
    final chosen = selected == 'Todas' ? store.children : [selected];
    final document = pw.Document();
    final monthSessions = store.sessions
        .where((s) =>
            chosen.contains(s.child) &&
            s.date.year == year &&
            s.date.month == month)
        .toList();
    document.addPage(pw.MultiPage(
        build: (_) => [
              pw.Header(
                  level: 0,
                  child: pw.Text(
                      'LeitorKids — Relatório de ${DateFormat('MMMM yyyy', 'pt_BR').format(DateTime(year, month))}')),
              pw.Text('Criança(s): $selected'),
              pw.SizedBox(height: 12),
              ...chosen.map((child) {
                final list =
                    monthSessions.where((s) => s.child == child).toList();
                final approved = list.where((s) => s.approved).toList();
                final rejected = list.where((s) => s.rejected).length;
                final minutes = approved.fold(0, (a, s) => a + s.minutes);
                final activeDays = approved
                    .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
                    .toSet()
                    .length;
                final maxStreak = _maxStreak(approved);
                final medals = approved.where((s) => s.minutes >= 30).length;
                return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Header(level: 1, child: pw.Text(child)),
                      pw.Text(
                          'Minutos aprovados: $minutes | Sessões aprovadas: ${approved.length} | Rejeitadas: $rejected'),
                      pw.Text(
                          'Medalhas conquistadas: $medals | Streak máximo: $maxStreak dias | Média diária: ${activeDays == 0 ? 0 : (minutes / activeDays).toStringAsFixed(1)} min'),
                      pw.SizedBox(height: 6),
                      pw.Text('Resumos:'),
                      ...list.where((s) => s.summary.trim().isNotEmpty).map(
                          (s) => pw.Bullet(
                              text:
                                  '${DateFormat('dd/MM').format(s.date)} — ${s.summary}')),
                      pw.SizedBox(height: 16)
                    ]);
              }),
            ]));
    final bytes = Uint8List.fromList(await document.save());
    final filename =
        'leitorkids-relatorio-$year-${month.toString().padLeft(2, '0')}.pdf';
    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await Share.shareXFiles(
          [XFile.fromData(bytes, name: filename, mimeType: 'application/pdf')],
          subject: 'Relatório LeitorKids');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Relatório gerado com sucesso.')));
    }
  }

  int _maxStreak(List<Session> list) {
    final days = list
        .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
        .toSet()
        .toList()
      ..sort();
    int best = 0, current = 0;
    DateTime? previous;
    for (final day in days) {
      if (previous != null && day.difference(previous).inDays == 1) {
        current++;
      } else {
        current = 1;
      }
      if (current > best) best = current;
      previous = day;
    }
    return best;
  }

  void _config(BuildContext context) {
    final c = TextEditingController(text: store.weeklyGoal.toString());
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
                title: const Text('Configurar meta'),
                content: TextField(
                    controller: c,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Minutos por semana')),
                actions: [
                  FilledButton(
                      onPressed: () {
                        store.weeklyGoal = int.tryParse(c.text) ?? 60;
                        Navigator.pop(context);
                      },
                      child: const Text('Salvar'))
                ]));
  }
}
