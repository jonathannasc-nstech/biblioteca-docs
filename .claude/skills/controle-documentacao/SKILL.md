---
name: controle-documentacao
description: >-
  Controle de documentacao na Biblioteca (repo git de documentacao tecnica).
  Use para handover, handoff, spec, plano de execucao, testes (unitarios+manuais),
  resumo, ou doc tecnica para agentes. Task nova = UM arquivo em tasks/ (plano, testes,
  status e review juntos). NUNCA gravar corpo completo em docs/ do repo do projeto — so
  Biblioteca + stub. Apos salvar qualquer documento, rodar scripts/sync-all.ps1.
  NUNCA editar INDEX.md nem tabela manualmente.
---

# Controle de documentacao

**Biblioteca:** a raiz deste repo — regras resumidas em `01-regras-biblioteca.md`,
templates em `_templates/`.

## Formato atual: um arquivo por task

Task nova (card do rastreador ou demanda informal) = **um** doc `tasks/{card}-{slug}.md`
(template `_templates/task.md`), cobrindo todos os repos (`repo:` com todos, separados por
espaco). Ele substitui os antigos `task-code` + `task-planning` + `testes` + `resumo`.

Quando outra skill (spec, plano, `testes-manuais`, `task-hub-*`, `delegar-task` no modo
revisar) mandar gravar em `task-code/`, `task-planning/`, `testes/` ou `resumo/`, gravar na
secao equivalente do `tasks/` da task:

| Pedido da outra skill | Secao do `tasks/{card}-{slug}.md` |
|---|---|
| spec | `## Plano` > `### Entendimento` / `### Abordagem` |
| plano de execucao | `## Plano` > `### Mudancas por repo` / `### Riscos e bloqueios` |
| testes unitarios / manuais | `## Testes unitarios` / `## Testes manuais` |
| ajustes de QA rodada N | `## Ajustes QA — rodada N` (Reportado / Causa raiz / Corrigido) |
| resumo (status, o que falta, implementado) | `## Status atual` / `## O que falta` / `## O que foi implementado` / `## REQs seguidas` |
| rodada de review / deploy | `## Review` > `### Rodada N — data — veredito` |

**Task que ja tem docs no formato antigo:** continua neles ate fechar — nao migrar.

Fora do `tasks/`, sem mudanca: `reqs/` (card verbatim), `handover-tecnico/` (publico externo),
`delegadas/` (skill `delegar-task`), `progresso/` (rascunho), `exportacoes/`.

## IDs — um ancora, o resto e' papel

- `task:` = **card ancora** (o item que o produto conhece). E' o unico ID usado em
  comunicacao (chat do time, rastreador, conversa com o usuario).
- `ids:` (uma linha) = os outros itens **por papel**:
  `ids: qa=1235 relacionado=1230 tc-back=1240 tc-front=1241 parent=1200`.
- PRs: so' nos campos `pr_pending`/`pr_merged`/`pr_rejected` (URL completa).
- O sync gera o bloco **IDs/PRs** no topo do doc — nao escrever a lista a mao.
- No texto corrido, citar o **papel** ("a task de QA", "o PR do back"). Se o numero for
  indispensavel: `AZ 1234` (item do rastreador) e `repo#558` (PR). **Nunca `#1234`** — `#`
  e' de PR; o lint avisa.
- Run id, hash de commit e timestamp de migration so' em `## Review`.
- Sem `number:` e sem `pseudo_task:` em doc novo. Task sem card (`task: general`):
  `cluster:` com 2-4 palavras identifica o assunto.

## Atualizar vs criar

**Atualizar** (o comum): abrir o arquivo, editar so' o que mudou, `updated:` = hoje, rodar
`sync-all.ps1`. `## Status atual` e' **snapshot** — reescrever, nunca acrescentar narrativa.

**Criar** um `tasks/` novo:
1. `grep -rl "^task: {card}" tasks/ task-code/ task-planning/ resumo/ delegadas/` — ja existe? atualizar.
2. Copiar `_templates/task.md`, preencher frontmatter + corpo (H1 em diante).
3. Sem tabela de metadados, sem lista de IDs/PRs, sem `## Documentos relacionados` — o script gera.
4. Rodar `powershell -ExecutionPolicy Bypass -File scripts/sync-all.ps1`.

