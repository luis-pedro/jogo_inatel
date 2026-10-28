# Jogo Inatel *(nome provisório)*

Jogo 2D de **tower defense baseado em coleta de recursos e expansão de reino**, desenvolvido em **Godot 4.6** para a **FETIN** (Feira Tecnológica do Inatel).

Inspirado em *Kingdoms and Castles* e *Northgard*: o jogador começa com uma casa e dois aldeões, coleta comida, ouro e madeira, expande o reino construindo novas casas e estruturas, recruta unidades para proteger e ampliar o território e defende-se de ondas de inimigos.

> 🚧 Projeto em fase inicial de desenvolvimento.

## Sumário

- [Como rodar](#como-rodar)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Documentação](#documentação)
- [Equipe](#equipe)
- [Créditos](#créditos)

## Como rodar

1. Instale o [Godot 4.6](https://godotengine.org/download) (versão padrão, não a .NET).
2. Clone o repositório:
   ```bash
   git clone https://github.com/luis-pedro/jogo_inatel.git
   ```
3. Abra o Godot, clique em **Importar** e selecione o arquivo `project.godot`.
4. Pressione **F5** para rodar.

## Estrutura do projeto

```
jogo_inatel/
├── assets/            # Sprites do pack Tiny Swords (Pixel Frog)
│   ├── Buildings/     # Construções (5 cores de facção)
│   ├── Particle FX/   # Poeira, explosão, fogo, água
│   ├── Terrain/       # Tileset, decorações e recursos (ouro, carne, madeira)
│   ├── UI Elements/   # Botões, barras, banners, ícones, cursores
│   └── Units/         # Unidades (Pawn, Warrior, Archer, Lancer, Monk)
├── scenes/            # Cenas (.tscn), organizadas por funcionalidade
│   └── main/          # Cena principal
├── scripts/           # Scripts GDScript (.gd)
│   └── autoload/      # Singletons globais (ex.: GameState)
└── docs/              # Documentação do projeto
```

## Documentação

| Documento | Conteúdo |
|---|---|
| [docs/GDD.md](docs/GDD.md) | Game Design Document: conceito, mecânicas, recursos, unidades, inimigos |
| [docs/ARQUITETURA.md](docs/ARQUITETURA.md) | Organização do código, convenções e decisões técnicas |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Fluxo de trabalho com Git, branches, commits e Pull Requests |

## Equipe

| Nome | GitHub |
|---|---|
| Luis Pedro Costa | [@luis-pedro](https://github.com/luis-pedro) |
| *(a definir)* | |

## Créditos

- **Arte:** [Tiny Swords](https://pixelfrog-assets.itch.io/tiny-swords), por **Pixel Frog**.
- **Engine:** [Godot Engine](https://godotengine.org/).
