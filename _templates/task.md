---
type: task
status: in_progress
repo: repo-a repo-b
task: TASK_ID
ids: qa=NNNNNN relacionado=NNNNNN
function: O que a task entrega, uma linha
titulo_busca: 3 a 8 palavras-chave do que foi feito
branch: feat/TASK_ID
related:
  - reqs/TASK_ID-slug.md
updated: YYYY-MM-DD
author: Seu Nome
---

# Titulo curto da entrega

<!-- Um arquivo por card (todos os repos). Substitui task-code + task-planning
+ testes + resumo. IDs moram no frontmatter (`task:` = card ancora, `ids:` =
papeis, `pr_*` = PRs) e o sync gera o bloco "IDs/PRs" acima - no texto, citar
o PAPEL ("Task QA", "PR do back"), nao o numero. Se precisar citar: `AZ 118403`
para work item, `repo#558` para PR. Nunca `#118403`. -->

## Status atual

<!-- Snapshot, reescrito a cada toque (nao log). 2-5 bullets: onde esta, o que
bloqueia. Sem run id, hash ou URL - isso fica em Review. -->

## O que falta

## Plano

### Entendimento

### Abordagem

### Mudancas por repo

### Riscos e bloqueios

## Testes unitarios

## Testes manuais

## O que foi implementado

<!-- Preencher ao fechar: nomes concretos de campos, endpoints e telas. -->

## REQs seguidas

## Review

<!-- ### Rodada N - YYYY-MM-DD - Aprovado | Ajustes solicitados
Findings, deploy, run ids e hashes ficam AQUI, nunca em Status atual. -->
