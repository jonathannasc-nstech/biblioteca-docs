# Gera dashboard-visual/dashboard.html a partir de TODOS os docs da
# Biblioteca (nao so pendentes) - secoes Ativas / Completas +
# comando copiavel de retomada/conclusao/QA por task. Reaproveita
# lib-doc.ps1, nao duplica parsing de frontmatter. Isso e' a camada visual
# da propria Biblioteca (nao um projeto separado) - mora em
# Biblioteca/dashboard-visual/.
#
# Favorito ("estrela") e puramente client-side (localStorage) - nao precisa
# de comando/skill, e' so uma preferencia de UI, sem logica de git.
param([array]$ParsedDocs)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$hubRoot = Split-Path $PSScriptRoot -Parent
$libRoot = Split-Path $hubRoot -Parent
$libScript = Join-Path $libRoot 'scripts\lib-doc.ps1'
. $libScript
. (Join-Path $PSScriptRoot 'dashboard-lib.ps1')

$root = Get-LibRoot
# -ParsedDocs vem de sync-all.ps1 (parse compartilhado); sem ele (rodando
# este script solo, como faz task-hub-qa), parseia por conta
# propria - ver lint-clusters.ps1.
$parsedDocs = if ($ParsedDocs) { $ParsedDocs } else { Get-ParsedDocs $root }
$typeOrder = @{ 'task' = 0; 'task-code' = 0; 'task-planning' = 1; 'testes' = 2; 'handover-tecnico' = 3 }
# Tipos cujo corpo tem secoes de teste (## Testes unitarios/manuais,
# ## Ajustes QA). `task` (formato unico desde 2026-11-17) junta planning,
# testes e resumo num arquivo so'.
$testBodyTypes = @('testes', 'task')
$activeStatuses = @('draft', 'in_progress')
$bibConfig = Get-BibliotecaConfig
$azureBase = $bibConfig.azureOrgUrl

$githubIcon = '<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.02 1.93-.02 2.2 0 .21.15.46.55.38A8.01 8.01 0 0016 8c0-4.42-3.58-8-8-8z"/></svg>'
$linkIcon = '<svg viewBox="0 0 16 16" width="13" height="13" fill="currentColor"><path d="M4.72 3.5a2.25 2.25 0 000 4.5h1.5a.75.75 0 010 1.5h-1.5a3.75 3.75 0 010-7.5h1.5a.75.75 0 010 1.5h-1.5zm6.56 0h-1.5a.75.75 0 000 1.5h1.5a2.25 2.25 0 010 4.5h-1.5a.75.75 0 000 1.5h1.5a3.75 3.75 0 000-7.5zM5.5 8a.75.75 0 01.75-.75h3.5a.75.75 0 010 1.5h-3.5A.75.75 0 015.5 8z"/></svg>'
$starIcon = '<svg class="star-icon" viewBox="0 0 24 24" width="17" height="17"><path d="M12 2.5l2.9 6.26L22 9.77l-5 4.87L18.18 21.5 12 17.77 5.82 21.5 7 14.64l-5-4.87 7.1-1.01L12 2.5z"/></svg>'
$bookIcon = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z"/><path d="M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z"/></svg>'
$chevronIcon = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6l4 4 4-4"/></svg>'

# Padrao unico de lancamento (biblioteca-cmd-run:) - injetado no <script> de
# TODA pagina com botao que abre um cmd novo (dashboard.html, resumo/*.html,
# nova-task.html), fonte unica em vez de 3 copias que podiam divergir (foi
# assim que o header "Abrir Claude" ficou com preventDefault+location.href
# enquanto os outros usavam <a href> real - bug de janela dupla, 2026-09-01).
# href sempre atualizado ANTES do clique nativo seguir - nunca
# preventDefault + location.href de novo pra reabrir um protocolo
# customizado (dispara o handler do SO 2x em alguns navegadores). Clipboard
# e' so fallback assincrono pra maquina sem o protocolo registrado, nao
# bloqueia a navegacao.
$launchButtonJs = @'
function biblLaunch(el, cmd) {
  el.setAttribute('href', 'biblioteca-cmd-run:' + encodeURIComponent(cmd));
  function fallback() {
    var ta = document.createElement('textarea');
    ta.value = cmd;
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); } catch (e) {}
    document.body.removeChild(ta);
  }
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(cmd).catch(fallback);
  } else {
    fallback();
  }
  var original = el.textContent;
  el.textContent = 'Abrindo...';
  setTimeout(function () { el.textContent = original; }, 1500);
}
'@

# Tokens de cor + reset base - identicos nas 6 paginas geradas (dashboard,
# resumo, paleta, archive, nova-task, pendencias). Cada pagina pode somar
# um `:root { --token-extra: ...; }` proprio logo depois deste bloco pra
# variaveis que so ela usa (ex.: nova-task.html tem --azure-*/--claude-*,
# paleta.html tem --current/--current-glow) - nao precisa duplicar as
# 10 variaveis base, so' extender.
$sharedCss = @'
:root {
  color-scheme: dark;
  --bg: #1c1e21; --card-bg: #24262a; --card-border: #34373c;
  --text: #e2e4e7; --text-dim: #93969e; --text-faint: #6d7078;
  --gold: #b8935a; --gold-bright: #d9b26a; --gold-bg: #2e2717; --gold-border: #6b5628;
}
* { box-sizing: border-box; }
*:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; border-radius: 4px; }
'@


# Favicon - livro verde vibrante, mesmo desenho do $bookIcon (silhueta) mas
# preenchido (stroke fino some em 16x16) - vai pra aba do navegador/favoritos.
$faviconSvg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'><path fill='%2322c55e' d='M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z'/><path fill='%2316a34a' d='M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z'/></svg>"
$faviconLink = "<link rel=`"icon`" type=`"image/svg+xml`" href=`"data:image/svg+xml,$faviconSvg`">"

# Marca do topo do dashboard - mesmo desenho/cores do favicon (preenchido, 2
# tons de verde), so' que sem URL-encoding - usado so' no header, nao troca o
# $bookIcon (contorno) usado em "Ver resumo"/paleta.
$brandIconGreen = '<svg viewBox="0 0 24 24"><path fill="#22c55e" d="M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z"/><path fill="#16a34a" d="M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z"/></svg>'
$paletteIcon = '<svg viewBox="0 0 16 16" width="12" height="12"><circle cx="8" cy="8" r="6" fill="currentColor"/></svg>'
$archiveIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2" y="6" width="12" height="8" rx="1"/><path d="M2 6l1-3h10l1 3"/></svg>'
$pendIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><circle cx="8" cy="8" r="6.3"/><path d="M5.5 8l1.8 1.8L10.8 6"/></svg>'
$searchIcon = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><circle cx="7" cy="7" r="5"/><path d="M11 11l3.5 3.5"/></svg>'
$mockIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><path d="M1 8s2.5-4.5 7-4.5S15 8 15 8s-2.5 4.5-7 4.5S1 8 1 8z"/><circle cx="8" cy="8" r="1.8" fill="currentColor" stroke="none"/></svg>'

# Icones do "tipo de repo" do PR (backend/frontend/migration) - trocam o
# $githubIcon generico no pill de PR, inferido do nome do repo na propria
# URL (sufixo -backend, prefixo [org-]mfe-/mobile-, ou nome com
# "migrations"). "PR #N" no texto ja diz que e' PR - o icone generico
# do github era redundante; agora carrega informacao nova.
$backendIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="2" y="2" width="12" height="4.5" rx="1"/><rect x="2" y="9.5" width="12" height="4.5" rx="1"/><circle cx="4.3" cy="4.25" r="0.55" fill="currentColor" stroke="none"/><circle cx="4.3" cy="11.75" r="0.55" fill="currentColor" stroke="none"/></svg>'
$frontendIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4"><rect x="1.5" y="2.5" width="13" height="9" rx="1"/><path d="M6 14.5h4M8 11.5v3"/></svg>'
$migrationIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5.5h9.5m0 0L10 3M12.5 5.5L10 8"/><path d="M13 10.5H3.5m0 0L6 8M3.5 10.5L6 13"/></svg>'

# Cards irmaos da mesma task (task numerica igual, ou mesmo cluster exato
# pra task "general") - inclui o proprio $card. Le $cardsByTask/
# $cardsByCluster (script scope, montados logo apos $cards ficar pronto,
# antes de qualquer chamada a esta funcao). Usada por qualquer lugar que
# precisa agregar dado cross-repo da mesma task (PRs, estado de PR, testes,
# tasks relacionadas).
function Get-TaskSiblings([PSCustomObject]$card) {
    $siblings = if ($card.Task -match '^\d+$') {
        @($cardsByTask[$card.Task])
    } elseif ($card.Cluster) {
        @($cardsByCluster[$card.Cluster])
    } else {
        @()
    }
    if ($siblings.Count -eq 0) { return @($card) }
    return $siblings
}

# Classifica um nome de repo pela convencao de nome (sufixo -backend, prefixo
# [org-]mfe-/mobile-, ou "migrations") - fonte unica usada tanto pelo icone do PR
# (Get-PrKindInfo) quanto pelo rotulo curto de camada no titulo do card
# (Build-Card/Build-SummaryHtml, taskLabel). $null se o nome nao bater com
# nenhuma convencao conhecida (repo pessoal, nome atipico etc.).
function Get-RepoLayer([string]$repo) {
    if (-not $repo) { return $null }
    if ($repo -match '-backend$') { return 'backend' }
    if ($repo -match 'migrations') { return 'migrations' }
    if ($repo -match '^([^-]+-)?(mfe|mobile)-') { return 'frontend' }
    return $null
}
$script:RepoLayerLabels = @{ backend = 'Backend'; frontend = 'Frontend'; migrations = 'Migrations' }


# Classifica o PR pelo nome do repo na propria URL - sem depender de campo
# novo no frontmatter. Fallback pro icone generico do github se o nome nao
# bater com nenhuma convencao conhecida (repo pessoal, nome atipico etc.).
function Get-PrKindInfo([string]$prUrl) {
    if ($prUrl -notmatch 'github\.com/[^/]+/([^/]+)/pull/') {
        return [PSCustomObject]@{ Icon = $githubIcon; Title = 'PR'; Layer = $null }
    }
    $repo = $Matches[1]
    switch (Get-RepoLayer $repo) {
        'backend' { return [PSCustomObject]@{ Icon = $backendIcon; Title = 'PR de backend'; Layer = 'backend' } }
        'migrations' { return [PSCustomObject]@{ Icon = $migrationIcon; Title = 'PR de migration'; Layer = 'migrations' } }
        'frontend' { return [PSCustomObject]@{ Icon = $frontendIcon; Title = 'PR de frontend'; Layer = 'frontend' } }
        default { return [PSCustomObject]@{ Icon = $githubIcon; Title = 'PR'; Layer = $null } }
    }
}

