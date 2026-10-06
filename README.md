# CargaCerta AR

Planejamento inteligente de mudanças: o usuário aponta a câmera, mede os móveis,
classifica cada um e recebe **volume estimado, veículo sugerido, ordem de
carregamento e alertas**. Um único código Flutter para Android, iOS e Web
(responsivo: barra inferior no celular, trilho lateral em telas largas).

Baseado no mini projeto e no infográfico "Como o CargaCerta AR funciona".

| Etapa do infográfico | Onde está |
|---|---|
| 1 Calibrar | `ui/pages/calibrate_page.dart`, `domain/calibration.dart` |
| 2 Mapear e selecionar | `ui/pages/map_page.dart`, `furniture_editor_page.dart`, `measure_screen.dart` |
| 3 Classificar | `ui/pages/classify_page.dart` (desmontável, frágil, macio, pesado, empilhável, orientação) |
| 4 Recomendar | `ui/pages/recommend_page.dart`, `domain/plan.dart`, `domain/load_planner.dart` |

O botão **Carregar exemplo** (etapa 2) recria o cenário do infográfico:
~8,6 m³ de capacidade mínima e **Caminhão 3/4** como veículo sugerido.

## Como a medição funciona (importante)

Esta versão usa o modo de **calibração manual por referência**, que o próprio PDF
prevê como alternativa ao rastreamento de planos/profundidade:

1. tira a foto (fica só em memória);
2. você marca as duas pontas de um objeto de tamanho conhecido (porta, folha A4, cartão, trena);
3. o app calcula pixels por metro e mede qualquer segmento **no mesmo plano**.

Limite físico: o erro cresce se o móvel estiver mais perto/longe da câmera que a
referência, ou se o celular estiver inclinado. O app avisa quando a referência
ocupa pouco da foto. **Não é AR com rastreamento (ARCore/ARKit)** e não mede
profundidade; isso exige código nativo e não existe no navegador (ver Roadmap).
Toda medida pode ser digitada ou corrigida manualmente.

## Rodar

```bash
# 1) Gera as pastas nativas que faltam (android/, ios/, web/) sem tocar em lib/
git init && git add -A && git commit -m "base"   # recomendado antes do create
flutter create --platforms=android,ios,web --project-name cargacerta_ar --org br.com.cargacerta .

# Se o create sobrescrever algo (ex.: test/widget_test.dart), restaure: git checkout -- lib test pubspec.yaml
flutter pub get
flutter test                      # testes de domínio (volume, empacotamento, validação)
flutter run -d chrome             # demo web (localhost conta como contexto seguro)
flutter run                       # celular conectado
```

## Publicar o link de demonstração (GitHub Pages)

A câmera no navegador **exige HTTPS**; o GitHub Pages já entrega HTTPS.

1. Crie um repositório no GitHub e envie este projeto para a branch `main`.
2. No repositório: **Settings → Pages → Source: GitHub Actions**.
3. O workflow `.github/workflows/deploy-web.yml` roda análise + testes, gera o build
   web e publica em `https://SEU-USUARIO.github.io/NOME-DO-REPO/`.
4. Abra o link no celular e permita a câmera.

Alternativas com cabeçalhos de segurança de verdade (CSP, Permissions-Policy):
**Netlify** ou **Cloudflare Pages** (`flutter build web --release --no-web-resources-cdn`
e publique `build/web`; o arquivo `web/_headers` já vai junto).

## Configuração nativa da câmera

