# Gera INDEX.md a partir do frontmatter de todos os documentos
param([array]$ParsedDocs)
. (Join-Path $PSScriptRoot 'lib-doc.ps1')
$root = Get-LibRoot
# -ParsedDocs vem de sync-all.ps1 (parse compartilhado); sem ele, parseia
# por conta propria (rodando este script solo) - ver lint-clusters.ps1.
$parsedDocs = if ($ParsedDocs) { $ParsedDocs } else { Get-ParsedDocs $root }
$rows = @()
# Doc ativo sem toque ha mais que isso aparece marcado "parado" no INDEX -
# status manual diverge; o aviso obriga a decidir (fechar ou retomar).
$staleDays = 14
$todayDate = (Get-Date).Date

foreach ($d in $parsedDocs) {
    $f = $d.File
    $p = $d.Parsed
    # `number:` deixou de ser obrigatorio em 2026-11-17 - basta `type:`.
    if (-not $p -or -not $p.Meta['type']) { continue }
    $rel = $f.FullName.Substring($root.Length + 1) -replace '\\', '/'
    $status = Clean-Field $(if ($p.Meta['status']) { $p.Meta['status'] } else { 'draft' })
    $statusLabel = if ($script:StatusLabels.ContainsKey($status)) { $script:StatusLabels[$status] } else { $status }
    $updated = Clean-Field $p.Meta['updated']
    if ($status -in @('draft', 'in_progress') -and $updated -match '^\d{4}-\d{2}-\d{2}$') {
        $age = ($todayDate - [datetime]::ParseExact($updated, 'yyyy-MM-dd', $null)).Days
        if ($age -gt $staleDays) { $statusLabel = "$statusLabel (parado ha $age dias)" }
    }
    $rows += [PSCustomObject]@{
        Updated = $updated
        Type = $p.Meta['type']
        Status = $status
        Line = "| $(Format-DisplayDate $updated) | [``$rel``]($rel) | $statusLabel | $($p.Meta['repo']) | $($p.Meta['task']) | $($p.Meta['function']) |"
    }
}
$today = Get-Date -Format 'dd/MM/yyyy'

$tableHeader = @(
    '| Atualizado | Arquivo | Status | Repo | Task | Funcao |'
    '|:--|:--|:--|:--|:--|:--|'
)

# INDEX.md fica pequeno de proposito (ativas + cabecalho) - e' o unico arquivo
# que se espera ler por completo; historico cresce pra sempre em CATALOGO.md,
# consultado so por grep/busca pontual (ver controle-documentacao).
$index = @(
    '# Indice - Biblioteca'
    ''
    '> **Gerado automaticamente.** Nao editar. Rode ``_ferramenta/scripts/sync-all.ps1`` apos alterar documentos.'
    ''
    "**Pasta:** ``$root``  "
    "**Atualizado:** $today"
    ''
    '---'
    ''
    '## Como usar'
    ''
    '| Acao | Onde |'
    '|:--|:--|'
    '| Regras | [`01-regras-biblioteca.md`](01-regras-biblioteca.md) |'
    '| Task nova (formato atual) | [`_templates/task.md`](_templates/task.md), salvar em `tasks/` |'
    '| Sincronizar tabelas + indice | ``_ferramenta/scripts/sync-all.ps1`` |'
    '| Historico completo (busca pontual, nao ler por completo) | [`CATALOGO.md`](CATALOGO.md) |'
    ''
    '---'
    ''
)

$active = $rows | Where-Object { $_.Status -in @('draft', 'in_progress') } | Sort-Object Updated -Descending
if ($active.Count -gt 0) {
    $index += '## Em andamento agora'
    $index += ''
    $index += $tableHeader
    foreach ($r in $active) { $index += $r.Line }
    $index += ''
}

$out = Join-Path $root 'INDEX.md'
[System.IO.File]::WriteAllText($out, ($index -join "`r`n"))

$catalogo = @(
    '# Catalogo completo - Biblioteca'
    ''
    '> **Gerado automaticamente.** Nao editar. Historico de tudo, agrupado por'
    '> tipo, mais recente primeiro. So consultar via grep/busca pontual — nao'
    '> ler por completo (cresce pra sempre). Ativas ficam em [`INDEX.md`](INDEX.md).'
    ''
    '---'
    ''
)

$groupOrder = @('task', 'task-code', 'task-planning', 'testes', 'resumo', 'handover-tecnico', 'delegada', 'rules')
foreach ($type in $groupOrder) {
    $group = $rows | Where-Object { $_.Type -eq $type } | Sort-Object Updated -Descending
    if ($group.Count -eq 0) { continue }
    $typeLabel = if ($script:TypeLabels.ContainsKey($type)) { $script:TypeLabels[$type] } else { $type }
    $catalogo += "## $typeLabel"
    $catalogo += ''
    $catalogo += $tableHeader
    foreach ($r in $group) { $catalogo += $r.Line }
    $catalogo += ''
}

$catOut = Join-Path $root 'CATALOGO.md'
[System.IO.File]::WriteAllText($catOut, ($catalogo -join "`r`n"))
Write-Host "build-index: $($rows.Count) entradas"