# 4 badges de status por camada (migrations/backend/frontend/testes) da
# task inteira (todos os repos, via $cardsByTask/$cardsByCluster - mesmo
# agrupamento cross-repo do Get-RelatedTasksHtml) - substitui a antiga
# lista de texto livre "Pendencias" (extraida por regex do corpo do doc,
# pouco legivel e nao confiavel). Verde = feito, vermelho = pendente,
# amarelo = camada nao existe nesta task (nenhum PR/doc encontrado).
function Get-LayerStates([PSCustomObject]$card) {
    $siblings = Get-TaskSiblings $card

    # Uniao dos PRs de todos os irmaos, montada aqui (card.Signals.PRs NAO
    # vem mais agregado - ver nota logo apos $cardsByTask/$cardsByCluster
    # serem montados) - o painel de status por camada precisa ver a task
    # inteira mesmo quando chamado a partir do card de um unico repo.
    $allPrs = @($siblings | ForEach-Object { $_.Signals.PRs } | Select-Object -Unique)
    $allDocs = New-Object System.Collections.Generic.List[object]
    foreach ($s in $siblings) {
        foreach ($d in $s.Docs) { $allDocs.Add($d) }
        if ($s.ResumoDoc) { $allDocs.Add($s.ResumoDoc) }
    }

    function Get-PrState([string]$pr) {
        # mesma checagem de estado do Get-ExtLinksHtml (Contains, nao -eq,
        # pra bater com campo com varias URLs - migration espelho etc.)
        if (@($allDocs | Where-Object { $_.PrMerged -and $_.PrMerged.Contains($pr) }).Count -gt 0) { return 'done' }
        if (@($allDocs | Where-Object { $_.PrRejected -and $_.PrRejected.Contains($pr) }).Count -gt 0) { return 'done' }
        return 'pending'
    }

    function Get-LayerState([string]$layer) {
        $prsInLayer = @($allPrs | Where-Object { (Get-PrKindInfo $_).Layer -eq $layer })
        if ($prsInLayer.Count -eq 0) { return 'na' }
        if (@($prsInLayer | Where-Object { (Get-PrState $_) -eq 'pending' }).Count -gt 0) { return 'pending' }
        return 'done'
    }

    # Isola o texto de UMA secao "## Titulo" ate a proxima "## " (ou fim do
    # doc) - split com lookahead, sem regex multilinha fragil. So' a
    # primeira linha do trecho e' comparada contra o titulo procurado.
    function Get-SectionText([string]$body, [string]$headingSubstring) {
        $parts = $body -split '(?m)(?=^## )'
        foreach ($p in $parts) {
            $firstLine = ($p -split "`n")[0]
            if ($firstLine -match [regex]::Escape($headingSubstring)) { return $p }
        }
        return $null
    }

    # Heuristica sobre texto ja convencionado (mesma familia de risco da
    # antiga extracao de pendencias, escopo bem mais restrito): secao
    # "## Testes unitarios" (padrao backend) ou "## Verificacao estatica"
    # (papel equivalente no frontend, tsc/biome/build) = camada unitaria;
    # "## Testes manuais" = camada manual. Sem secao em nenhum doc irmao
    # `testes/` = amarelo (nao necessario). Com secao, procura marcador
    # negativo ja usado na convencao atual (cross/hourglass emoji, "pendente",
    # "nao executado") dentro DAQUELE trecho especifico, nao o doc inteiro - senao um doc
    # com unitario verde + manual pendente contaminaria os dois).
    function Get-TestTypeState([string]$headingSubstring, [string[]]$negativeMarkers) {
        $sections = @($testesDocs | ForEach-Object { Get-SectionText $_.Body $headingSubstring } | Where-Object { $_ })
        if ($sections.Count -eq 0) { return 'na' }
        foreach ($sec in $sections) {
            foreach ($marker in $negativeMarkers) {
                if ($sec -match $marker) { return 'pending' }
            }
        }
        return 'done'
    }

    # Caracteres especiais via codepoint, nao literal - este arquivo nao tem
    # BOM, PowerShell 5.1 le como ANSI e corrompe qualquer char nao-ASCII
    # digitado direto no source (mesmo motivo do $script:EmDash em
    # lib-doc.ps1 e do $emDash em export-public.ps1).
    $crossmark = [char]0x274C
    $hourglass = [char]0x23F3
    $aTilde = [char]0x00E3
    $aAcute = [char]0x00E1

    $testesDocs = @($allDocs | Where-Object { $_.Type -in $testBodyTypes })
    # 'Testes unit' (sem o resto): casa "unitarios" e "unitários" - a maioria
    # dos docs usa acento e ficava sempre "nao necessario".
    $unitState = Get-TestTypeState 'Testes unit' @($crossmark, '(?i)falhou', '(?i)regress\w* encontrada')
    if ($unitState -eq 'na') {
        $unitState = Get-TestTypeState 'Verifica' @($crossmark, '(?i)falhou')
    }
    $manualState = Get-TestTypeState 'Testes manuais' @($hourglass, '(?i)pendente', "(?i)n${aTilde}o executado")

    $layers = @(
        [ordered]@{ label = 'Migrations'; short = 'Migr'; state = (Get-LayerState 'migrations') }
        [ordered]@{ label = 'Backend'; short = 'Back'; state = (Get-LayerState 'backend') }
        [ordered]@{ label = 'Frontend'; short = 'Front'; state = (Get-LayerState 'frontend') }
        [ordered]@{ label = "Testes unit${aAcute}rios"; short = 'Unit'; state = $unitState }
        [ordered]@{ label = 'Testes manuais'; short = 'Manual'; state = $manualState }
    )
    # Nenhuma camada com sinal (sem PR em migrations/backend/frontend, sem
    # secao de teste) = ruido puro (handover, investigacao) - nao mostra.
    if (@($layers | Where-Object { $_.state -ne 'na' }).Count -eq 0) { return @() }
    return $layers
}



$all = @()
foreach ($d in $parsedDocs) {
    $f = $d.File
    $p = $d.Parsed
    # `number:` opcional desde 2026-11-17 - basta `type:` (mesmo filtro do build-index).
    if (-not $p -or -not $p.Meta['type']) { continue }
    $status = Clean-Field $(if ($p.Meta['status']) { $p.Meta['status'] } else { 'draft' })
    $task = Clean-Field $(if ($p.Meta['task']) { $p.Meta['task'] } else { 'general' })
    $all += [PSCustomObject]@{
        Task     = $task
        Repo     = Clean-Field $p.Meta['repo']
        Function = Clean-Field $p.Meta['function']
        TituloBusca = Clean-Field $p.Meta['titulo_busca']
        Type     = Clean-Field $p.Meta['type']
        Status   = $status
        Updated  = Clean-Field $p.Meta['updated']
        UpdatedTime = $f.LastWriteTime.ToString('HH:mm')
        Path     = $f.FullName
        Body     = $p.Body
        Related  = $p.Meta['related']
        Branch    = Clean-Field $p.Meta['branch']
        Cluster   = Clean-Field $p.Meta['cluster']
        PseudoTask = Clean-Field $p.Meta['pseudo_task']
        PrPending  = Clean-Field $p.Meta['pr_pending']
        PrMerged   = Clean-Field $p.Meta['pr_merged']
        PrRejected = Clean-Field $p.Meta['pr_rejected']
        # so' docs `delegada` (pagina time.html) usam estes - vazio nos demais
        Dev         = Clean-Field $p.Meta['dev']
        Dificuldade = Clean-Field $p.Meta['dificuldade']
        Estimativa  = Clean-Field $p.Meta['estimativa']
        DelegadaEm  = Clean-Field $p.Meta['delegada_em']
    }
}

# `delegada` = task passada pra outro dev do time (pagina time.html). Fica
# em $all (o sweep/backfill de PR abaixo precisa enxergar - e' isso que
# fecha a delegada sozinha quando o PR do dev mergeia), mas NUNCA vira card
# do dashboard principal nem entra na lista de repos: nao e' trabalho
# proprio, e agrupar por task+repo misturaria com uma task minha de mesmo id.
$ownDocs = @($all | Where-Object { $_.Type -ne 'delegada' })

# Lista de repos conhecidos - repos ja com doc na Biblioteca + pastas reais em
# reposBasePath (repo novo que ainda nao tem task nenhuma). Usada nos
# datalists de nova-task.html e do seletor "Abrir Claude" do header do
# dashboard - montada 1x aqui pra nao duplicar a logica nos dois lugares.
$knownRepos = New-Object System.Collections.Generic.List[string]
foreach ($r in @($ownDocs | ForEach-Object { $_.Repo } | Where-Object { $_ })) {
    if (-not $knownRepos.Contains($r)) { $knownRepos.Add($r) }
}
if ($bibConfig.reposBasePath -and (Test-Path $bibConfig.reposBasePath)) {
    foreach ($dir in (Get-ChildItem -Path $bibConfig.reposBasePath -Directory -ErrorAction SilentlyContinue)) {
        if (-not $knownRepos.Contains($dir.Name)) { $knownRepos.Add($dir.Name) }
    }
}

# Primeiro caractere alfanumerico: pasta oculta (.claude, .vscode) em
# reposBasePath nao e' repo.
$knownRepos = @($knownRepos | Where-Object { $_ -match '^[A-Za-z0-9][A-Za-z0-9._-]*$' } |
    ForEach-Object { Get-RepoSortKey $_ $bibConfig.reposAoFim $bibConfig.repoAliases } |
    Sort-Object Bucket, Domain, SubOrder, Name |
    ForEach-Object { $_.Name })
