---
name: importar-historico-github
description: >-
  Povoa a Biblioteca com docs tasks/ gerados a partir do historico de Pull
  Requests do usuario no GitHub - pra quem ja resolveu tasks antes de
  existir a Biblioteca (usuario novo, sem documentacao anterior). So gera
  um doc `task` minimo (status + PRs nos campos pr_*), sem plano nem testes.
  Use quando o usuario pedir "importar historico do github", "povoar a
  biblioteca com meus PRs", ou logo apos `biblioteca-setup` se o usuario
  topar.
---

# importar-historico-github

## Quando disparar

Sob demanda - o usuario pede explicitamente ("importar meu historico do
github", "povoar a biblioteca com meus PRs", "quero comecar com algo
funcional") ou aceita a sugestao feita no fim do `biblioteca-setup`.
Nunca dispara sozinha, nunca bloqueia o setup normal.

## O que faz

Roda `_ferramenta/scripts/backfill-github-prs.ps1`, que:

1. Busca via `gh search prs --owner {org} --author @me` (mergeadas +
   abertas) - sem precisar clonar nenhum repo.
2. Classifica cada PR pelo **titulo**, em 3 trilhas com fallback em cascata
   (numerica → scope → titulo avulso; ver cabecalho/logica de
   `backfill-github-prs.ps1` pras regras exatas - nao restatar aqui, senao
   as duas fontes divergem no dia que o script mudar).
3. Agrupa por task+repo (task numerica) ou cluster+repo (fallback) - uma
   task cross-repo vira um card por repo, igual ao resto da Biblioteca -
   e classifica frontend/backend pelo nome do repo (mesma convencao do
   `Get-PrKindInfo` no dashboard).
4. Gera um doc `tasks/{task}-{slug}.md` (`type: task`) minimo por grupo -
   `status`, `pr_merged`/`pr_pending` (o sync gera o bloco IDs/PRs), o
   assunto de cada PR em "O que foi implementado" e um "Status atual"
   deixando claro que e' backfill automatico (sem plano, testes nem
   contexto de negocio).
5. Pula grupos que ja tem doc (`tasks/` do mesmo card, ou `resumo/` legado
   do mesmo task+repo/cluster+repo) e grupos com PR ja citado em qualquer
   doc da Biblioteca - nao sobrescreve nada real nem um backfill anterior.
6. Roda `sync-all.ps1` no final se criou algo.

**Aplica direto, sem preview** - decisao do usuario (2026-08-21): pode
gerar entrada errada ou duplicada ocasionalmente, ele prefere resolver
isso depois com uma ferramenta de limpeza (ainda nao existe - se o
usuario pedir pra remover um doc de backfill, apagar o arquivo e
rodar `sync-all.ps1`, nao ha comando dedicado ainda).

## Pre-requisitos

- `gh` (GitHub CLI) instalado e autenticado (`gh auth login`) - o script
  checa `gh auth status` e para com aviso claro se nao estiver.
- Org do GitHub: passa `-Org <nome>` ou grava `githubOrg` em
  `biblioteca.config.json` (perguntar ao usuario se nenhum dos dois
  estiver disponivel - nao adivinhar o nome da org). Se perguntou porque
  o campo nao existia, gravar a resposta em `githubOrg` no
  `biblioteca.config.json` antes de rodar o script, pra nao perguntar de
  novo da proxima vez.

## Como rodar

```powershell
powershell -ExecutionPolicy Bypass -File _ferramenta/scripts/backfill-github-prs.ps1 -Org minha-org
```

Reportar ao usuario, ao final (o proprio script ja imprime isso): quantos
grupos cairam em cada trilha (numerica / scope-fallback / titulo-fallback),
quantos docs `tasks/` foram criados, quantos foram pulados (ja existiam).

## O que essa skill NAO faz

Nao preenche plano nem testes do doc (exigiria ler diff de
codigo de verdade - fora do que da pra automatizar so' com titulo/link de
PR). Nao inventa numero de task - PR sem numero no titulo vira `cluster`
(fallback por scope ou por titulo, ver acima), nunca um numero chutado.
Nao remove nem corrige backfill anterior (sem ferramenta de limpeza
ainda). Nao pede confirmacao/preview antes de gravar - aplica direto.
