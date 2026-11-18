# dashboard-visual

Camada visual da própria **Biblioteca** — não é um projeto separado. Só existe para
navegar e retomar tasks sem abrir cada repo de projeto. Abra `dashboard.html` direto no
navegador (vale salvar nos favoritos).

## Arquitetura — onde editar

| Arquivo | Papel | Quem escreve |
|---|---|---|
| `dashboard.html` | Página fixa: cabeçalho, abas, painel lateral, diálogos do Time | à mão |
| `assets/app.css` | Todo o visual (tokens de cor no `:root`) | à mão |
| `assets/app.js` | Monta cards, tabela, Time e painel a partir dos dados; busca, abas, menus, atualização | à mão |
| `data.js` | `window.BIBLIOTECA = {...}`: cards, PRs com estado, camadas, comandos, resumo, QA, Time | `scripts/build-dashboard.ps1` (a cada `sync-all`) |

- **Regra fica no PowerShell, desenho fica no JS.** Estado de PR, camadas, rodadas de QA,
  comandos e texto do Teams são calculados em `build-dashboard.ps1` (`Get-CardData`,
  `Get-QaRoundData`, `Get-DelegadaData`, `Get-TimeData`, `Get-LayerStates`, `Get-PrData`).
  O `app.js` não decide nada de negócio.
- **Acento:** `app.js`, `app.css` e `dashboard.html` são UTF-8 normais. Só os `.ps1`
  evitam acento literal (PowerShell 5.1 lê arquivo sem BOM como ANSI).
- **Atualização:** o `app.js` relê `data.js` a cada 20s e só redesenha se `generatedAt`
  mudou — sem recarregar a página. Pula com diálogo, menu ou lista de repos aberta.
- **PS 5.1 + JSON:** `Remove-TypeData System.Array` antes do `ConvertTo-Json` (senão array
  vira `{"value":[...],"Count":n}`); `@()` direto numa `List[object]` lança "tipos de
  argumento não correspondem" — usar `.ToArray()`.

## Telas

- **Cabeçalho:** busca + campo de repositório (lista própria, com até 5 repos fixados no
  topo, guardados no navegador), Abrir Claude, + Nova Task, Revisar PRs, menus Time e Mais.
- **Ativas:** cards enxutos — título abre o painel, PRs resumidos numa pílula, camadas
  sempre visíveis, faixa lateral pelo estado (laranja = pendente, verde = feito). A mesma
  task em vários repos vira um card só; os botões ganham a camada ("Retomar task · back").
  Rodadas de QA aparecem como cards próprios logo depois.
- **Time:** colunas por dev com as delegadas (`delegadas/`, `delegadas/devs.json`).
- **Completas:** tabela com ordenação e paginação; visões **Completas / Pendências /
  Arquivo** (Pendências = resumo em andamento de task que não está mais ativa, com seleção e
  comando para o Claude conferir; Arquivo = `_archive/`).
- **Painel lateral:** status, o que falta, implementado, REQs, PRs, QA, documentos e o botão
  **Copiar texto pro Teams**.

`paleta.html` e `nova-task.html` ainda são HTML gerado pelo `build-dashboard.ps1`.
`time.html`, `archive.html` e `pendencias.html` só redirecionam para o dashboard.

## Botões que abrem o Claude

Cada botão de ação é um link `biblioteca-cmd-run:<comando>` (além de copiar o comando).
O protocolo é registrado uma vez por máquina com `scripts/register-protocol.ps1` e
entregue ao `scripts/launch-command.vbs`, que abre um terminal, digita o comando e aperta
Enter. Sem o protocolo, o comando fica na área de transferência.

Skills locais: `task-hub-resume` (retomar task), `task-hub-qa` (reabrir para ajustes de QA).
