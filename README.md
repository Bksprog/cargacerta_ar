# CargaCerta AR

Aplicação desenvolvida em **Flutter e Dart** para auxiliar no planejamento e organização de cargas em veículos.

O CargaCerta AR permite cadastrar veículos e objetos, realizar medições e calibrações por imagem e gerar uma sugestão de organização da carga, buscando aproveitar melhor o espaço disponível.

> **Status:** Em desenvolvimento

---

## Demonstração

**Aplicação Web:**  
https://bksprog.github.io/cargacerta_ar/

> A versão atual utiliza recursos de medição e calibração por imagem. O projeto não utiliza ARCore/ARKit nativamente neste momento.

---

## Funcionalidades

- Cadastro e gerenciamento de veículos
- Cadastro de móveis e objetos
- Cadastro de peças e dimensões
- Medição por imagem
- Calibração utilizando objetos de referência
- Classificação de objetos
- Estimativa de dimensões
- Planejamento da distribuição da carga
- Visualização da disposição dos objetos
- Recomendações para organização da carga
- Validação de dados
- Persistência de informações
- Interface responsiva para Web

---

## Tecnologias

- **Flutter**
- **Dart**
- **Material Design**
- **Git**
- **GitHub Actions**
- **GitHub Pages**

---

## Estrutura do projeto

```text
lib/
├── core/
│   ├── format.dart
│   ├── secure_temp.dart
│   └── validators.dart
│
├── data/
│   └── inventory_repository.dart
│
├── domain/
│   ├── calibration.dart
│   ├── estimate.dart
│   ├── furniture.dart
│   ├── load_planner.dart
│   ├── piece.dart
│   ├── plan.dart
│   ├── presets.dart
│   ├── reference.dart
│   └── vehicle.dart
│
├── state/
│   └── app_state.dart
│
├── ui/
│   ├── pages/
│   ├── widgets/
│   └── theme.dart
│
├── app.dart
└── main.dart

test/
├── calibration_test.dart
├── estimate_test.dart
├── load_planner_test.dart
├── serialization_test.dart
├── validators_test.dart
└── widget_test.dart
```

---

## Como executar

### Pré-requisitos

É necessário ter o Flutter instalado.

Verifique a instalação com:

```bash
flutter --version
```

### Instalação

Clone o repositório:

```bash
git clone https://github.com/Bksprog/cargacerta_ar.git
```

Entre na pasta:

```bash
cd cargacerta_ar
```

Instale as dependências:

```bash
flutter pub get
```

Execute o projeto:

```bash
flutter run
```

Para executar especificamente na Web:

```bash
flutter run -d chrome
```

---

## Testes

O projeto possui testes automatizados para diferentes partes da aplicação.

Para executar todos os testes:

```bash
flutter test
```

Os testes abrangem funcionalidades como:

- Calibração
- Estimativas
- Planejamento de carga
- Serialização
- Validação
- Widgets

---

## Arquitetura

O projeto utiliza uma organização baseada na separação de responsabilidades.

### `core`

Contém funcionalidades compartilhadas e utilitários, como formatação, validações e recursos auxiliares.

### `data`

Responsável pelo acesso e gerenciamento dos dados utilizados pela aplicação.

### `domain`

Contém as principais entidades e regras de negócio do sistema, incluindo veículos, móveis, peças, planos e planejamento de carga.

### `state`

Responsável pelo gerenciamento do estado da aplicação.

### `ui`

Contém as telas, componentes visuais, temas e elementos de interface.

Essa separação facilita a manutenção e evolução do projeto.

---

## Medição e calibração

A aplicação possui um sistema de medição baseado em imagem.

Para realizar uma medição, o usuário pode utilizar um objeto de referência com dimensão conhecida. A partir dessa referência, o sistema realiza a calibração da imagem e utiliza a escala obtida para estimar as dimensões dos objetos.

### Limitações atuais

A precisão das medições depende de fatores como:

- Qualidade da imagem
- Posicionamento da câmera
- Perspectiva
- Iluminação
- Objeto utilizado como referência
- Posicionamento do objeto na imagem

Por esse motivo, os resultados devem ser considerados **estimativas**, especialmente em situações que exigem precisão física.

---

## Planejamento de carga

A aplicação utiliza as dimensões cadastradas dos objetos e do veículo para auxiliar na organização da carga.

O sistema busca encontrar uma disposição adequada dos objetos considerando o espaço disponível e as dimensões informadas.

O planejamento tem como objetivo auxiliar o usuário na tomada de decisão e não substitui uma avaliação profissional para situações que envolvam requisitos técnicos ou de segurança específicos.

---

## Segurança e privacidade

O projeto foi desenvolvido considerando boas práticas para evitar o versionamento de informações sensíveis.

Arquivos como:

```text
.env
*.jks
*.keystore
key.properties
```

são ignorados pelo Git através do `.gitignore`.

Informações sensíveis e credenciais não devem ser adicionadas ao repositório.

---

## CI/CD

O projeto possui configuração de **GitHub Actions** para automatizar o processo de publicação da versão Web.

O workflow está localizado em:

```text
.github/workflows/deploy-web.yml
```

Dessa forma, alterações enviadas ao repositório podem ser utilizadas no processo de atualização da aplicação Web.

---

## Roadmap

Algumas melhorias planejadas para versões futuras:

- [ ] Melhorar a precisão das medições
- [ ] Implementar recursos de AR nativo
- [ ] Melhorar o algoritmo de planejamento de carga
- [ ] Adicionar mais opções de veículos
- [ ] Adicionar mais tipos de objetos
- [ ] Melhorar a visualização 3D
- [ ] Melhorar a experiência do usuário
- [ ] Expandir os testes automatizados
- [ ] Disponibilizar versões para Android e iOS

---

## Objetivo do projeto

O CargaCerta AR foi desenvolvido como um projeto de estudo e aplicação prática de conceitos de **desenvolvimento de software, interfaces, processamento de imagens, modelagem de dados e algoritmos de planejamento**.

O projeto também serve como experiência prática no desenvolvimento de aplicações utilizando Flutter e Dart.

---

## Autor

**Bernardo Knies Soares**

Projeto desenvolvido utilizando **Flutter + Dart**.

---

## Licença

Este projeto é destinado a fins educacionais e de desenvolvimento.