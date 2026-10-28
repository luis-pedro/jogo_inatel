# Jogo Inatel *(nome provisÃ³rio)*

Jogo 2D de **tower defense baseado em coleta de recursos e expansÃ£o de reino**, desenvolvido em **Godot 4.6** para a **FETIN** (Feira TecnolÃ³gica do Inatel).

Inspirado em *Kingdoms and Castles* e *Northgard*: o jogador comeÃ§a com uma casa e dois aldeÃµes, coleta comida, ouro e madeira, expande o reino construindo novas casas e estruturas, recruta unidades para proteger e ampliar o territÃ³rio e defende-se de ondas de inimigos.

> ðŸš§ Projeto em fase inicial de desenvolvimento.

## SumÃ¡rio

- [Como rodar](#como-rodar)
- [Estrutura do projeto](#estrutura-do-projeto)
- [DocumentaÃ§Ã£o](#documentaÃ§Ã£o)
- [Equipe](#equipe)
- [CrÃ©ditos](#crÃ©ditos)

## Como rodar

1. Instale o [Godot 4.6](https://godotengine.org/download) (versÃ£o padrÃ£o, nÃ£o a .NET).
2. Clone o repositÃ³rio:
   ```bash
   git clone https://github.com/luis-pedro/jogo_inatel.git
   ```
3. Abra o Godot, clique em **Importar** e selecione o arquivo `project.godot`.
4. Pressione **F5** para rodar.

## Estrutura do projeto

```
jogo_inatel/
â”œâ”€â”€ assets/            # Sprites do pack Tiny Swords (Pixel Frog)
â”‚   â”œâ”€â”€ Buildings/     # ConstruÃ§Ãµes (5 cores de facÃ§Ã£o)
â”‚   â”œâ”€â”€ Particle FX/   # Poeira, explosÃ£o, fogo, Ã¡gua
â”‚   â”œâ”€â”€ Terrain/       # Tileset, decoraÃ§Ãµes e recursos (ouro, carne, madeira)
â”‚   â”œâ”€â”€ UI Elements/   # BotÃµes, barras, banners, Ã­cones, cursores
â”‚   â””â”€â”€ Units/         # Unidades (Pawn, Warrior, Archer, Lancer, Monk)
â”œâ”€â”€ scenes/            # Cenas (.tscn), organizadas por funcionalidade
â”‚   â””â”€â”€ main/          # Cena principal
â”œâ”€â”€ scripts/           # Scripts GDScript (.gd)
â”‚   â””â”€â”€ autoload/      # Singletons globais (ex.: GameState)
â””â”€â”€ docs/              # DocumentaÃ§Ã£o do projeto
```

## DocumentaÃ§Ã£o

| Documento | ConteÃºdo |
|---|---|
| [docs/GDD.md](docs/GDD.md) | Game Design Document: conceito, mecÃ¢nicas, recursos, unidades, inimigos |
| [docs/ARQUITETURA.md](docs/ARQUITETURA.md) | OrganizaÃ§Ã£o do cÃ³digo, convenÃ§Ãµes e decisÃµes tÃ©cnicas |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Fluxo de trabalho com Git, branches, commits e Pull Requests |

## Equipe

| Nome | GitHub |
|---|---|
| Luis Pedro Costa | [@luis-pedro](https://github.com/luis-pedro) |
| *(a definir)* | |

## CrÃ©ditos

- **Arte:** [Tiny Swords](https://pixelfrog-assets.itch.io/tiny-swords), por **Pixel Frog**.
- **Engine:** [Godot Engine](https://godotengine.org/).
