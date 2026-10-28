# Como contribuir

Guia do fluxo de trabalho da equipe. O objetivo é que os dois possam trabalhar em paralelo sem quebrar o jogo um do outro.

## Fluxo

1. **Toda tarefa vira uma Issue** no GitHub, atribuída a quem vai fazer.
2. Atualize a `main` e crie uma branch a partir dela:
   ```bash
   git checkout main
   git pull
   git checkout -b feat/coleta-de-madeira
   ```
3. Faça commits pequenos e frequentes.
4. Envie a branch e abra um **Pull Request** para a `main`, com `Closes #<número da issue>` na descrição.
5. O outro membro **revisa e testa** o PR antes do merge.
6. Depois do merge, apague a branch.

> Nunca faça commit direto na `main`.

## Nomes de branch

| Prefixo | Uso |
|---|---|
| `feat/` | Nova funcionalidade |
| `fix/` | Correção de bug |
| `docs/` | Documentação |
| `art/` | Assets, sprites, áudio |
| `refactor/` | Reorganização de código sem mudar comportamento |

## Mensagens de commit

Padrão [Conventional Commits](https://www.conventionalcommits.org/pt-br/), em português:

```
feat: adiciona coleta de madeira pelos aldeões
fix: corrige aldeão travando na árvore
docs: atualiza GDD com custos das construções
```

## Evitando conflitos no Godot

Arquivos `.tscn` são difíceis de mesclar. Para evitar dor de cabeça:

- **Combinem quem está mexendo em qual cena.** Duas pessoas editando a mesma `.tscn` ao mesmo tempo quase sempre gera conflito.
- **Divida em cenas menores** e instancie-as (ex.: `house.tscn` separada de `main.tscn`).
- **Commite os arquivos `.uid` e `.import`** gerados pelo Godot: eles mantêm as referências entre arquivos estáveis.
- **Não commite a pasta `.godot/`** (já está no `.gitignore`).
- Feche o Godot antes de `git pull` / trocar de branch, ou recarregue o projeto depois.

## Checklist do Pull Request

- [ ] O jogo abre e roda sem erros no console.
- [ ] Segue as convenções de [docs/ARQUITETURA.md](docs/ARQUITETURA.md).
- [ ] Documentação (GDD / arquitetura) atualizada, se necessário.
