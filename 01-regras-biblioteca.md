---
type: rules
status: completed
repo: geral
task: general
function: Regras da Biblioteca
cluster: Regras da Biblioteca
updated: 2026-11-17
author: —
---
# Regras da Biblioteca

Referência humana, condensada. Agentes seguem a versão operacional em
`.claude/skills/controle-documentacao/SKILL.md`.

**Local:** raiz deste repo
**Índice:** [`INDEX.md`](INDEX.md) (tasks em andamento, gerado — não editar)
**Catálogo:** [`CATALOGO.md`](CATALOGO.md) (histórico completo, gerado — não editar)
**Sync:** `scripts/sync-all.ps1`

---

## Formato: um arquivo por task

Task nova = **um** `tasks/{card}-{slug}.md` (template [`_templates/task.md`](_templates/task.md)),
cobrindo todos os repos. Ele reúne status, o que falta, plano, testes, o que foi
implementado e review — um status só, sem divergência entre documentos.

Os tipos antigos (`task-code`, `task-planning`, `testes`, `resumo`) continuam lidos pelo
dashboard, para quem já tem histórico neles.

## Estrutura

```
Biblioteca/
├── INDEX.md / CATALOGO.md       # gerados
├── 01-regras-biblioteca.md
├── tasks/                        # um doc por card
├── reqs/                         # card/item técnico/parent verbatim (sem frontmatter)
├── handover-tecnico/             # módulo, playbook, contrato — público externo
├── delegadas/                    # task de outro dev do time (aba Time)
├── progresso/                    # rascunho sobrescrito, fora do sync
├── planos/                       # backup automático de planos (hook)
├── exportacoes/                  # PDF/imagem para quem não é técnico
├── _templates/  _archive/  scripts/  dashboard-visual/
```

## IDs

| Onde | O quê |
|---|---|
| `task:` | **Card âncora** — o item que o produto conhece. Único ID usado em comunicação |
| `ids:` | Demais itens por papel, numa linha: `qa=1235 relacionado=1230 tc-back=1240` |
| `pr_pending` / `pr_merged` / `pr_rejected` | URLs completas dos PRs; o sweep do sync atualiza o estado e fecha a task quando todos mergeiam |

O sync gera no topo do doc o bloco **IDs/PRs** com links. No texto, citar o papel ("a task
de QA", "o PR do back"). Notação quando o número for indispensável: `AZ 1234` (item do
rastreador) e `meu-app-frontend#439` (PR). `#1234` solto é proibido (o lint avisa).

## Status

`draft` → `in_progress` → `completed` | `superseded` | `archived`. Doc ativo sem toque há
mais de 14 dias aparece no INDEX como "parado há N dias".

## Dashboard

`dashboard-visual/dashboard.html` (abrir direto no navegador) lê `data.js`, gerado pelo
`sync-all`. Abas Ativas / Time / Completas, painel lateral com o resumo da task e botão
**Copiar texto pro Teams** (título, status e o que falta em texto puro).

## Regra absoluta — nunca corpo completo no repo do projeto

Só stub (`docs/`, ~5 linhas apontando para a Biblioteca) quando o YAML tiver `stub:`.

## Automação

| Script | Função |
|--------|--------|
| `sync-header.ps1` | YAML → badge, bloco IDs/PRs, metadados |
| `lint-clusters.ps1` | Trava cluster divergente e resumo duplicado; avisa `related` quebrado e `#item` |
| `build-index.ps1` | Gera `INDEX.md` + `CATALOGO.md` |
| `dashboard-visual/scripts/build-dashboard.ps1` | Gera `data.js` do dashboard; sweep de PR |
| `sync-all.ps1` | Roda os quatro em ordem — sempre depois de editar |