# "Biblioteca" nao mora em reposBasePath (e' a raiz do proprio repo da
# Biblioteca, pasta irma de reposBasePath) - por isso nunca aparecia nesta
# lista (que so' varre reposBasePath + repo: dos docs). Forcado primeiro na
# lista (nao passa por Get-RepoSortKey) pra abrir o Claude direto nela pelo
# seletor "Abrir Claude" - ver caso especial de path em __LIB_ROOT_PATH__.
$knownRepos = @('Biblioteca') + @($knownRepos | Where-Object { $_ -ne 'Biblioteca' })
$knownReposOptionsHtml = ($knownRepos | ForEach-Object { "<option value=`"$(Esc $_)`">" }) -join "`n"

# Regex de link de PR no corpo - mesma usada pelo Get-Signals (linha ~38),
# reaproveitada aqui pro backfill de estado (cor do pill).
$prLinkPattern = 'https?://github\.com/\S*?/pull/\d+'

# Sweep de PR mergeado: guarda barata - so chama `gh` (rede) se existir pelo
# menos 1 doc com `pr_pending`. Maioria das rodadas custa zero. Doc mergeado
# flipa status:completed, some o pr_pending, e o proprio arquivo e' regravado
# via Sync-DocumentFile (lib-doc.ps1) pra badge/footer sairem corretos ja
# nesta mesma rodada, sem esperar o proximo sync-all.
$pending = @($all | Where-Object { $_.PrPending })
if ($pending.Count -gt 0) {
    $ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    if (-not $ghAvailable) {
        Write-Host "dashboard: 'gh' nao encontrado no PATH - pulando sweep de PR pendente ($($pending.Count) doc(s))." -ForegroundColor Yellow
    }
    foreach ($doc in $pending) {
        if (-not $ghAvailable) { continue }
        # pr_pending pode ter VARIAS URLs (task "migration espelho" - 1 PR
        # por ambiente, separadas por espaco no mesmo campo). Checar TODAS,
        # nao so' a primeira - senao a 1a mergear ja fecha a task inteira e
        # apaga o rastro das URLs restantes ainda abertas (bug real,
        # encontrado 2026-08-25).
        $urls = @([regex]::Matches($doc.PrPending, $prLinkPattern) | ForEach-Object { $_.Value })
        if ($urls.Count -eq 0) {
            Write-Host "dashboard: pr_pending com formato inesperado em $($doc.Path): $($doc.PrPending)" -ForegroundColor Yellow
            continue
        }
        $stillPending = New-Object System.Collections.Generic.List[string]
        $newlyMerged = New-Object System.Collections.Generic.List[string]
        $newlyRejected = New-Object System.Collections.Generic.List[string]
        $anyResolved = $false
        foreach ($url in $urls) {
            if ($url -notmatch 'github\.com/([^/]+)/([^/]+)/pull/(\d+)') { $stillPending.Add($url); continue }
            $ghRepo = "$($Matches[1])/$($Matches[2])"
            $prNumber = $Matches[3]
            try {
                $json = gh pr view $prNumber --repo $ghRepo --json state 2>$null | ConvertFrom-Json
            } catch { $json = $null }
            if (-not $json -or $json.state -eq 'OPEN') { $stillPending.Add($url); continue }
            $anyResolved = $true
            if ($json.state -eq 'MERGED') { $newlyMerged.Add($url) } else { $newlyRejected.Add($url) }
        }
        if (-not $anyResolved) { continue }

        $raw = [IO.File]::ReadAllText($doc.Path)
        $parsed = Parse-Frontmatter $raw
        if (-not $parsed) { continue }
        $meta = $parsed.Meta
        $body = Get-ContentBody $parsed.Body

        # Acumula com o que ja existia no campo (nao sobrescreve - uma
        # rodada anterior do sweep pode ja ter marcado outras URLs).
        if ($newlyMerged.Count -gt 0) {
            $prior = if ($doc.PrMerged) { $doc.PrMerged.Trim() + ' ' } else { '' }
            $meta['pr_merged'] = ($prior + ($newlyMerged -join ' ')).Trim()
            $doc.PrMerged = $meta['pr_merged']
        }
        if ($newlyRejected.Count -gt 0) {
            $prior = if ($doc.PrRejected) { $doc.PrRejected.Trim() + ' ' } else { '' }
            $meta['pr_rejected'] = ($prior + ($newlyRejected -join ' ')).Trim()
            $doc.PrRejected = $meta['pr_rejected']
        }

        $note = $null
        if ($stillPending.Count -eq 0) {
            $meta.Remove('pr_pending')
            $doc.PrPending = ''
            # archived/superseded = doc ja saiu de cena (ex.: delegada que o
            # TechLead assumiu): registra pr_merged, mas nunca reabre o status
            # (bug real, 2026-10-02: delegada 111202 archived virou completed).
            if ($newlyRejected.Count -eq 0 -and $meta['status'] -notin @('archived', 'superseded')) {
                # Todas as URLs mergearam, nenhuma rejeitada - so' ENTAO
                # fecha a task. Se sobrou alguma rejeitada junto das
                # mergeadas, e' estado misto - nao flipa status sozinho,
                # mesmo principio do PR unico fechado sem merge (quem
                # decide o que fazer e' o usuario).
                $meta['status'] = 'completed'
                $doc.Status = 'completed'
                $note = 'Mergeado em `develop`/`production` (deteccao automatica) - sem pendencia de codigo, so ajustes se vier retorno de QA.'
            }
        } else {
            $meta['pr_pending'] = ($stillPending -join ' ')
            $doc.PrPending = $meta['pr_pending']
        }

        if ($note -and $body -notmatch '(?:Mergeado em|PR fechado sem merge)') {
            if ($body -match '(?m)^# .*$') {
                $m = [regex]::Match($body, '(?m)^# .*$')
                $insertAt = $m.Index + $m.Length
                $body = $body.Substring(0, $insertAt) + "`n`n**Status:** $note" + $body.Substring($insertAt)
            }
        }

        [IO.File]::WriteAllText($doc.Path, (Serialize-Frontmatter $meta) + $body)
        Sync-DocumentFile $doc.Path | Out-Null

        $resolvedCount = $newlyMerged.Count + $newlyRejected.Count
        Write-Host "dashboard: $resolvedCount/$($urls.Count) PR(s) resolvido(s) ($($newlyMerged.Count) mergeado(s), $($newlyRejected.Count) rejeitado(s)) - $($doc.Path.Substring($root.Length + 1)) atualizado automaticamente."
    }
}

# Backfill INCREMENTAL (nao 1x por doc): link de PR encontrado no corpo
# (jeito antigo, so' texto solto) mas AINDA nao coberto por nenhum dos 3
# campos (pr_pending/pr_merged/pr_rejected) tem estado desconhecido pro
# pill colorido. Roda em QUALQUER sync-all.ps1, de qualquer task/sessao -
# nao so' verifica os PRs pendentes conhecidos (sweep acima), mas tambem
# descobre PR que foi mencionado em prosa e nunca ganhou campo nenhum
# (fix de review em PR separado, por exemplo). Guarda por LINK, nao por
# doc: um doc que ja tem `pr_merged` com 1 URL ainda entra aqui se o
# corpo mencionar uma 2a URL que esse campo nao cobre - a guarda antiga
# ("doc ja tem qualquer campo preenchido = nunca mais confere") deixava
# PR novo em doc antigo pendurado cinza pra sempre (bug real, encontrado
# manualmente 2026-08-25 em 4 PRs - #300/#394/#395/#176 - o motivo desta
# reescrita: "verificar de uma vez, sem precisar voltar depois").
$unknown = @($all | Where-Object {
    if ($_.Body -notmatch $prLinkPattern) { return $false }
    $knownUrls = "$($_.PrPending) $($_.PrMerged) $($_.PrRejected)"
    @([regex]::Matches($_.Body, $prLinkPattern) | ForEach-Object { $_.Value } | Where-Object { -not $knownUrls.Contains($_) }).Count -gt 0
})
if ($unknown.Count -gt 0) {
    $ghAvailable = $null -ne (Get-Command gh -ErrorAction SilentlyContinue)
    foreach ($doc in $unknown) {
        if (-not $ghAvailable) { break }
        # So' os links que AINDA nao estao em nenhum dos 3 campos - nao
        # re-consulta `gh` pra link ja conhecido (mesma guarda barata de
        # rede de antes, so' que por link, nao por doc inteiro).
        $knownUrls = "$($doc.PrPending) $($doc.PrMerged) $($doc.PrRejected)"
        $links = @([regex]::Matches($doc.Body, $prLinkPattern) | ForEach-Object { $_.Value } | Select-Object -Unique | Where-Object { -not $knownUrls.Contains($_) })
        if ($links.Count -eq 0) { continue }
        $merged = New-Object System.Collections.Generic.List[string]
        $rejected = New-Object System.Collections.Generic.List[string]
        $stillPending = New-Object System.Collections.Generic.List[string]
        foreach ($link in $links) {
            if ($link -notmatch 'github\.com/([^/]+)/([^/]+)/pull/(\d+)') { continue }
            $ghRepo = "$($Matches[1])/$($Matches[2])"
            $prNumber = $Matches[3]
            try {
                $json = gh pr view $prNumber --repo $ghRepo --json state 2>$null | ConvertFrom-Json
            } catch { $json = $null }
            if (-not $json) { continue }
            if ($json.state -eq 'MERGED') { $merged.Add($link) }
            elseif ($json.state -eq 'CLOSED') { $rejected.Add($link) }
            else { $stillPending.Add($link) }
        }
        if ($merged.Count -eq 0 -and $rejected.Count -eq 0 -and $stillPending.Count -eq 0) { continue }

        $raw = [IO.File]::ReadAllText($doc.Path)
        $parsed = Parse-Frontmatter $raw
        if (-not $parsed) { continue }
        $meta = $parsed.Meta
        # Acumula com o que ja existia - nunca sobrescreve (doc que ja
        # tinha pr_merged com outra URL continua com as duas).
        if ($merged.Count -gt 0) {
            $prior = if ($doc.PrMerged) { $doc.PrMerged.Trim() + ' ' } else { '' }
            $meta['pr_merged'] = ($prior + ($merged -join ' ')).Trim(); $doc.PrMerged = $meta['pr_merged']
        }
        if ($rejected.Count -gt 0) {
            $prior = if ($doc.PrRejected) { $doc.PrRejected.Trim() + ' ' } else { '' }
            $meta['pr_rejected'] = ($prior + ($rejected -join ' ')).Trim(); $doc.PrRejected = $meta['pr_rejected']
        }
        if ($stillPending.Count -gt 0) {
            $prior = if ($doc.PrPending) { $doc.PrPending.Trim() + ' ' } else { '' }
            $meta['pr_pending'] = ($prior + ($stillPending -join ' ')).Trim(); $doc.PrPending = $meta['pr_pending']
        }
        [IO.File]::WriteAllText($doc.Path, (Serialize-Frontmatter $meta) + (Get-ContentBody $parsed.Body))
        Sync-DocumentFile $doc.Path | Out-Null
    }
    if ($ghAvailable) {
        Write-Host "dashboard: backfill de estado de PR - $($unknown.Count) doc(s) com link novo verificado(s)."
    }
}

# task "general" nao tem id real - agrupa por `cluster` quando presente (mesmo
# texto em todo doc do assunto = mesmo grupo, independente de repo/related).
# Sem cluster, cai no fallback antigo: doc `resumo` agrupa pelo 1o doc em
# `related:` (o doc-fonte), senao vira card solto (mesma regra do status.ps1).
$groups = $ownDocs | Group-Object {
    if ($_.Task -eq 'general') {
        if ($_.Cluster) {
            # cluster+repo, nao so cluster: mesmo assunto em repos diferentes
            # (ex.: CRUD frontend vs backend) continua card separado por repo,
            # igual toda task numerica ja funciona hoje ("$Task|$Repo").
            "cluster|$($_.Cluster)|$($_.Repo)"
        } elseif ($_.Type -eq 'resumo' -and @($_.Related | Where-Object { $_ }).Count -gt 0) {
            $rel = ([string]@($_.Related | Where-Object { $_ })[0]).Trim() -replace '/', '\'
            Join-Path $root $rel
        } else {
            $_.Path
        }
    } else {
        "$($_.Task)|$($_.Repo)"
    }
}

$cards = @()
foreach ($g in $groups) {
    $docs = $g.Group | Sort-Object { if ($typeOrder.ContainsKey($_.Type)) { $typeOrder[$_.Type] } else { 99 } }
    # resumo e' dado pro dashboard consumir, nao entra nos chips nem pode
    # ser o doc "representante" (task-code tem prioridade pra isso). Ignora
    # superseded/archived na escolha - defensivo contra a colisao de
    # 2026-08-14 (resumo substituido esquecido na pasta normal em vez de
    # fisicamente movido pra _archive/ ainda nao devia "vencer" a escolha).
    # `task` (formato unico) faz o papel de resumo E continua como chip/representante.
    $resumoDoc = $docs | Where-Object { $_.Type -in @('task', 'resumo') -and $_.Status -notin @('superseded', 'archived') } | Sort-Object { if ($_.Type -eq 'task') { 0 } else { 1 } } | Select-Object -First 1
    $docs = @($docs | Where-Object { $_.Type -ne 'resumo' })
    if ($docs.Count -eq 0 -and $resumoDoc) { $docs = @($resumoDoc) }
    $rep = $docs | Select-Object -First 1
    $isActive = @($docs | Where-Object { $_.Status -in $activeStatuses }).Count -gt 0
    $latestDoc = ($docs | Where-Object { $_.Updated } | Sort-Object Updated -Descending | Select-Object -First 1)
    $latest = $latestDoc.Updated
    $latestTime = $latestDoc.UpdatedTime
    # PR, Azure e o status por camada (Get-LayerStates) aparecem em
    # Ativas E Completas por igual - nenhum e' restrito a tasks ativas.
    $signals = Get-Signals $docs $rep.Task
    # cluster opcional (so faz diferenca pra task "general" - o card mostra
    # "Geral" por padrao, sem jeito de distinguir varios de cor no dashboard;
    # qualquer doc do grupo com `cluster:` no frontmatter vira o titulo do card
    # - e agora tambem a propria chave de agrupamento, ver Group-Object acima)
    $cardCluster = ($docs + $resumoDoc | Where-Object { $_ -and $_.Cluster } | Select-Object -First 1).Cluster
    # pseudo_task e' opcional mesmo em cluster "general" - so os que quiserem
    # um numero curto pra achar por busca (ver 01-regras-biblioteca.md).
    $cardPseudoTask = ($docs + $resumoDoc | Where-Object { $_ -and $_.PseudoTask } | Select-Object -First 1).PseudoTask
    # titulo_busca e' opcional (campo novo, docs antigos nao tem) - pega o
    # primeiro preenchido no grupo, mesma logica de cluster/pseudo_task acima.
    # Sem valor, o card cai pro fallback de Function (ver Build-Card).
    $cardTituloBusca = ($docs + $resumoDoc | Where-Object { $_ -and $_.TituloBusca } | Select-Object -First 1).TituloBusca
    $cards += [PSCustomObject]@{
        Task      = $rep.Task
        Repo      = $rep.Repo
        Function  = $rep.Function
        TituloBusca = $cardTituloBusca
        Cluster   = $cardCluster
        PseudoTask = $cardPseudoTask
        Active    = $isActive
        Updated   = $latest
        UpdatedTime = $latestTime
        Docs      = $docs
        Signals   = $signals
        RepPath   = $rep.Path
        ResumoDoc = $resumoDoc
        Branch    = if ($resumoDoc) { $resumoDoc.Branch } else { '' }
    }
}

# Related tasks (cross-repo): mesma task numerica, ou mesmo cluster exato
# (so' task "general"), aparecendo em outro card/repo. Usado na pagina de
# resumo (Get-RelatedTasksHtml) e no status por camada do card
# (Get-LayerStates, precisa vir antes de Build-Card ser chamado mais
# abaixo). As duas listas sao mutuamente exclusivas por construcao (Task
# numerica cai so' aqui, "general"+Cluster cai so' ali) - nunca precisa
# deduplicar um card que bateria nos dois.
$cardsByTask = @{}
$cardsByCluster = @{}
foreach ($c in $cards) {
    if ($c.Task -match '^\d+$') {
        if (-not $cardsByTask.ContainsKey($c.Task)) { $cardsByTask[$c.Task] = @() }
        $cardsByTask[$c.Task] += $c
    } elseif ($c.Cluster) {
        if (-not $cardsByCluster.ContainsKey($c.Cluster)) { $cardsByCluster[$c.Cluster] = @() }
        $cardsByCluster[$c.Cluster] += $c
    }
}

# NOTA: card.Signals.PRs NAO e mais sobrescrito com a uniao dos irmaos
# aqui - cada card volta a expor so' os PRs do proprio repo (Get-ExtLinksHtml
# na grade). A uniao cross-repo agora e' calculada sob demanda: dentro de
# Get-LayerStates (sempre, painel de status por camada - compacto,
# faz sentido em qualquer card da task) e dentro de Get-ExtLinksHtml so'
# quando chamada com -AllSiblings (pagina de resumo, o "principal" que
# mostra todos os PRs da task inteira). Decisao 2026-08-25: card da grade
# poluia (lista de ~13 PRs identica nos 3 cards de uma task multi-repo,
# mesmo cada card sendo de 1 repo so') - resumo ja tinha Get-RelatedTasksHtml
# linkando pros outros repos da mesma task, virou o lugar natural pra
# mostrar a lista completa.

# Conversor leve pro corpo das secoes do resumo - nao e' um motor de
# markdown generico, so o suficiente pro que um agente escreve ali:
# paragrafos, bullets, **bold**, [texto](url http/https).
function Format-InlineMd([string]$s) {
    $c = Esc $s
    $c = $c -replace '\[([^\]]+)\]\((https?://[^)]+)\)', '<a href="$2" target="_blank">$1</a>'
    $c = $c -replace '\*\*([^*]+)\*\*', '<strong>$1</strong>'
    $c = $c -replace '`([^`]+)`', '<code>$1</code>'
    return $c
}

# Nao e' um motor de markdown generico, so o suficiente pro que um agente
# escreve ali: paragrafos, bullets, **bold**, [texto](url http/https).
# Junta linhas fisicas consecutivas (prosa hard-wrapped ~80 chars, convencao
# de todo doc da Biblioteca) numa unica <p> - bug real corrigido 2026-08-25:
# a versao anterior tratava CADA quebra de linha do markdown-fonte como um
# paragrafo novo (1 <p> por linha fisica, nao por paragrafo logico),
# fragmentando toda secao de resumo da Biblioteca inteira em dezenas de
# <p> de 1 linha cada. So' quebra paragrafo em linha em branco de verdade
# ou ao entrar/sair de uma lista.
function Convert-SectionHtml([string]$text) {
    $text = if ($text) { $text.Trim() } else { '' }
    # tira comentarios HTML (ex: dica de preenchimento deixada no template)
    # antes de qualquer coisa - senao vazam como texto escapado na pagina
    $text = [regex]::Replace($text, '(?s)<!--.*?-->', '').Trim()
    if (-not $text) { return '<p class="empty">(vazio)</p>' }
    $lines = $text -split "`r?`n"
    $htmlLines = New-Object System.Collections.Generic.List[string]
    $paraBuffer = New-Object System.Collections.Generic.List[string]
    $listItemBuffer = New-Object System.Collections.Generic.List[string]
    $inList = $false

    function Flush-Para {
        if ($paraBuffer.Count -gt 0) {
            $htmlLines.Add("<p>$(Format-InlineMd ($paraBuffer -join ' '))</p>")
            $paraBuffer.Clear()
        }
    }
    function Flush-ListItem {
        if ($listItemBuffer.Count -gt 0) {
            $htmlLines.Add("<li>$(Format-InlineMd ($listItemBuffer -join ' '))</li>")
            $listItemBuffer.Clear()
        }
    }

    foreach ($line in $lines) {
        $t = $line.Trim()
        if (-not $t) { Flush-ListItem; Flush-Para; continue }
        $isBullet = $t -match '^[-*]\s+(.*)'
        if ($isBullet) {
            Flush-Para
            Flush-ListItem
            if (-not $inList) { $htmlLines.Add('<ul>'); $inList = $true }
            $listItemBuffer.Add($Matches[1])
        } elseif ($inList -and $listItemBuffer.Count -gt 0) {
            # Continuacao do item de lista atual (linha indentada sem
            # marcador, mesma convencao de todo doc da Biblioteca - "- foo"
            # seguido de linhas com 2 espacos de indentacao, sem linha em
            # branco entre elas).
            $listItemBuffer.Add($t)
        } else {
            if ($inList) { Flush-ListItem; $htmlLines.Add('</ul>'); $inList = $false }
            $paraBuffer.Add($t)
        }
    }
    Flush-ListItem
    Flush-Para
    if ($inList) { $htmlLines.Add('</ul>') }
    return ($htmlLines -join "`n")
}

$resumoSectionOrder = @('Status atual', 'O que foi implementado', 'REQs seguidas', 'O que falta')

function Get-ResumoSections([string]$body) {
    $clean = Strip-GeneratedParts $body
    $sections = @{}
    foreach ($n in $resumoSectionOrder) { $sections[$n] = '' }
    $sectionMatches = [regex]::Matches($clean, '(?m)^##\s+(.+?)\s*$')
    for ($i = 0; $i -lt $sectionMatches.Count; $i++) {
        $title = $sectionMatches[$i].Groups[1].Value.Trim()
        $start = $sectionMatches[$i].Index + $sectionMatches[$i].Length
        $end = if ($i + 1 -lt $sectionMatches.Count) { $sectionMatches[$i + 1].Index } else { $clean.Length }
        $content = $clean.Substring($start, $end - $start)
        if ($sections.ContainsKey($title)) { $sections[$title] = $content }
    }
    return $sections
}

# Dados de "Rodadas de QA" - le as secoes "## Ajustes QA - rodada N" que
# ja existem nos docs `testes/` do proprio card (mesmo repo, task-hub-qa
# ja grava uma por rodada) e devolve um objeto por rodada (numero, data,
# teaser, PRs mencionados so' NAQUELA secao, doc de origem). Nao cria doc
# novo nem campo novo - so' le o que ja existe. Consumido por
# Build-QaRoundCard pra virar card de verdade na grade principal (nao
# fica escondido so' na pagina de resumo).
# Acha o campo `- **Label:** texto` (bullet opcional) dentro de uma secao
# de rodada de QA - junta linhas de continuacao (mesma convencao de
# indentacao/wrap de todo doc da Biblioteca), para no proximo campo em
# negrito ou linha em branco. $null se o label nao existir na secao
# (rodada ainda no formato antigo, sem os 3 campos padronizados).
function Get-QaFieldValue([string]$sectionBody, [string]$label) {
    $lines = $sectionBody -split "`r?`n"
    $labelPattern = "^-?\s*\*\*$([regex]::Escape($label)):\*\*\s*(.*)$"
    # Fronteira = qualquer bullet novo (com ou sem label em negrito) ou
    # label solto sem bullet - continuacao de verdade nesta convencao
    # nunca comeca com "-" (e' sempre texto indentado simples). Sem
    # cobrir "^-\s" aqui, um bullet extra sem negrito logo depois do
    # campo (ex.: "- Detalhe completo: ver...") era engolido como se
    # fosse continuacao do campo anterior (bug real, 2026-08-25).
    $boundaryPattern = '^-\s|^\*\*'
    $collecting = $false
    $buffer = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($collecting) {
            if (-not $t -or $t -match $boundaryPattern) { break }
            $buffer.Add($t)
            continue
        }
        if ($t -match $labelPattern) {
            $collecting = $true
            $first = $Matches[1].Trim()
            if ($first) { $buffer.Add($first) }
        }
    }
    if ($buffer.Count -eq 0) { return $null }
    $joined = ($buffer -join ' ') -replace '\*\*([^*]+)\*\*', '$1' -replace '`([^`]+)`', '$1' -replace '\[([^\]]+)\]\(https?://[^)]+\)', '$1'
    return $joined.Trim()
}

# HTML de exibicao de UMA rodada de QA - cada campo (Reportado/Causa
# raiz/Corrigido) em linha propria com label em negrito, junto via <br>
# dentro do MESMO <p> (nao 3 <p> separados) - um bloco visual so, sem
# espacamento extra de paragrafo entre os campos. Cai pro teaser bruto
# (1o paragrafo, ja sem markdown) quando a rodada nao tem os campos
# padronizados ainda.
function Get-QaFieldsHtml([PSCustomObject]$round) {
    if ($round.Reportado) {
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add("<strong>Reportado:</strong> $(Esc $round.Reportado)")
        if ($round.CausaRaiz) { $lines.Add("<strong>Causa raiz:</strong> $(Esc $round.CausaRaiz)") }
        if ($round.Corrigido) { $lines.Add("<strong>Corrigido:</strong> $(Esc $round.Corrigido)") }
        return $lines -join '<br>'
    }
    return Esc $round.Teaser
}

# Mesmo conteudo de Get-QaFieldsHtml, mas texto puro (sem HTML) - pro
# indice de busca (data-search), nunca pra exibicao.
function Get-QaSearchText([PSCustomObject]$round) {
    if ($round.Reportado) {
        $parts = New-Object System.Collections.Generic.List[string]
        $parts.Add("Reportado: $($round.Reportado)")
        if ($round.CausaRaiz) { $parts.Add("Causa raiz: $($round.CausaRaiz)") }
        if ($round.Corrigido) { $parts.Add("Corrigido: $($round.Corrigido)") }
        return $parts -join ' '
    }
    return $round.Teaser
}

function Get-QaRounds([PSCustomObject]$card) {
    $testesDocs = @($card.Docs | Where-Object { $_.Type -in $testBodyTypes })
    if ($testesDocs.Count -eq 0) { return @() }

    $rounds = New-Object System.Collections.Generic.List[object]
    foreach ($doc in $testesDocs) {
        $parts = $doc.Body -split '(?m)(?=^## )'
        $roundIndex = 0
        foreach ($p in $parts) {
            $firstLine = ($p -split "`n")[0]
            if ($firstLine -notmatch 'Ajustes QA') { continue }
            $roundIndex++
            # Numero da rodada vem do proprio heading quando existe
            # ("rodada N") - so' cai pro contador posicional se a secao
            # nao foi numerada (task-hub-qa permite a 1a rodada sem
            # numero, ver SKILL.md).
            $roundNum = if ($firstLine -match 'rodada\s+(\d+)') { $Matches[1] } else { "$roundIndex" }
            $dateLabel = if ($firstLine -match '(\d{4}-\d{2}-\d{2})') { $Matches[1] } else { $doc.Updated }

            # Campos padronizados: Reportado/Causa raiz/Corrigido (formato
            # obrigatorio no task-hub-qa, ver SKILL.md) - mantidos
            # SEPARADOS aqui (nao junta numa string so') pra quem
            # renderiza o card (Get-QaFieldsHtml) poder formatar cada um
            # em linha propria com label em negrito - um paragrafo so'
            # com tudo junto (jeito anterior) ficava dificil de ler.
            # $teaser (1o paragrafo bruto) e' so' o fallback pra rodada
            # que ainda nao foi migrada pro formato novo (Reportado
            # ausente). Texto sempre COMPLETO, sem cortar aqui - o corte
            # visual (clamp + botao de expandir) e' so' CSS/JS no card.
            $reportado = Get-QaFieldValue $p 'Reportado'
            $causaRaiz = if ($reportado) { Get-QaFieldValue $p 'Causa raiz' } else { $null }
            $corrigido = if ($reportado) { Get-QaFieldValue $p 'Corrigido' } else { $null }
            $teaser = if (-not $reportado) {
                $bodyText = ($p -split "`n", 2)[1]
                $firstPara = if ($bodyText) { (($bodyText.Trim() -split "`r?`n`r?`n")[0] -replace '\s+', ' ').Trim() } else { '' }
                $firstPara -replace '\*\*([^*]+)\*\*', '$1' -replace '`([^`]+)`', '$1' -replace '\[([^\]]+)\]\(https?://[^)]+\)', '$1'
            } else { $null }

            # PRs so' dessa rodada (regex escopada ao texto da secao $p,
            # nao ao doc inteiro) - e' isso que faz o card da rodada
            # mostrar so' o que e' relevante pra ela, nao a lista inteira
            # do repo (mesmo motivo da mudanca de Get-ExtLinksHtml desta
            # sessao).
            $prs = New-Object System.Collections.Generic.List[string]
            foreach ($m in [regex]::Matches($p, 'https?://github\.com/\S*?/pull/\d+')) {
                if (-not $prs.Contains($m.Value)) { $prs.Add($m.Value) }
            }

            $rounds.Add([PSCustomObject]@{
                RoundNum  = $roundNum
                DateLabel = $dateLabel
                Reportado = $reportado
                CausaRaiz = $causaRaiz
                Corrigido = $corrigido
                Teaser    = $teaser
                PRs       = @($prs)
                TestesDoc = $doc
            })
        }
    }
    # .ToArray(), nao @($rounds) - nesta maquina, @() aplicado direto
    # (fora de pipeline) sobre List[object] lanca "Os tipos de argumento
    # nao correspondem" (ArgumentException), diferente de List[string]
    # (funciona) ou de uma lista passada por pipeline antes do @() (ver
    # padrao @($allDocs | Where-Object {...}) usado no resto do arquivo -
    # esse funciona pq o pipe ja converteu pra stream antes do @()).
    return $rounds.ToArray()
}

# ---------------------------------------------------------------------------
# Dados do dashboard (data.js) - desde 2026-11-17 o dashboard.html e' uma
# pagina fixa (dashboard.html + assets/app.css + assets/app.js) que monta a
# tela a partir de window.BIBLIOTECA. Aqui so' calculo: estado de PR, camadas,
# rodadas de QA, comandos, resumo. HTML so' onde ja vinha pronto (secoes do
# resumo via Convert-SectionHtml, campos de QA via Get-QaFieldsHtml).
# ---------------------------------------------------------------------------

# Estado real de UM PR (mesma regra das pills antigas: olha pr_merged/
# pr_rejected/pr_pending dos docs passados - Contains, campo pode ter
# varias URLs).
function Get-PrData([string]$pr, $docs) {
    $state = 'unknown'
    if (@($docs | Where-Object { $_ -and $_.PrMerged -and $_.PrMerged.Contains($pr) }).Count -gt 0) { $state = 'merged' }
    elseif (@($docs | Where-Object { $_ -and $_.PrRejected -and $_.PrRejected.Contains($pr) }).Count -gt 0) { $state = 'rejected' }
    elseif (@($docs | Where-Object { $_ -and $_.PrPending -and $_.PrPending.Contains($pr) }).Count -gt 0) { $state = 'open' }
    $m = [regex]::Match($pr, 'github\.com/[^/]+/([^/]+)/pull/(\d+)')
    return [ordered]@{ url = $pr; repo = $m.Groups[1].Value; num = $m.Groups[2].Value; state = $state; layer = (Get-PrKindInfo $pr).Layer }
}

# Uma rodada de QA (card proprio na aba Ativas, lista no painel de resumo).
# $entries = 1 a 3 itens { Card; Round; LayerLabel } - 2+ = mesma rodada
# feita junto em varias camadas da task, vira um card so'.
function Get-QaRoundData($entries) {
    $entries = @($entries)
    $first = $entries[0].Card
    $layerLine = (@($entries | ForEach-Object { $_.LayerLabel } | Where-Object { $_ })) -join ' + '
    $label = "QA #$($entries[0].Round.RoundNum)"
    if ($layerLine) { $label += " $($script:EmDash) $layerLine" }
    $stateDocs = @($entries | ForEach-Object { @($_.Card.Docs) + @(if ($_.Card.ResumoDoc) { $_.Card.ResumoDoc }) })
    $prUrls = New-Object System.Collections.Generic.List[string]
    foreach ($e in $entries) { foreach ($pr in $e.Round.PRs) { if (-not $prUrls.Contains($pr)) { $prUrls.Add($pr) } } }
    $multi = $entries.Count -gt 1
    $cmds = New-Object System.Collections.Generic.List[object]
    foreach ($e in $entries) {
        foreach ($c in (Get-CardCommands $e.Card | Where-Object { $_.Label -eq 'Reabrir p/ QA' })) {
            $lbl = if ($multi -and $e.LayerLabel) { "Reabrir p/ QA ($($e.LayerLabel.ToLowerInvariant()))" } else { 'Reabrir p/ QA' }
            $cmds.Add([ordered]@{ label = $lbl; kind = 'qa'; cmd = $c.Cmd; uri = $c.Uri })
        }
    }
    $searchText = (@($entries | ForEach-Object { Get-QaSearchText $_.Round }) | Where-Object { $_ }) -join ' '
    return [ordered]@{
        id       = (@($entries | ForEach-Object { "$($_.Round.TestesDoc.Path)#qa$($_.Round.RoundNum)" })) -join '+'
        title    = if ($first.TituloBusca) { $first.TituloBusca } else { "Task $($first.Task)" }
        label    = $label
        task     = $first.Task
        repo     = (@($entries | ForEach-Object { $_.Card.Repo })) -join ' + '
        date     = $entries[0].Round.DateLabel
        prs      = @($prUrls | ForEach-Object { Get-PrData $_ $stateDocs })
        boxes    = @($entries | ForEach-Object { [ordered]@{ label = $(if ($multi) { "$($_.LayerLabel)" } else { '' }); html = (Get-QaFieldsHtml $_.Round) } })
        commands = $cmds.ToArray()
        search   = ("$label $($first.TituloBusca) $($first.Task) $searchText").ToLowerInvariant()
    }
}

# Um card (task+repo) com tudo que a tela precisa. $qa = rodadas ja
# calculadas (Get-QaRoundData) que pertencem a este card.
function Get-CardData([PSCustomObject]$card, $qa) {
    $isNum = $card.Task -match '^\d+$'
    $label = if ($card.Cluster) { $card.Cluster } elseif (-not $isNum) { 'Geral' } else { "Task $($card.Task)" }
    # Estado de PR olha os docs de todos os irmaos (outro repo da mesma task
    # pode ter o pr_merged daquele link) - mesma regra do Get-ExtLinksHtml.
    $stateDocs = New-Object System.Collections.Generic.List[object]
    foreach ($s in (Get-TaskSiblings $card)) {
        foreach ($d in $s.Docs) { $stateDocs.Add($d) }
        if ($s.ResumoDoc) { $stateDocs.Add($s.ResumoDoc) }
    }
    $summary = $null
    if ($card.ResumoDoc) {
        $sec = Get-ResumoSections $card.ResumoDoc.Body
        $allPrs = New-Object System.Collections.Generic.List[string]
        foreach ($s in (Get-TaskSiblings $card)) { foreach ($pr in $s.Signals.PRs) { if (-not $allPrs.Contains($pr)) { $allPrs.Add($pr) } } }
        $summary = [ordered]@{
            status       = Convert-SectionHtml $sec['Status atual']
            falta        = Convert-SectionHtml $sec['O que falta']
            implementado = Convert-SectionHtml $sec['O que foi implementado']
            reqs         = Convert-SectionHtml $sec['REQs seguidas']
            teams        = Get-TeamsText $card $sec
            prs          = @($allPrs | ForEach-Object { Get-PrData $_ $stateDocs })
            related      = @(@($card.ResumoDoc.Related) | Where-Object { $_ } | ForEach-Object {
                [ordered]@{ label = (Split-Path $_.Trim() -Leaf); url = 'file:///' + (($root.TrimEnd('\') + '\' + $_.Trim()) -replace '\\', '/') }
            })
        }
    }
    return [ordered]@{
        id       = $card.RepPath
        task     = $card.Task
        isNum    = $isNum
        label    = $label
        title    = if ($card.TituloBusca) { $card.TituloBusca } else { $label }
        func     = $card.Function
        repos    = @($card.Repo -split '[\s,]+' | Where-Object { $_ })
        updated  = $card.Updated
        time     = $card.UpdatedTime
        active   = [bool]$card.Active
        azure    = $(if ($azureBase -and $isNum) { "$azureBase/$($card.Task)" } else { '' })
        prs      = @($card.Signals.PRs | ForEach-Object { Get-PrData $_ $stateDocs })
        layers   = @(Get-LayerStates $card)
        docs     = @($card.Docs | ForEach-Object {
            [ordered]@{
                type = $_.Type
                label = $(if ($script:TypeLabels.ContainsKey($_.Type)) { $script:TypeLabels[$_.Type] } else { $_.Type })
                status = $_.Status
                statusLabel = $(if ($script:StatusLabels.ContainsKey($_.Status)) { $script:StatusLabels[$_.Status] } else { $_.Status })
                url = 'file:///' + ($_.Path -replace '\\', '/')
            }
        })
        commands = @(Get-CardCommands $card | ForEach-Object { [ordered]@{ label = $_.Label; kind = $(if ($_.Label -like 'Reabrir*') { 'qa' } else { 'resume' }); cmd = $_.Cmd; uri = $_.Uri } })
        summary  = $summary
        qa       = @($qa | Where-Object { $_ })
        search   = ("$label $($card.Task) $($card.Repo) $($card.Function) $($card.TituloBusca)").ToLowerInvariant()
    }
}
# Texto pronto pro Teams (texto puro: sem markdown, sem URL, sem run id/hash).
# So' o card ancora como ID - PRs, Task QA e afins ficam no doc, nao na
# mensagem. Fonte: secoes "Status atual" e "O que falta" do resumo/task.
function Get-TeamsText([PSCustomObject]$card, $sections) {
    function Clean-TeamsLines([string]$text, [int]$max) {
        # Junta continuacao hard-wrapped (indentada, sem marcador) no item
        # anterior; sub-bullet indentado (lista de PRs/URLs) e' detalhe e fica
        # no doc, junto com as continuacoes dele.
        $items = New-Object System.Collections.Generic.List[string]
        $skipping = $false
        foreach ($l in ([regex]::Replace("$text", '(?s)<!--.*?-->', '') -split "`r?`n")) {
            if (-not $l.Trim()) { $skipping = $false; continue }
            $indented = $l -match '^\s{2,}'
            $bullet = $l -match '^\s*(?:[-*]|\d+\.)\s'
            if ($indented -and $bullet) { $skipping = $true; continue }
            if ($indented) { if (-not $skipping -and $items.Count) { $items[$items.Count - 1] += ' ' + $l.Trim() }; continue }
            $skipping = $false
            $items.Add($l)
        }
        $out = @()
        foreach ($t in $items) {
            $t = $t -replace 'https?://\S+', '' -replace '\brun \d+', '' -replace '\b(?=[0-9a-f]*[a-f])(?=[0-9a-f]*\d)[0-9a-f]{7,40}\b', '' -replace '[`*>]', '' -replace '#{2,}\s*', ''
            $t = ($t -replace '^\s*(?:[-*]|\d+\.)\s+', '' -replace '\s{2,}', ' ' -replace '\s+([,.;)])', '$1').Trim(' ', ':', '-', ',')
            if ($t.Length -lt 4) { continue }
            $out += $t
            if ($out.Count -ge $max) { break }
        }
        return $out
    }
    $title = if ($card.TituloBusca) { $card.TituloBusca } else { $card.Function }
    $head = if ($card.Task -match '^\d+$') { "$($card.Task) $($script:EmDash) $title" } else { $title }
    $lines = @($head, '')
    $status = @(Clean-TeamsLines $sections['Status atual'] 4)
    if ($status.Count) { $lines += 'Status:'; $lines += $status; $lines += '' }
    $falta = @(Clean-TeamsLines $sections['O que falta'] 5)
    if ($falta.Count) { $lines += 'Falta:'; $lines += $falta }
    return ($lines -join "`n").Trim()
}

# Pagina de referencia rapida da paleta - so pra ver as cores/icones sem
# precisar procurar um card real que use cada um. Gerada junto com o
# dashboard, nao faz parte da navegacao de tasks.
function Build-PaletteHtml() {
    $chipTypes = @('task-code', 'task-planning', 'testes', 'handover-tecnico', 'rules')
    $chipRows = ($chipTypes | ForEach-Object {
        $type = $_
        $label = $script:TypeLabels[$type]
        $emoji = $script:StatusEmoji['in_progress']
        "<div class=`"swatch-row`"><a class=`"chip chip-$type`">$(Esc $label) $emoji</a><code>.chip-$type</code></div>"
    }) -join "`n"

    $statusRows = (@('draft', 'in_progress', 'completed') | ForEach-Object {
        $status = $_
        "<div class=`"swatch-row`"><span>$($script:StatusEmoji[$status]) $(Esc $script:StatusLabels[$status])</span><code>StatusEmoji.$status</code></div>"
    }) -join "`n"

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Paleta de cores</title>
<style>
$sharedCss
  :root { --current: #d97b3f; --current-glow: rgba(217, 123, 63, 0.28); }
  body {
    background: var(--bg); color: var(--text); max-width: 720px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0; padding: 24px 32px 64px;
  }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; }
  .back:hover { color: var(--gold-bright); }
  h1 { font-size: 1.3rem; margin: 14px 0 4px; color: #fff; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 0 0 24px; }
  section { margin-bottom: 28px; }
  h2 {
    font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--gold-bright); border-bottom: 1px solid var(--card-border); padding-bottom: 6px; margin: 0 0 12px;
  }
  .swatch-row {
    display: flex; align-items: center; justify-content: space-between; gap: 12px;
    padding: 8px 0; border-bottom: 1px solid #2a2c30;
  }
  .swatch-row code { font-size: 0.76rem; color: var(--text-faint); }
  .chip {
    font-size: 0.72rem; padding: 3px 9px; border-radius: 999px; text-decoration: none;
    border: 1px solid transparent; white-space: nowrap;
  }
  .chip-task-code { background: #332a12; color: #d9b568; border-color: #6b5628; }
  .chip-task-planning { background: #1a2e30; color: #7cbfc4; border-color: #355a5e; }
  .chip-testes { background: #1f2e22; color: #86b894; border-color: #3d5c44; }
  .chip-handover-tecnico { background: #2e1f28; color: #c184a0; border-color: #5c3a4f; }
  .chip-rules { background: #292420; color: #a89484; border-color: #4d413a; }
  .ext-link {
    display: inline-flex; align-items: center; gap: 6px; font-size: 0.78rem; font-weight: 500;
    padding: 4px 10px; border-radius: 999px; text-decoration: none;
    background: #2c3038; border: 1px solid #454a54; color: var(--gold-bright);
  }
  .ext-azure { background: #1f2a33; color: #7fa8c2; border-color: #3d5566; }
  .ext-github { border-color: #4d5560; }
  .ext-github-open { background: #242e1f; color: #a3b886; border-color: #4a5c3d; }
  .ext-github-merged { background: #281f33; color: #a996c4; border-color: #4f3d5c; }
  .ext-github-rejected { background: #33221f; color: #c98a7a; border-color: #5c3d34; }
  .chip-pend-draft { background: #2a2c30; color: #b0b4bc; border-color: #4a4e58; }
  .chip-pend-progress { background: #1f2733; color: #86a3d9; border-color: #3d4f6b; }
  .copy-btn {
    background: var(--gold-bg); color: var(--text); border: 1px solid var(--gold-border); border-radius: 6px;
    padding: 5px 10px; font-size: 0.76rem; cursor: pointer;
  }
  .qa-btn { border-color: #6b3f34; }
  .icon-sample { display: flex; align-items: center; gap: 10px; color: var(--text-dim); }
  .icon-sample.current { color: var(--current); }
  .icon-sample svg { width: 20px; height: 20px; }
  .badge-current {
    background: var(--current); color: #2b1d0a; font-weight: 700;
    font-size: 0.66rem; letter-spacing: 0.06em; text-transform: uppercase;
    padding: 3px 8px; border-radius: 999px;
  }
  .mini-card {
    background: var(--card-bg); border: 1px solid var(--current); border-radius: 10px;
    padding: 10px 14px; box-shadow: 0 0 0 1px var(--current), 0 0 16px -2px var(--current-glow);
    font-size: 0.8rem; color: var(--text-dim); width: fit-content;
  }
</style>
</head>
<body>
<a class="back" href="dashboard.html">&larr; Voltar ao dashboard</a>
<h1>Paleta de cores $($script:EmDash) Biblioteca</h1>
<p class="sub">Referencia rapida de todo icone/cor usado no dashboard e no resumo - so pra revisar sem precisar procurar um card real.</p>

<section>
  <h2>Chips por tipo de documento</h2>
  $chipRows
</section>

<section>
  <h2>Emoji de status (usado dentro dos chips)</h2>
  $statusRows
</section>

<section>
  <h2>Links externos</h2>
  <div class="swatch-row"><a class="ext-link ext-azure">$linkIcon Azure</a><code>.ext-link.ext-azure</code></div>
  <div class="swatch-row"><a class="ext-link ext-github">$githubIcon PR #000</a><code>.ext-link.ext-github</code></div>
  <div class="swatch-row"><a class="ext-link ext-github-open">$githubIcon PR #000</a><code>.ext-github-open (aberto)</code></div>
  <div class="swatch-row"><a class="ext-link ext-github-merged">$githubIcon PR #000</a><code>.ext-github-merged</code></div>
  <div class="swatch-row"><a class="ext-link ext-github-rejected">$githubIcon PR #000</a><code>.ext-github-rejected</code></div>
</section>

<section>
  <h2>Chips de status (pagina Pendencias)</h2>
  <div class="swatch-row"><span class="chip chip-pend-draft">Rascunho</span><code>.chip-pend-draft</code></div>
  <div class="swatch-row"><span class="chip chip-pend-progress">Em andamento</span><code>.chip-pend-progress</code></div>
</section>

<section>
  <h2>Status por camada (caixa "Pendencias" do card ativo)</h2>
  <div class="swatch-row"><div class="layer-row layer-done"><span class="layer-dot"></span><span class="layer-label">Backend</span><span class="layer-state">feito</span></div><code>.layer-done</code></div>
  <div class="swatch-row"><div class="layer-row layer-pending"><span class="layer-dot"></span><span class="layer-label">Frontend</span><span class="layer-state">pendente</span></div><code>.layer-pending</code></div>
  <div class="swatch-row"><div class="layer-row layer-na"><span class="layer-dot"></span><span class="layer-label">Migrations</span><span class="layer-state">nao necessario</span></div><code>.layer-na</code></div>
</section>

<section>
  <h2>Botoes de acao</h2>
  <div class="swatch-row"><button class="copy-btn">Retomar task</button><code>.copy-btn</code></div>
  <div class="swatch-row"><button class="copy-btn qa-btn">Reabrir p/ QA</button><code>.copy-btn.qa-btn</code></div>
</section>

<section>
  <h2>Icones</h2>
  <div class="swatch-row"><span class="icon-sample">$starIcon Estrela (normal)</span><code>.star-icon</code></div>
  <div class="swatch-row"><span class="icon-sample current">$starIcon Estrela (favorita/atual)</span><code>.card-current .star-icon</code></div>
  <div class="swatch-row"><span class="icon-sample">$bookIcon Ver resumo</span><code>.resumo-btn</code></div>
  <div class="swatch-row"><span class="icon-sample">$chevronIcon Expandir/recolher card</span><code>.expand-btn</code></div>
  <div class="swatch-row"><span class="icon-sample">$backendIcon PR de backend (repo termina em -backend)</span><code>Get-PrKindInfo</code></div>
  <div class="swatch-row"><span class="icon-sample">$frontendIcon PR de frontend (repo mfe-/mobile-)</span><code>Get-PrKindInfo</code></div>
  <div class="swatch-row"><span class="icon-sample">$migrationIcon PR de migration (repo com "migrations" no nome)</span><code>Get-PrKindInfo</code></div>
</section>

<section>
  <h2>Destaque de favorito ("atual")</h2>
  <div class="swatch-row"><span class="badge-current">TRABALHANDO ATUALMENTE</span><code>.badge-current</code></div>
  <div class="mini-card">Borda/glow de card favoritado (.card-current)</div>
</section>
</body>
</html>
"@
}

# Arquivo (_archive/): docs superados/antigos - filtro "Arquivo" da aba
# Completas no dashboard (antes era a pagina archive.html).
function Get-ArchiveData() {
    $archiveDir = Join-Path $root '_archive'
    if (-not (Test-Path $archiveDir)) { return @() }
    return @(Get-ChildItem -Path $archiveDir -Filter '*.md' -File | Sort-Object Name | ForEach-Object {
        $raw = [IO.File]::ReadAllText($_.FullName)
        $parsed = Parse-Frontmatter $raw
        $desc = ''
        if ($parsed -and $parsed.Meta['function']) {
            $desc = Clean-Field $parsed.Meta['function']
            $repo = Clean-Field $parsed.Meta['repo']
            if ($repo) { $desc = "$desc ($repo)" }
        } else {
            $m = [regex]::Match($raw, '(?m)^#\s+(.+)$')
            $desc = if ($m.Success) { $m.Groups[1].Value.Trim() } else { '' }
        }
        [ordered]@{ name = $_.Name; desc = $desc; url = 'file:///' + ($_.FullName -replace '\\', '/') }
    })
}

# Formulario de criacao de task - dump completo (nao pergunta parcial por
# chat): usuario preenche link(s) do Azure, repo e a demanda em texto livre,
# a pagina monta um comando que abre o Claude DIRETO na pasta do repo
# escolhido, com um prompt auto-suficiente (sem skill dedicada - o texto
# ja inclui as instrucoes de busca/confirmacao/historico, e o gate global
# do CLAUDE.md do usuario dispara sozinho, igual qualquer demanda digitada
# nesse repo). Estatica (sem backend) - so compoe o texto, quem processa
# e' o agente depois que a sessao abre. Reaproveita o mesmo mecanismo de
# lancamento do biblioteca-cmd-run: (Get-LaunchUri) + copia pro clipboard como
# fallback, igual todo outro botao de acao.
function Build-NovaTaskHtml() {
    # $reposBasePathJs/$libRootJs vem do escopo do script (calculados antes
    # desta funcao ser chamada, perto do fim do arquivo) - mesmo padrao de
    # closure que as outras Build-*Html usam pra $hubRoot/$faviconLink etc.
    # Nunca citar outra variavel do script num comentario dentro do here-
    # string abaixo: ele interpola, e um nome de variavel em comentario JS
    # despeja o conteudo dela na pagina (ja aconteceu - o JS inteiro do
    # dashboard foi parar dentro do nova-task.html).
    $hubRootJs = $hubRoot.Replace('\', '\\')
    $ntReposBaseJs = if ($reposBasePathJs) { $reposBasePathJs } else { $libRootJs }

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
$faviconLink
<title>Biblioteca - Nova Task</title>
<style>
$sharedCss
  :root {
    --azure-bg: #1f2a33; --azure-text: #7fa8c2; --azure-border: #3d5566;
    --claude-bg: #2e1f16; --claude-border: #a85a35; --claude-bright: #d97757;
  }
  html, body { height: 100%; }
  body {
    background: var(--bg); color: var(--text); max-width: 1400px;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
    margin: 0 auto; padding: 20px 32px 24px; display: flex; flex-direction: column;
  }
  .back { color: var(--text-dim); text-decoration: none; font-size: 0.82rem; flex-shrink: 0; }
  .back:hover { color: var(--gold-bright); }
  h1 { font-size: 1.3rem; margin: 10px 0 4px; color: #fff; flex-shrink: 0; }
  .sub { color: var(--text-faint); font-size: 0.85rem; margin: 0 0 16px; flex-shrink: 0; }
  /* grid-template-rows: minmax(0,1fr) - forca a linha unica a ocupar toda
     a altura restante do container (que ja e' definida, vem do flex:1 do
     body) em vez de depender do "auto" calculado a partir do conteudo -
     "auto" mediu a coluna esquerda mais alta que a direita mesmo crescida,
     deixando vao vazio antes do botao. */
  .nt-grid {
    display: grid; grid-template-columns: 1.1fr 1fr; grid-template-rows: minmax(0, 1fr);
    gap: 20px; align-items: stretch; flex: 1 1 auto; min-height: 0;
  }
  /* height:100% (nao so' o stretch implicito do grid) - sem isso o
     flex-grow dos filhos (a secao do prompt/demanda) nao enxerga uma
     altura definida pra crescer contra, e vira um vao vazio embaixo em
     vez de esticar a caixa. */
  .nt-col-main, .nt-col-side { display: flex; flex-direction: column; min-height: 0; height: 100%; }
  .nt-desc-section { flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; }
  .nt-desc-section textarea { flex: 1 1 auto; min-height: 200px; }
  .nt-prompt-section { flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; }
  .nt-prompt-section textarea { flex: 1 1 auto; min-height: 200px; }
  /* position:fixed, ancorado na borda da janela (nao da caixa) - usa o
     vao vazio a direita do conteudo quando a janela e' mais larga que o
     max-width do body, que e' o espaco livre que sobra do lado. */
  .nt-rail {
    position: fixed; right: 24px; bottom: 24px;
    display: flex; flex-direction: column; align-items: flex-end; gap: 10px;
    max-width: 220px;
  }
  @media (max-width: 980px) {
    html, body { height: auto; }
    body { display: block; }
    .nt-grid { grid-template-columns: 1fr; }
    .nt-col-main, .nt-col-side { height: auto; }
    .nt-rail { position: static; max-width: none; margin-top: 14px; }
  }
  .nt-section {
    background: var(--card-bg); border: 1px solid var(--card-border); border-radius: 10px;
    padding: 14px 16px; margin: 0 0 14px;
  }
  .nt-section h2 {
    font-size: 0.76rem; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--gold-bright); margin: 0 0 10px; display: flex; align-items: center; gap: 6px;
  }
  .nt-azure { border-color: var(--azure-border); }
  .nt-azure h2 { color: var(--azure-text); }
  label { display: block; font-size: 0.8rem; color: var(--text-dim); margin: 12px 0 6px; }
  label:first-of-type { margin-top: 0; }
  label.req::after { content: " *"; color: var(--gold-bright); }
  label.nt-optional { font-size: 0.72rem; color: var(--text-faint); }
  input[type="text"], textarea {
    width: 100%; background: #262931; border: 1px solid var(--card-border);
    color: var(--text); border-radius: 8px; padding: 8px 12px; font-size: 0.88rem;
    font-family: inherit;
  }
  textarea { resize: vertical; }
  input[type="text"]:focus-visible, textarea:focus-visible { border-color: var(--gold); }
  #nt-desc { min-height: 140px; }
  .hint { color: var(--text-faint); font-size: 0.76rem; margin: 6px 0 0; }
  .hint code { font-family: ui-monospace, "SF Mono", monospace; color: var(--gold-bright); }
  .hint a { color: var(--gold-bright); }
  .warn { color: #c98a7a; font-size: 0.8rem; min-height: 1.1em; margin: 10px 0; }
  #nt-prompt { min-height: 150px; font-size: 0.85rem; line-height: 1.4; }
  details { margin-top: 10px; }
  details summary { color: var(--text-dim); font-size: 0.76rem; cursor: pointer; }
  details summary:hover { color: var(--gold-bright); }
  #nt-output {
    margin-top: 8px; min-height: 80px; font-family: ui-monospace, "SF Mono", monospace;
    font-size: 0.74rem; color: var(--text-dim);
  }
  .actions { display: flex; justify-content: flex-end; gap: 10px; margin-top: 18px; flex-wrap: wrap; }
  .claude-btn {
    background: var(--claude-bg); color: var(--claude-bright); border: 1px solid var(--claude-border);
    border-radius: 8px; padding: 10px 20px; font-size: 0.9rem; font-weight: 600; cursor: pointer;
    display: inline-block; text-decoration: none;
  }
  .claude-btn:hover { filter: brightness(1.2); }
</style>
</head>
<body>
<a class="back" href="dashboard.html">&larr; Voltar ao dashboard</a>
<h1>Nova Task</h1>
<p class="sub">Preenche os campos - o prompt se monta sozinho na caixa ao lado, pode ajustar antes de abrir. "Abrir Claude" ja copia e abre direto, sem precisar colar - na pasta do repositorio (ou na pasta geral, se ainda nao souber qual repo).</p>

<div class="nt-grid">
  <div class="nt-col-main">
    <section class="nt-section nt-azure">
      <h2>$linkIcon Origem (Azure DevOps)</h2>
      <label class="nt-optional" for="nt-azure">Link do work item (opcional)</label>
      <input type="text" id="nt-azure" placeholder="https://dev.azure.com/.../_workitems/edit/12345" autocomplete="off">
      <label class="nt-optional" for="nt-parent">Link do item pai (opcional)</label>
      <input type="text" id="nt-parent" placeholder="https://dev.azure.com/.../_workitems/edit/12000" autocomplete="off">
      <p class="hint">Pode deixar em branco - o Claude acha o parent sozinho via MCP do Azure DevOps, se estiver conectado.</p>
    </section>

    <section class="nt-section">
      <h2>Repositorio</h2>
      <label class="nt-optional" for="nt-repo">Repositorio (opcional)</label>
      <input type="text" id="nt-repo" list="nt-repos" placeholder="meu-app-frontend" autocomplete="off">
      <datalist id="nt-repos">
$knownReposOptionsHtml
      </datalist>
      <p class="hint" id="nt-path-hint"></p>
      <p class="hint">Pode deixar em branco - abre na pasta geral de repositorios e o Claude descobre qual usar depois de ler o work item no Azure DevOps.</p>
    </section>

    <section class="nt-section nt-desc-section">
      <h2>Demanda</h2>
      <label class="req" for="nt-desc">O que precisa ser feito</label>
      <textarea id="nt-desc" placeholder="Contexto, aceite, qualquer coisa relevante - sem limite de linhas."></textarea>
    </section>
  </div>

  <div class="nt-col-side">
    <section class="nt-section nt-prompt-section">
      <h2>Prompt (isso vai ser enviado pro Claude)</h2>
      <textarea id="nt-prompt" placeholder="Preencha os campos ao lado - o prompt aparece aqui sozinho."></textarea>
      <details>
        <summary>Comando bruto (powershell)</summary>
        <textarea id="nt-output" readonly placeholder="Aparece depois de clicar em Abrir Claude."></textarea>
      </details>
    </section>
  </div>
</div>

<div class="nt-rail">
  <p class="warn" id="nt-warn"></p>
  <div class="actions">
    <a class="claude-btn" id="nt-launch" href="#">Abrir Claude</a>
  </div>
</div>

<script>
$launchButtonJs
var azureEl = document.getElementById('nt-azure');
var parentEl = document.getElementById('nt-parent');
var repoEl = document.getElementById('nt-repo');
var descEl = document.getElementById('nt-desc');
var promptEl = document.getElementById('nt-prompt');
var pathHint = document.getElementById('nt-path-hint');
var warn = document.getElementById('nt-warn');
var rawOutput = document.getElementById('nt-output');
var launch = document.getElementById('nt-launch');
var reposBase = '$ntReposBaseJs';

// Sem skill dedicada - o prompt e' auto-suficiente: abre direto no repo e
// manda seguir o fluxo de skills do CLAUDE.md do proprio usuario (seja
// qual for). As instrucoes de busca/confirmacao/historico vao dentro do
// proprio texto, nao numa skill separada. Confirmacao do Azure e' objetiva
// (link + sim/nao), nao um paragrafo aberto - e so acontece 1x, depois o
// REQ salvo vira a fonte.
function buildPromptText() {
  var azure = azureEl.value.trim();
  var parent = parentEl.value.trim();
  var repo = repoEl.value.trim();
  var desc = descEl.value.trim();
  if (!azure && !repo && !desc) { return ''; }
  var parts = [];
  parts.push('Nova demanda - Azure: ' + (azure || '(nao informado)') + (parent ? ' (parent: ' + parent + ')' : '') + '.');
  if (repo) {
    parts.push('Repo: ' + repo + '. Se esta pasta nao for exatamente esse repositorio, mova-se (cd) pra pasta correta antes de seguir.');
  } else {
    parts.push('Repo: nao informado - abriu na pasta geral de repositorios (' + reposBase + '). Depois de ler o work item (e o parent) via MCP azure-devops, descubra qual repositorio corresponde e mova-se (cd) pra pasta dele (' + reposBase + '\\<repo>) antes de gravar qualquer doc.');
  }
  parts.push('Descricao: ' + (desc || '(nao informado)'));
  parts.push('Antes de gravar qualquer doc: busque REQ/parent via MCP azure-devops se estiver conectado (ferramenta wit_work_item, `$expand=relations pra achar o parent - nunca wit_work_item_write/wit_work_item_comment_write/wit_work_item_link_write/wit_backlog). Mostre o link do work item (e do parent, se achar) e peca uma confirmacao objetiva (sim/nao) se e esse mesmo - nao descreva tudo em texto solto, so o link + a pergunta.');
  parts.push('So depois da confirmacao, grave o REQ (e o parent, se houver) em reqs/ na Biblioteca ($libRootJs) e siga o fluxo de skills do seu CLAUDE.md pra demanda nova (documentacao pela skill controle-documentacao). A partir dai, use o arquivo salvo como fonte - nao reconsulte o Azure ao vivo de novo pra essa mesma task.');
  parts.push('Ao terminar de gravar os docs (task-code/reqs/resumo), anexe uma entrada em ' + '$hubRootJs' + '\\historico-nova-task.md (cabecalho \'## {data/hora} - task {id|slug} ({repo})\' + bullets Azure/Parent/REQs confirmados/Docs gerados) antes de considerar concluido.');
  return parts.join('\n\n');
}

// "Biblioteca" nao mora em reposBasePath (e' a raiz do proprio repo) -
// mesmo caso especial do seletor "Abrir Claude" do header. Repo em branco
// cai solto na pasta que contem todos os repos.
function getTargetPath(repo) {
  if (repo.toLowerCase() === 'biblioteca') { return '$libRootJs'; }
  return repo ? (reposBase + '\\' + repo) : reposBase;
}

function updatePathHint() {
  var repo = repoEl.value.trim();
  pathHint.textContent = 'Vai abrir em: ' + (repo ? getTargetPath(repo) : (reposBase + ' (pasta geral - repositorio a definir)'));
}

// Sem trava de "edicao manual" - o prompt sempre reflete os campos ao
// lado. Editar a caixa do prompt direto ainda funciona (o comando final
// usa o texto dela), so' que qualquer mudanca nos campos reescreve por
// cima - simples e previsivel.
function regeneratePrompt() {
  promptEl.value = buildPromptText();
}

[azureEl, parentEl, repoEl, descEl].forEach(function (el) {
  el.addEventListener('input', function () {
    regeneratePrompt();
    updatePathHint();
  });
});

launch.addEventListener('click', function (e) {
  var repo = repoEl.value.trim();
  var desc = descEl.value.trim();
  if (!desc) {
    e.preventDefault();
    warn.textContent = 'Preencha ao menos a descricao.';
    return;
  }
  warn.textContent = '';
  var promptOneLine = promptEl.value.trim().replace(/\r\n|\r|\n/g, '\\n').replace(/"/g, "'");
  var escapedPhrase = promptOneLine.replace(/'/g, "''");
  var cmd = 'powershell -NoProfile -Command "cd \'' + getTargetPath(repo) + '\'; claude \'' + escapedPhrase + '\'"';

  rawOutput.value = cmd;
  biblLaunch(launch, cmd);
});
</script>
</body>
</html>
"@
}

# Pagina Time (time.html) - tasks delegadas pra outros devs do time, uma
# coluna por dev. Fonte: docs `type: delegada` em delegadas/ (criados pela
# skill de delegacao - config `delegarSkill`, default delegar-task) + delegadas/devs.json (lista de devs,
# editada pelo botao "+ Dev" via scripts/time-dev.ps1 - nunca a mao pelo
# agente). Feature opt-in: sem a pasta delegadas/ (export publico, clone
# novo) nao gera pagina nem link no header.
# Texto com acento vai como entidade HTML (&aacute;) ou \u00e1 no JS - este
# .ps1 nao tem BOM, acento literal corrompe (ver $crossmark acima).
# ---------------------------------------------------------------------------
$delegadasDir = Join-Path $root 'delegadas'
$timeEnabled = Test-Path $delegadasDir
# Analisar/revisar precisa ler codigo de varios repos - abre o Claude na
# pasta que contem todos (reposBasePath), igual o "Abrir Claude" sem repo.
$timeClaudeDir = if ($bibConfig.reposBasePath) { $bibConfig.reposBasePath } else { $root }
$delegarSkill = $bibConfig.delegarSkill
$teamIcon = '<svg viewBox="0 0 16 16" width="12" height="12" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"><circle cx="6" cy="5.5" r="2.3"/><path d="M1.8 13.5c.5-2.4 2.2-3.7 4.2-3.7s3.7 1.3 4.2 3.7"/><circle cx="11.3" cy="6.2" r="1.8"/><path d="M11.6 9.9c1.5.2 2.4 1.3 2.7 3"/></svg>'

function Get-TimeDevs() {
    $path = Join-Path $delegadasDir 'devs.json'
    if (-not (Test-Path $path)) { return @() }
    try {
        $raw = [IO.File]::ReadAllText($path) | ConvertFrom-Json
    } catch {
        Write-Host 'dashboard: delegadas/devs.json invalido - pagina Time sem devs cadastrados.' -ForegroundColor Yellow
        return @()
    }
    return @($raw.devs | Where-Object { $_ -and $_.id })
}

# Get-DelegadaField / Get-DelegadaReview (parsers do corpo) moram em
# dashboard-lib.ps1 - funcoes puras, cobertas por test-dashboard-lib.ps1.

# PRs da delegada: links no corpo (mesmo Get-Signals do dashboard) + qualquer
# URL que so' esteja nos campos pr_* (sweep/delegadas-prs.ps1).
function Get-DelegadaPrs($d) {
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($pr in (Get-Signals @($d) $d.Task).PRs) { if (-not $list.Contains($pr)) { $list.Add($pr) } }
    foreach ($field in @($d.PrPending, $d.PrMerged, $d.PrRejected)) {
        foreach ($m in [regex]::Matches("$field", $prLinkPattern)) { if (-not $list.Contains($m.Value)) { $list.Add($m.Value) } }
    }
    return @($list)
}

function Test-PrClosed($d, [string]$pr) {
    return ($d.PrMerged -and $d.PrMerged.Contains($pr)) -or ($d.PrRejected -and $d.PrRejected.Contains($pr))
}

# Etapa do card (chip colorido) - deriva so' de status/dev/PRs/review, nada
# gravado a mais no doc.
function Get-DelegadaStage($d, $prs, $review) {
    if ($d.Status -eq 'completed') { return @{ Key = 'done'; Label = 'Conclu&iacute;da' } }
    if (-not $d.Dev) { return @{ Key = 'triagem'; Label = 'Aguardando dev' } }
    if ($prs.Count -eq 0) { return @{ Key = 'dev'; Label = 'Em desenvolvimento' } }
    $open = @($prs | Where-Object { -not (Test-PrClosed $d $_) })
    # Todos os PRs fechados mas status ainda aberto: link entrou so' no corpo
    # (backfill marca pr_merged, mas so' o sweep de pr_pending fecha status)
    # ou algum PR foi fechado sem merge - em ambos, conferir na mao.
    if ($open.Count -eq 0) {
        if (@($prs | Where-Object { $d.PrMerged -and $d.PrMerged.Contains($_) }).Count -gt 0) { return @{ Key = 'done'; Label = 'PR mergeado &middot; conferir conclus&atilde;o' } }
        return @{ Key = 'ajustes'; Label = 'PR fechado sem merge' }
    }
    if (-not $review) { return @{ Key = 'pr'; Label = 'PR aberto &middot; aguardando review' } }
    switch ($review.Verdict) {
        'ajustes' { return @{ Key = 'ajustes'; Label = 'Ajustes solicitados' } }
        'aprovado' { return @{ Key = 'aprovado'; Label = 'Aprovado &middot; aguardando merge' } }
        default { return @{ Key = 'pr'; Label = 'Revisado' } }
    }
}

function Get-DelegadaData($d) {
    $prs = Get-DelegadaPrs $d
    $review = Get-DelegadaReview $d.Body
    $stage = Get-DelegadaStage $d $prs $review
    $taskLabel = if ($d.Task -match '^\d+$') { "Task $($d.Task)" } elseif ($d.Cluster) { $d.Cluster } else { 'Geral' }
    $title = if ($d.TituloBusca) { $d.TituloBusca } elseif ($d.Function) { $d.Function } else { $taskLabel }
    $analysis = New-Object System.Collections.Generic.List[object]
    foreach ($f in @(@{ P = 'Tela'; L = 'Tela' }, @{ P = 'Causa'; L = 'Causa prov&aacute;vel' }, @{ P = 'Aten'; L = 'Aten&ccedil;&atilde;o' })) {
        $v = Get-DelegadaField $d.Body $f.P
        if ($v) { $analysis.Add([ordered]@{ label = $f.L; html = (Format-InlineMd $v) }) }
    }
    $openPrs = @($prs | Where-Object { -not (Test-PrClosed $d $_) })
    $reviewCmd = $null
    if ($openPrs.Count -gt 0) {
        $cmd = Get-ClaudeCmd $timeClaudeDir "Use a skill $delegarSkill no modo revisar para os PRs: $($openPrs -join ' ') (task $($d.Task), delegada em $($d.Path))."
        $reviewCmd = [ordered]@{ cmd = $cmd; uri = (Get-LaunchUri $cmd) }
    }
    $mid = " $([char]0xB7) "
    return [ordered]@{
        id        = $d.Path
        task      = $d.Task
        label     = $taskLabel
        title     = $title
        repos     = @($d.Repo -split '[\s,]+' | Where-Object { $_ })
        azure     = $(if ($azureBase -and $d.Task -match '^\d+$') { "$azureBase/$($d.Task)" } else { '' })
        prs       = @($prs | ForEach-Object { Get-PrData $_ @($d) })
        stage     = [ordered]@{ key = $stage.Key; label = $stage.Label }
        diff      = ((@($d.Dificuldade, $d.Estimativa) | Where-Object { $_ }) -join $mid)
        analysis  = $analysis.ToArray()
        review    = $(if ($review) { [ordered]@{ count = $review.Count; heading = $review.Heading; html = (Format-InlineMd $review.Resumo) } } else { $null })
        doc       = 'file:///' + ($d.Path -replace '\\', '/')
        reqs      = @(@($d.Related | Where-Object { $_ -match '^reqs/' }) | ForEach-Object { "file:///$(($root -replace '\\', '/'))/$_" })
        reviewCmd = $reviewCmd
        updated   = Format-DisplayDate $d.Updated
        done      = $d.Status -eq 'completed'
        search    = ("$taskLabel $title $($d.Repo) $($d.Function)").ToLowerInvariant()
    }
}

function Get-TimeData() {
    $devs = Get-TimeDevs
    $delegadas = @($all | Where-Object { $_.Type -eq 'delegada' -and $_.Status -notin @('superseded', 'archived') } | Sort-Object Updated -Descending)
    # Colunas: devs do devs.json na ordem do arquivo + qualquer `dev:` de doc
    # que nao esta (mais) la - delegada nunca some por dev removido. Cor por
    # dev: campo opcional `cor` no JSON, senao a posicao na paleta.
    $devPalette = @('#b48ee8', '#4fc1b0', '#e8a07c', '#7fb2f0', '#e48aa8', '#a8c46a')
    $ids = New-Object System.Collections.Generic.List[string]
    foreach ($dv in $devs) { $ids.Add("$($dv.id)") }
    foreach ($id in @($delegadas | Where-Object { $_.Dev } | ForEach-Object { $_.Dev } | Select-Object -Unique)) { if (-not $ids.Contains($id)) { $ids.Add($id) } }
    $columns = New-Object System.Collections.Generic.List[object]
    $i = 0
    foreach ($id in $ids) {
        $cfg = $devs | Where-Object { $_.id -eq $id } | Select-Object -First 1
        $nome = if ($cfg) { "$($cfg.nome)" } else { $id }
        $words = @($nome -split '\s+' | Where-Object { $_ })
        $initials = if ($words.Count -ge 2) { "$($words[0][0])$($words[-1][0])" } elseif ($words.Count -eq 1) { "$($words[0][0])" } else { '?' }
        $mine = @($delegadas | Where-Object { $_.Dev -eq $id })
        $columns.Add([ordered]@{
            id       = $id
            nome     = $nome
            github   = $(if ($cfg) { "$($cfg.github)" } else { '' })
            known    = [bool]$cfg
            accent   = $(if ($cfg -and "$($cfg.cor)" -match '^#[0-9A-Fa-f]{6}$') { $cfg.cor } else { $devPalette[$i % $devPalette.Count] })
            initials = $initials.ToUpperInvariant()
            active   = @($mine | Where-Object { $_.Status -ne 'completed' } | ForEach-Object { Get-DelegadaData $_ })
            done     = @($mine | Where-Object { $_.Status -eq 'completed' } | ForEach-Object { Get-DelegadaData $_ })
        })
        $i++
    }
    # Relativo a este script: ..\..\scripts = _ferramenta\scripts (pessoal) ou
    # raiz\scripts (export publico flat).
    $scriptsDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\scripts'))
    $q = $scriptsDir.Replace("'", "''")
    $syncCmd = "powershell -NoProfile -Command `"cd '$q'; powershell -NoProfile -ExecutionPolicy Bypass -File .\delegadas-prs.ps1`""
    return [ordered]@{
        columns     = $columns.ToArray()
        unassigned  = @($delegadas | Where-Object { -not $_.Dev -and $_.Status -ne 'completed' } | ForEach-Object { Get-DelegadaData $_ })
        activeTotal = @($delegadas | Where-Object { $_.Status -ne 'completed' }).Count
        scriptsDir  = $scriptsDir
        syncPrs     = [ordered]@{ cmd = $syncCmd; uri = (Get-LaunchUri $syncCmd) }
        removeDevs  = @($devs | ForEach-Object {
            $rm = "powershell -NoProfile -Command `"cd '$q'; powershell -NoProfile -ExecutionPolicy Bypass -File .\time-dev.ps1 -Remover '$($_.id)'`""
            [ordered]@{ nome = "$($_.nome)"; github = "$($_.github)"; cmd = $rm; uri = (Get-LaunchUri $rm) }
        })
    }
}
$activeCards =@($cards | Where-Object { $_.Active } | Sort-Object Updated -Descending)
$doneCards = @($cards | Where-Object { -not $_.Active } | Sort-Object Updated -Descending)
$pendenciasCount = @($cards | Where-Object { $_.ResumoDoc -and $_.ResumoDoc.Status -in @('draft', 'in_progress') -and -not $_.Active }).Count

# Rodadas de QA por card "dono": por task numerica, a mesma rodada (numero +
# data) feita em 2-3 camadas vira 1 item so' (pedido do usuario, 2026-08-25),
# dono = a primeira camada na ordem backend, frontend, migrations. Task
# `general` fica sempre solo.
$layerOrder = @{ backend = 0; frontend = 1; migrations = 2 }
$qaByRepPath = @{}
function Add-QaRound([string]$repPath, $data) {
    if (-not $qaByRepPath.ContainsKey($repPath)) { $qaByRepPath[$repPath] = New-Object System.Collections.Generic.List[object] }
    $qaByRepPath[$repPath].Add($data)
}
$processedQaTasks = New-Object System.Collections.Generic.HashSet[string]
foreach ($c in $cards) {
    if ($c.Task -notmatch '^\d+$') {
        foreach ($r in (Get-QaRounds $c)) { Add-QaRound $c.RepPath (Get-QaRoundData @([PSCustomObject]@{ Card = $c; Round = $r; LayerLabel = $null })) }
        continue
    }
    if (-not $processedQaTasks.Add($c.Task)) { continue }
    $siblings = Get-TaskSiblings $c
    $roundGroups = @{}
    foreach ($layer in $layerOrder.Keys) {
        $layerCard = @($siblings | Where-Object { (Get-RepoLayer $_.Repo) -eq $layer } | Select-Object -First 1)
        if ($layerCard.Count -eq 0) { continue }
        foreach ($r in (Get-QaRounds $layerCard[0])) {
            $key = "$($r.RoundNum)|$($r.DateLabel)"
            if (-not $roundGroups.ContainsKey($key)) { $roundGroups[$key] = New-Object System.Collections.Generic.List[object] }
            $roundGroups[$key].Add([PSCustomObject]@{ Card = $layerCard[0]; Round = $r; LayerLabel = $script:RepoLayerLabels[$layer]; LayerOrder = $layerOrder[$layer] })
        }
    }
    foreach ($key in $roundGroups.Keys) {
        $entries = @($roundGroups[$key] | Sort-Object LayerOrder)
        Add-QaRound $entries[0].Card.RepPath (Get-QaRoundData $entries)
    }
}

$today = Get-Date -Format 'dd/MM/yyyy HH:mm'

# Lombada de estante (faixa fina no cabecalho): docs por tipo.
$spine = @(
    @{ Type = 'task'; Label = 'Task'; Color = '#e0b45a' }
    @{ Type = 'task-code'; Label = 'Task code'; Color = '#d9b568' }
    @{ Type = 'task-planning'; Label = 'Task planning'; Color = '#7cbfc4' }
    @{ Type = 'testes'; Label = 'Testes'; Color = '#86b894' }
    @{ Type = 'handover-tecnico'; Label = 'Handover tecnico'; Color = '#c184a0' }
    @{ Type = 'rules'; Label = 'Regras'; Color = '#a89484' }
) | ForEach-Object {
    $t = $_.Type
    [ordered]@{ type = $t; label = $_.Label; color = $_.Color; count = @($all | Where-Object { $_.Type -eq $t }).Count }
} | Where-Object { $_.count -gt 0 }

function Get-CardsData($list) {
    return @($list | ForEach-Object {
        $qa = if ($qaByRepPath.ContainsKey($_.RepPath)) { $qaByRepPath[$_.RepPath].ToArray() } else { @() }
        Get-CardData $_ $qa
    })
}

$dashboardData = [ordered]@{
    generatedAt = (Get-Date -Format 'o')
    today       = $today
    stats       = [ordered]@{ active = $activeCards.Count; done = $doneCards.Count; pendencias = $pendenciasCount }
    config      = [ordered]@{
        libRoot       = $root
        reposBasePath = "$($bibConfig.reposBasePath)"
        timeClaudeDir = $timeClaudeDir
        delegarSkill  = $delegarSkill
        hubRoot       = $hubRoot
    }
    pendencias  = @($cards | Where-Object { $_.ResumoDoc -and $_.ResumoDoc.Status -in @('draft', 'in_progress') -and -not $_.Active } | ForEach-Object { $_.RepPath })
    archive     = @(Get-ArchiveData)
    repos       = @($knownRepos | ForEach-Object { [ordered]@{ name = $_; layer = (Get-RepoLayer $_) } })
    spine       = @($spine)
    active      = @(Get-CardsData $activeCards)
    done        = @(Get-CardsData $doneCards)
    time        = $(if ($timeEnabled) { Get-TimeData } else { $null })
}

# PS 5.1: o ETS de System.Array faz ConvertTo-Json gravar array como
# {"value":[...],"Count":n} - remover o tipo antes de serializar.
Remove-TypeData System.Array -ErrorAction SilentlyContinue
$json = $dashboardData | ConvertTo-Json -Depth 14 -Compress
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'data.js'), "window.BIBLIOTECA = $json;`n", (New-Object System.Text.UTF8Encoding $false))

[System.IO.File]::WriteAllText((Join-Path $hubRoot 'paleta.html'), (Build-PaletteHtml))
if ($timeEnabled) {
    # time.html virou secao do dashboard - o arquivo so' redireciona, pra
    # favorito/link antigo nao quebrar.
    [System.IO.File]::WriteAllText((Join-Path $hubRoot 'time.html'), '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=dashboard.html#time"><title>Time</title><a href="dashboard.html#time">Time agora fica no dashboard</a>')
}
# nova-task.html regenerado a cada sync, igual as outras paginas - o
# layout ajustado a mao mora em Build-NovaTaskHtml, e repos/paths vem do
# config (antes so' era criado 1x e congelava o path de quem gerou
# primeiro - foi assim que o template publico saiu com path pessoal).
[System.IO.File]::WriteAllText((Join-Path $hubRoot 'nova-task.html'), (Build-NovaTaskHtml))

# Historico de criacao de tasks (o proprio agente anexa as entradas,
# seguindo a instrucao embutida no prompt de nova-task.html - sem skill
# dedicada) - so' garante que o arquivo existe pra o link "Historico" do
# header nao dar 404 antes da 1a task criada pelo formulario; nunca
# sobrescreve conteudo.
$historicoPath = Join-Path $hubRoot 'historico-nova-task.md'
if (-not (Test-Path $historicoPath)) {
    [System.IO.File]::WriteAllText($historicoPath, "# Historico de criacao de tasks`n`nEntradas anexadas pelo agente (instrucao embutida no prompt de nova-task.html) a cada task criada - append-only, nao editar a mao.`n")
}

Write-Output "dashboard: $($cards.Count) tasks ($($activeCards.Count) ativas, $($doneCards.Count) completas) -> data.js"