## Gate — card, item tecnico e parent antes do plano (bloqueia)

Antes de escrever `## Plano`, `reqs/{card}-{slug}.md` precisa ter, **verbatim**:
1. O card original do rastreador.
2. O item tecnico filho, quando o time separa (ex.: "Task Code" no Azure DevOps) — mesmo
   sem pedido explicito; so' pular se nao existir item separado.
3. O parent (Feature/Epic), em `## Parent`, quando houver — perguntar se nao souber.

- Demanda sem card (`task: general`): o pedido original do usuario vai verbatim em `reqs/{slug}.md`.
- Duvida de produto em aberto: registrar como bloqueio em `### Riscos e bloqueios` e nao
  implementar a parte afetada antes da resposta.
- Artefato de arquivo (relatorio/export): formato vem do card/parent, nunca inferido.
- **Last check** antes de `status: completed`: reabrir o `reqs/` e conferir item por item.

## Status

Um campo so' (`status:` do `tasks/`): `draft` → `in_progress` → `completed`
(`superseded`/`archived` para doc substituido). Gatilhos:

| Evento | Acao |
|---|---|
| Plano aprovado / implementacao comecou | `in_progress` |
| Agente monta commit + texto/link de PR | URL em `pr_pending` **na hora** (cada PR novo) |
| Todos os PRs mergeiam | o sweep do `sync-all` muda para `pr_merged` e fecha a task sozinho |
| "Task resolvida?" = sim | last check do Gate; `completed`; `## O que foi implementado` preenchido |
| "Task resolvida?" = nao | manter `in_progress`; registrar a lacuna em `## O que falta` |
| Implementacao diverge do plano | atualizar `progresso/{card}-{slug}.md` (sem sync) e, ao estabilizar, o `## Plano` |

O INDEX marca "parado ha N dias" doc ativo sem toque ha mais de 14 dias: decidir fechar ou retomar.

## Frontmatter

```yaml
---
type: task                # handover-tecnico | delegada | rules (legado: task-code, task-planning, testes, resumo)
status: in_progress
repo: meu-app-frontend meu-app-backend
task: 1234                # card ancora | general
ids: qa=1235 relacionado=1230
function: Uma linha do que a task entrega
titulo_busca: Cadastro de produtos com filtro   # obrigatorio, 3-8 palavras do que foi FEITO
branch: feat/1234
cluster: —                # so' task: general
pr_pending: —             # URLs completas separadas por espaco
related:
  - reqs/1234-cadastro-produtos.md
updated: YYYY-MM-DD
author: Seu Nome
---
```

## Escrita (handover-tecnico e tasks/ lidos por terceiros)

- Regra de negocio citada do card em blockquote (`> Card, CA-XX: "trecho"`), copiado do `reqs/`.
- Sem historico de tentativa e erro, sem jargao da Biblioteca, sem citar o pedido do usuario
  ("conforme solicitado") — descrever o achado como fato tecnico.
- Tom profissional e frases completas, sem "nos"/"nosso".
- `progresso/` e' isento: rascunho sobrescrito (Fazendo agora / Ultima decisao / Proximo
  passo), fora do sync; ao fechar a task, mover para `_archive/progresso/`.

## Busca

`INDEX.md` = so' as ativas. Historico: `grep` pontual em `CATALOGO.md`, `tasks/` e `resumo/`
— nunca ler o catalogo inteiro.

## Repo de projeto

Nunca corpo de doc em `docs/` do repo do projeto. So' stub (~5 linhas: titulo + caminho do
doc na Biblioteca) quando o YAML tiver `stub:`.

## Commit da Biblioteca

Ao commitar/abrir PR em repo de projeto, `git status` da Biblioteca **inteira**:
- Doc com frontmatter `completed`/`superseded`/`archived`: entra. `draft`/`in_progress` com
  `updated:` antigo e sem doc mais novo da mesma task: perguntar antes.
- `planos/`: agrupar por `{codename}-{slug}`, subir so' o timestamp mais recente.
- `reqs/`: sempre sobe (so' pula duplicata exata).
- `delegadas/`: entra direto.

Mensagem simples (`docs: task <card>`).