**Android** (`android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<application
    android:allowBackup="false"
    android:usesCleartextTraffic="false" ...>
```

`android/app/build.gradle(.kts)`: `minSdk = 21` (ou superior).

**iOS** (`ios/Runner/Info.plist`):

```xml
<key>NSCameraUsageDescription</key>
<string>A câmera é usada para medir seus móveis. As fotos não saem do aparelho.</string>
```

Não declare permissão de microfone nem de rede: o app não usa nenhuma das duas.

## Builds de produção

```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
flutter build ipa       --release --obfuscate --split-debug-info=build/symbols
flutter build web       --release --no-web-resources-cdn
```

Guarde `build/symbols` (para ler stack traces) e o keystore **fora** do repositório
(o `.gitignore` já bloqueia `*.jks`, `key.properties` etc.).

## Segurança: o que já está feito

- **Privacidade por padrão:** zero chamadas de rede no código, sem analytics, sem
  microfone (`enableAudio: false`). Fotos só em memória; na versão nativa o arquivo
  temporário da câmera é apagado logo após a leitura; a câmera é liberada quando o
  app sai de cena.
- **Validação de toda entrada** (`core/validators.dart`): números só com dígitos,
  intervalos fixos, nomes sem caracteres de controle/direção, limites de itens e unidades.
- **Armazenamento local desconfiado:** o JSON salvo é revalidado campo a campo ao
  carregar (tamanho máximo, versão, tipos, faixas); registro adulterado é descartado.
  Botão **Apagar dados** limpa tudo do aparelho.
- **Poucas dependências** (`camera`, `shared_preferences`), formatação sem `intl`,
  Dependabot semanal para pub e GitHub Actions.
- **Web:** `Permissions-Policy` (só câmera), `nosniff`, `no-referrer`, anti-iframe e
  CSP em `web/_headers`; build sem CDN (nada de scripts de terceiros em runtime).
- **Erros contidos:** handler global sem expor stack trace em produção.

## Segurança: pendências antes de lançar de verdade

- Trocar a CSP de `Report-Only` para enforcement depois de checar o console.
- Fixar as Actions por SHA de commit e travar `pubspec.lock` no repositório.
- Se passar a haver login, backend ou orçamentos na nuvem: TLS com pinning opcional,
  tokens em `flutter_secure_storage`, rate limit e revisão de LGPD (consentimento,
  retenção, direito de exclusão). Hoje não há dados pessoais, só medidas de móveis.
- O armazenamento local **não é criptografado** (na web fica em `localStorage`). Não
  guarde endereços, nomes ou fotos sem antes criptografar.
- Teste em aparelhos reais (permissão negada, câmera ocupada, rotação, iOS Safari).

## Estrutura

```
lib/
  core/      formatação pt-BR, validação, limpeza de temporários
  domain/    Dart puro e testável: móveis, peças, volume, calibração,
             empacotamento 3D, recomendação de veículo, alertas
  data/      repositório local (validado) com interface trocável
  state/     AppState (ChangeNotifier) + cache de empacotamento
  ui/        tema (paleta do infográfico), páginas das 4 etapas, câmera, desenho 3D
test/        validação, calibração, volume, serialização, empacotador
```

### Regras da carga (empacotador 3D)

Pesado só no piso e carregado primeiro · frágil e peças sem “empilhável” não recebem
nada por cima · macio aceita só carga leve (até 15 kg) · nada mais pesado sobre algo mais
leve · “orientação”, frágil e pesado nunca são deitados · desmontável vira duas peças
(maior lado ao meio) · essenciais são carregados primeiro · apoio mínimo de 80% da base.
A ordem de carregamento é a ordem de posicionamento. O resultado considera a melhor de
4 estratégias de ordenação/inclinação.

## Frota e valores

`domain/vehicle.dart` traz uma frota **ilustrativa** (Utilitário, Van, Caminhão 3/4,
toco, truck). Substitua pelas medidas internas e cargas úteis reais da transportadora.
A reserva (padrão 20%) é ajustável na etapa 4.

## Roadmap: AR nativo de verdade

1. Definir uma interface `MeasurementEngine` (hoje a lógica está em `measure_screen.dart`).
2. Android: ARCore (planos + Depth API); iOS: ARKit/RealityKit (LiDAR quando houver),
   via plugin mantido ou *platform channel*. Avaliar a manutenção de cada plugin.
3. Manter a calibração por referência como plano B (e como único modo na web).
4. Detecção automática de móveis (modelo on-device) para pré-selecionar caixas.
5. Cadastro de veículos e orçamento via API autenticada.

## Limitações conhecidas

- Não foi possível compilar nem rodar `flutter analyze`/`flutter test` no ambiente em
  que este código foi escrito (sem SDK). A lógica de empacotamento foi validada em um
  protótipo equivalente (6.000 cenários aleatórios) e portada; rode os testes localmente
  e corrija qualquer ajuste de versão do Flutter/pacotes.
- Fonte padrão do Material. Para usar a tipografia do infográfico, adicione uma fonte em
  `assets/fonts` e declare no `pubspec.yaml` (bundlada, sem Google Fonts em runtime).
- Sem modo escuro.
