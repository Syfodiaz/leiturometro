# LeitorKids

MVP Flutter multiplataforma para incentivar crianças de 8 a 14 anos a lerem. O mesmo código gera Android e Web; o painel responsivo do responsável funciona melhor em desktop.

## Estado do MVP

Inclui login/seleção de perfil em modo demonstração, cronômetro, registro manual sem PIN, comprovação por resumo/foto, aprovação do responsável com PIN, meta semanal, horas liberadas e ranking. O PIN de demonstração é **2468** e é solicitado somente ao aprovar uma sessão no painel do responsável. A camada visual está pronta para receber Firebase; o modo demo é offline e permite testar o fluxo sem credenciais.

> O cronômetro demo tem os controles Iniciar, Pausar/Retomar e Finalizar; o tempo pausado não é contabilizado. Para produção Android, conecte um foreground service nativo (por exemplo, `flutter_foreground_task`) e configure as permissões de notificação/serviço no AndroidManifest.

## Rodar localmente

```bash
flutter pub get
flutter run -d chrome
flutter build web --release --base-href /NOME_DO_REPO/
flutter build apk --release
```

O APK fica em `build/app/outputs/flutter-apk/app-release.apk`; a Web fica em `build/web`.


### Anexo no registro manual

O registro manual possui o botão **Anexar foto**. No Android, a criança pode tirar uma foto ou escolher uma imagem da galeria; na Web, apenas a galeria/upload de arquivo é exibida. A prévia permite trocar ou remover a foto antes do envio. O arquivo é redimensionado/comprimido (`imageQuality: 75`, até 1600 px) e rejeitado se permanecer acima de 5 MB. A sessão é enviada para aprovação com os bytes da foto; após configurar `firebase_options.dart`, o adaptador de produção deve persistir esses bytes em `Firebase Storage` sob `proofs/{childUid}/{fileName}`.

### Visualização de comprovações

No painel do responsável, clique no cartão pendente ou em **Ver detalhes** para abrir o resumo e a foto. O botão **Abrir foto em tela cheia** permite zoom por gesto/roda do mouse e fechamento pelo botão superior. Se a imagem não estiver disponível, o cartão mostra erro e **Tentar novamente**. As imagens selecionadas no MVP são lidas como bytes e reutilizadas pelo cache de imagens do Flutter; na integração Firebase, grave os bytes no Storage e carregue-os por URL autenticada.

## Fase 1 — Engajamento e gestão

A versão atual inclui: rejeição de sessões com justificativa obrigatória de pelo menos 10 caracteres; histórico infantil com botão **Ver justificativa**; sininho de notificações internas com badge e marcação como lida; streak de leitura; tela **Regras da casa** com meta, recompensa e combinados familiares; e gráfico semanal de minutos aprovados por criança.

As regras do Firestore rejeitam atualizações sem `rejectionReason` válido. Notificações persistidas devem usar a coleção `notifications`, com `childUid`, `type`, `message`, `createdAt` e `read`. O push diário das 19h e os recursos Blaze permanecem planejados para a Fase 2.

## Relatório mensal e multiplicadores

O painel do responsável tem **Exportar relatório do mês**. O responsável escolhe o mês e uma criança ou todas. O PDF inclui minutos aprovados, sessões aprovadas/rejeitadas, medalhas, streak máximo, média diária e resumos. No Android ele abre o compartilhamento nativo via `share_plus`; na Web o arquivo é baixado diretamente. A geração acontece no cliente com `pdf`, sem backend.

A pontuação usa sempre o maior multiplicador aplicável: qualidade (`1.5`), Ler Junto (`1.2`) ou férias (`2.0`). Os campos genéricos `joinedValid` e `inVacation` já existem na sessão para receber as futuras features. Em produção, configure `config/multiplicadores` com, por exemplo:

```json
{"qualidade": 1.5, "lerJunto": 1.2, "ferias": 2.0}
```

A sessão mostra o fator aplicado no cartão de aprovação, como `2x — férias`. Os multiplicadores não são somados.

## Firebase

1. Crie um projeto no Firebase e ative Authentication (e-mail/senha), Firestore e Storage.
2. Instale o FlutterFire CLI e rode `flutterfire configure` na raiz do app. Isso substitui `lib/firebase_options.dart`.
3. Coloque `google-services.json` em `android/app/` quando o FlutterFire solicitar.
4. Atualize o código para inicializar Firebase antes do `runApp` e altere o repositório demo por chamadas a `FirebaseAuth`, `Firestore` e `FirebaseStorage`.
5. Publique regras:

```bash
firebase deploy --only firestore:rules,storage
```

Coleções previstas: `users`, `sessions`, `rewards`, `config`. A aprovação só pode ser feita por `role: responsavel`; o hash do PIN fica em `users/{responsavelUid}/private/pin` e nunca é lido pelo cliente criança.

## Cloud Functions e plano

`functions/` contém `validatePin`, que compara SHA-256 no servidor com `timingSafeEqual`. Cloud Functions exige o plano **Blaze** para implantação, embora possa ficar dentro da franquia sem custo. No Spark, use como alternativa a confirmação autenticada do responsável e não valide PIN no cliente.

```bash
cd functions && npm install
firebase deploy --only functions:validatePin
```

## GitHub Pages

O workflow `.github/workflows/deploy.yml` compila a Web a cada push em `main`, define automaticamente `--base-href "/nome-do-repositorio/"` e publica em GitHub Pages. No repositório, ative Pages com **GitHub Actions** como origem.

## Configuração do adulto

Após ligar o Firebase, crie um usuário responsável, grave `role: responsavel` em `users`, cadastre crianças com `role: crianca` e `responsavelUid`, e salve a política em `config/main`:

```json
{"weeklyGoalMinutes": 60, "rewardHours": 2, "timezone": "America/Sao_Paulo"}
```

Para trocar a proporção, altere esses campos. O reset semanal deve usar uma Cloud Scheduler/Function em horário de Brasília; a implementação demo mantém o histórico.

## Privacidade

Sem anúncios. Fotos devem ser comprimidas, limitadas a 5 MB e gravadas em Storage privado. Colete apenas o necessário para autenticação, leitura e aprovação. Antes de produção, adicione política de privacidade e consentimento do responsável legal.
