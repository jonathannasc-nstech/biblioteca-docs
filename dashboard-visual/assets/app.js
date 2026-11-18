/* Dashboard da Biblioteca — monta a tela a partir de window.BIBLIOTECA
   (data.js, gerado por scripts/build-dashboard.ps1 a cada sync-all).
   Nada de regra de negócio aqui: estado de PR, camadas, comandos e textos
   já chegam calculados. Este arquivo só desenha e trata interação. */
(function () {
  'use strict';

  var B = window.BIBLIOTECA;
  if (!B) {
    document.querySelector('main').innerHTML = '<p class="empty">data.js não encontrado. Rode _ferramenta/scripts/sync-all.ps1.</p>';
    return;
  }

  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function store(key, val) {
    try { if (val === undefined) { return localStorage.getItem(key); } if (val === null) { localStorage.removeItem(key); } else { localStorage.setItem(key, val); } } catch (e) { return null; }
    return null;
  }

  var STAR = '<svg class="star-icon" viewBox="0 0 24 24" width="17" height="17"><path d="M12 2.5l2.9 6.26L22 9.77l-5 4.87L18.18 21.5 12 17.77 5.82 21.5 7 14.64l-5-4.87 7.1-1.01L12 2.5z"/></svg>';
  var BOOK = '<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><path d="M2 4.8c1.6-.9 3.6-1.3 5.5-1.3 1.7 0 3.4.4 4.5 1v14c-1.1-.6-2.8-1-4.5-1-1.9 0-3.9.4-5.5 1.3V4.8z"/><path d="M22 4.8c-1.6-.9-3.6-1.3-5.5-1.3-1.7 0-3.4.4-4.5 1v14c1.1-.6 2.8-1 4.5-1 1.9 0 3.9.4 5.5 1.3V4.8z"/></svg>';
  var CHEV = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6l4 4 4-4"/></svg>';
  var LAYER_STATE = { done: 'feito', pending: 'pendente', na: 'não se aplica' };
  var PR_STATE = { merged: 'mergeado', open: 'aberto', rejected: 'fechado sem merge', unknown: 'estado desconhecido' };

  var ui = {
    q: '', repo: '',
    sort: { key: 'updated', dir: -1 },
    page: 1,
    pageSize: parseInt(store('bibPageSize'), 10) || 25,
    drawerId: null,
    doneView: 'done',
    expanded: {},
    doneOpen: {}
  };

  /* ---------- formatação ---------- */
  function fmtDate(iso, time) {
    if (!iso) { return ''; }
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
    var d = m ? m[3] + '/' + m[2] + '/' + m[1] : iso;
    return time ? d + ' ' + time : d;
  }
  // tira o prefixo de org antes de app-/mfe-/mobile- ("org-app-x-backend" -> "x-backend")
  function shortRepo(r) { return String(r || '').replace(/^[^-]+-(?=(app|mfe|mobile)-)/, '').replace(/^app-/, ''); }
  function reposHtml(repos) {
    repos = repos || [];
    if (!repos.length) { return ''; }
    var txt = repos[0] + (repos.length > 1 ? ' +' + (repos.length - 1) : '');
    return '<span class="repos" title="' + esc(repos.join('\n')) + '">' + esc(txt) + '</span>';
  }
  function idHtml(c) {
    if (c.azure) { return '<a class="id-link" href="' + esc(c.azure) + '" target="_blank" title="Abrir no Azure DevOps">AZ ' + esc(c.task) + '</a>'; }
    return '<span>' + esc(c.label) + '</span>';
  }
  function prPill(p) {
    return '<a class="pill pill-' + esc(p.state) + '" href="' + esc(p.url) + '" target="_blank" title="' + esc(p.repo + '#' + p.num + ' — ' + PR_STATE[p.state]) + '">' + esc(shortRepo(p.repo) + '#' + p.num) + '</a>';
  }
  function prCounts(prs) {
    var n = { merged: 0, open: 0, rejected: 0, unknown: 0 };
    (prs || []).forEach(function (p) { n[p.state] = (n[p.state] || 0) + 1; });
    return n;
  }
  // Resumo de PRs numa pílula só ("6 PRs · 2 abertos"); a lista fica no painel.
  function prSummary(prs, asButton, id) {
    prs = prs || [];
    if (!prs.length) { return ''; }
    var n = prCounts(prs);
    var cls = n.open ? 'pill-open' : (n.rejected && !n.merged ? 'pill-rejected' : (n.merged === prs.length ? 'pill-merged' : ''));
    var parts = [prs.length + (prs.length === 1 ? ' PR' : ' PRs')];
    if (n.open) { parts.push(n.open + (n.open === 1 ? ' aberto' : ' abertos')); }
    else if (n.merged === prs.length) { parts.push(prs.length === 1 ? 'mergeado' : 'mergeados'); }
    if (n.rejected) { parts.push(n.rejected + ' fechado' + (n.rejected === 1 ? '' : 's')); }
    var label = parts.join(' · ');
    var title = prs.map(function (p) { return p.repo + '#' + p.num + ' — ' + PR_STATE[p.state]; }).join('\n');
    if (asButton) { return '<button type="button" class="pill ' + cls + '" data-summary="' + esc(id) + '" title="' + esc(title) + '">' + esc(label) + '</button>'; }
    return '<span class="pill ' + cls + '" title="' + esc(title) + '">' + esc(label) + '</span>';
  }
  function layersHtml(layers) {
    if (!layers || !layers.length) { return ''; }
    return '<span class="layers">' + layers.map(function (l) {
      return '<span class="layer ' + esc(l.state) + '" title="' + esc(l.label + ': ' + LAYER_STATE[l.state]) + '"><i></i>' + esc(l.short) + '</span>';
    }).join('') + '</span>';
  }
  function cmdBtn(c) {
    return '<a class="btn' + (c.kind === 'qa' ? ' btn-ghost' : '') + '" href="' + esc(c.uri) + '" data-cmd="' + esc(c.cmd) + '">' + esc(c.label) + '</a>';
  }
  function cardPrs(c) { return (c.prs && c.prs.length) ? c.prs : (c.summary ? c.summary.prs : []); }

  /* ---------- filtro ---------- */
  function matches(item, extra) {
    var blob = (item.search || '') + ' ' + (extra || '');
    if (ui.q && blob.indexOf(ui.q) === -1) { return false; }
    if (ui.repo && (item.repos || []).join(' ').toLowerCase().indexOf(ui.repo) === -1 && blob.indexOf(ui.repo) === -1) { return false; }
    return true;
  }
  function cardMatches(c) { return matches(c, (c.qa || []).map(function (q) { return q.search; }).join(' ')); }

  /* ---------- Ativas ---------- */
  // Faixa lateral: camada pendente = laranja; tudo feito = verde; sem camada = nada.
  function cardState(c) {
    var l = c.layers || [];
    if (l.some(function (x) { return x.state === 'pending'; })) { return ' state-pending'; }
    if (l.some(function (x) { return x.state === 'done'; })) { return ' state-done'; }
    return '';
  }
  function cardHtml(c, current) {
    return '<article class="card' + cardState(c) + (current ? ' card-current' : '') + '" data-id="' + esc(c.id) + '">' +
      (current ? '<span class="badge-current">Trabalhando agora</span>' : '') +
      '<div class="card-head"><button type="button" class="card-title" data-summary="' + esc(c.id) + '" title="' + esc(c.title) + '">' + esc(c.title) + '</button>' +
      '<button type="button" class="icon-btn star-btn" aria-pressed="' + (current ? 'true' : 'false') + '" title="' + (current ? 'Remover destaque' : 'Marcar como a task atual') + '" aria-label="Destacar task">' + STAR + '</button></div>' +
      '<div class="card-meta">' + idHtml(c) + reposHtml(c.repos) + '</div>' +
      (c.func ? '<p class="func" title="' + esc(c.func) + '">' + esc(c.func) + '</p>' : '') +
      '<div class="card-row">' + prSummary(cardPrs(c), true, c.id) + layersHtml(c.layers) + '</div>' +
      '<div class="card-foot"><span class="updated">' + esc(fmtDate(c.updated, c.time)) + '</span><div class="btns">' + (c.commands || []).map(cmdBtn).join('') + '</div></div>' +
      '</article>';
  }
  function qaBoxes(q) {
    return (q.boxes || []).map(function (b) {
      return '<div class="qa-box">' + (b.label ? '<div class="qa-box-label">' + esc(b.label) + '</div>' : '') + '<div class="qa-text">' + b.html + '</div></div>';
    }).join('');
  }
  function qaHtml(q, parentId) {
    var open = ui.expanded[q.id];
    return '<article class="card qa-card' + (open ? ' expanded' : '') + '" data-id="' + esc(q.id) + '">' +
      '<div class="card-head"><button type="button" class="card-title" data-summary="' + esc(parentId) + '">' + esc(q.title) + '</button></div>' +
      '<div class="card-meta"><span class="qa-label">' + esc(q.label) + '</span><span class="updated">' + esc(fmtDate(q.date)) + '</span></div>' +
      qaBoxes(q) +
      '<button type="button" class="link-btn" data-toggle-expand>' + (open ? 'Mostrar menos' : 'Mostrar tudo') + '</button>' +
      ((q.prs && q.prs.length) ? '<div class="pills">' + q.prs.map(prPill).join('') + '</div>' : '') +
      '<div class="card-foot"><span></span><div class="btns">' + (q.commands || []).map(cmdBtn).join('') + '</div></div>' +
      '</article>';
  }
  // O build gera um card por task+repo. Na tela, a mesma task numérica vira
  // um card/linha só: repos, PRs e QA unidos; com mais de um repo, os botões
  // ganham a camada no rótulo ("Retomar task · back"). Abre o card com resumo.
  function layerShort(repo) {
    if (/-backend$/.test(repo)) { return 'back'; }
    if (/migrations/.test(repo)) { return 'migr'; }
    if (/(^|-)(mfe|mobile)-/.test(repo)) { return 'front'; }
    return shortRepo(repo);
  }
  function mergeByTask(cards) {
    var byTask = {}, out = [];
    var pend = {};
    (B.pendencias || []).forEach(function (id) { pend[id] = true; });
    cards.forEach(function (c) {
      if (!c.isNum) { out.push(Object.assign({}, c, { pend: !!pend[c.id], parts: [c] })); return; }
      var m = byTask[c.task];
      if (!m) {
        m = byTask[c.task] = Object.assign({}, c, { repos: c.repos.slice(), prs: cardPrs(c).slice(), qa: (c.qa || []).slice(), pend: !!pend[c.id], parts: [c] });
        out.push(m); return;
      }
      m.parts.push(c);
      c.repos.forEach(function (r) { if (m.repos.indexOf(r) === -1) { m.repos.push(r); } });
      cardPrs(c).forEach(function (p) { if (!m.prs.some(function (x) { return x.url === p.url; })) { m.prs.push(p); } });
      m.qa = m.qa.concat(c.qa || []);
      m.search += ' ' + c.search;
      m.pend = m.pend || !!pend[c.id];
      if (!m.summary && c.summary) { m.id = c.id; m.summary = c.summary; m.title = c.title; m.func = c.func; }
      if (((c.updated || '') + (c.time || '')) > ((m.updated || '') + (m.time || ''))) { m.updated = c.updated; m.time = c.time; }
    });
    out.forEach(function (m) {
      if (m.parts.length < 2) { return; }
      var seen = {};
      m.commands = [];
      m.parts.forEach(function (p) {
        (p.commands || []).forEach(function (cmd) {
          if (seen[cmd.cmd]) { return; }
          seen[cmd.cmd] = true;
          m.commands.push(Object.assign({}, cmd, { label: cmd.label + ' · ' + layerShort(p.repos[0] || '') }));
        });
      });
      m.commands.sort(function (a, b) { return (a.kind === 'qa') - (b.kind === 'qa'); });
    });
    return out;
  }
  var VIEW = { active: [], done: [] };
  function rebuildViews() { VIEW.active = mergeByTask(B.active); VIEW.done = mergeByTask(B.done); }

  function renderActive() {
    var cur = store('taskHubCurrent');
    var list = VIEW.active.filter(cardMatches);
    if (cur && !VIEW.active.some(function (c) { return c.id === cur; })) { store('taskHubCurrent', null); cur = null; }
    list.sort(function (a, b) { return (b.id === cur) - (a.id === cur); });
    $('#grid-active').innerHTML = list.length ? list.map(function (c) {
      return cardHtml(c, c.id === cur) + (c.qa || []).map(function (q) { return qaHtml(q, c.id); }).join('');
    }).join('') : '<p class="empty">' + (ui.q || ui.repo ? 'Nenhuma task ativa bate com a busca.' : 'Nenhuma task ativa.') + '</p>';
    return list.length;
  }

  /* ---------- Completas: Completas / Pendências / Arquivo ---------- */
  function sortValue(c, key) {
    if (key === 'updated') { return (c.updated || '') + ' ' + (c.time || ''); }
    if (key === 'task') { return c.isNum ? ('0000000000' + c.task).slice(-10) : 'z' + c.label.toLowerCase(); }
    return (c.title || '').toLowerCase();
  }
  function archiveMatches(a) {
    var blob = (a.name + ' ' + a.desc).toLowerCase();
    return (!ui.q || blob.indexOf(ui.q) !== -1) && (!ui.repo || blob.indexOf(ui.repo) !== -1);
  }
  function viewLists() {
    return {
      done: VIEW.done.filter(cardMatches),
      pend: VIEW.done.filter(function (c) { return c.pend && cardMatches(c); }),
      archive: (B.archive || []).filter(archiveMatches)
    };
  }
  var HEAD = {
    done: '<tr><th><button type="button" data-sort="updated">Atualizado <span class="sort"></span></button></th><th><button type="button" data-sort="task">Card <span class="sort"></span></button></th><th><button type="button" data-sort="title">Título <span class="sort"></span></button></th><th><span class="th">Repositórios</span></th><th><span class="th">PRs</span></th></tr>',
    archive: '<tr><th><span class="th">Arquivo</span></th><th><span class="th">Descrição</span></th><th><span class="th"></span></th></tr>'
  };
  HEAD.pend = HEAD.done.replace('<tr>', '<tr><th class="col-check"><span class="th"><input type="checkbox" id="pend-all" aria-label="Selecionar todas"></span></th>');
  var pendChecked = {};
  function doneRow(c, withCheck) {
    var qa = (c.qa || []).length ? ' <span class="pill" title="Rodadas de QA">QA ×' + c.qa.length + '</span>' : '';
    return '<tr data-summary="' + esc(c.id) + '" tabindex="0">' +
      (withCheck ? '<td class="col-check"><input type="checkbox" class="pend-check" data-id="' + esc(c.id) + '"' + (pendChecked[c.id] ? ' checked' : '') + ' aria-label="Selecionar"></td>' : '') +
      '<td class="col-date">' + esc(fmtDate(c.updated)) + '</td>' +
      '<td class="col-id">' + idHtml(c) + '</td>' +
      '<td class="col-title"><strong>' + esc(c.title) + '</strong>' + (c.func && c.func !== c.title ? '<small title="' + esc(c.func) + '">' + esc(c.func) + '</small>' : '') + '</td>' +
      '<td class="col-repos">' + reposHtml(c.repos) + '</td>' +
      '<td class="col-prs">' + prSummary(cardPrs(c), false) + qa + '</td></tr>';
  }
  function archiveRow(a) {
    return '<tr><td class="col-title"><strong>' + esc(a.name) + '</strong></td><td class="col-title"><small title="' + esc(a.desc) + '">' + esc(a.desc) + '</small></td>' +
      '<td class="col-prs"><a class="btn btn-ghost" href="' + esc(a.url) + '" target="_blank">Abrir</a></td></tr>';
  }
  function updatePendBar() {
    var n = Object.keys(pendChecked).filter(function (k) { return pendChecked[k]; }).length;
    var b = $('#pend-launch');
    b.classList.toggle('is-disabled', !n);
    b.setAttribute('aria-disabled', n ? 'false' : 'true');
    b.textContent = n ? 'Pedir conferência ao Claude (' + n + ')' : 'Pedir conferência ao Claude';
  }
  function renderDone() {
    var lists = viewLists();
    ['done', 'pend', 'archive'].forEach(function (v) { $('#n-view-' + v).textContent = lists[v].length; });
    $$('.seg [data-view]').forEach(function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-view') === ui.doneView ? 'true' : 'false'); });
    $('#pend-actions').hidden = ui.doneView !== 'pend';
    var view = ui.doneView, list = lists[view];
    var k = ui.sort.key, dir = ui.sort.dir;
    if (view !== 'archive') { list.sort(function (a, b) { var x = sortValue(a, k), y = sortValue(b, k); return x < y ? -dir : x > y ? dir : 0; }); }
    var pages = Math.max(1, Math.ceil(list.length / ui.pageSize));
    ui.page = Math.min(Math.max(1, ui.page), pages);
    var slice = list.slice((ui.page - 1) * ui.pageSize, ui.page * ui.pageSize);
    $('#done-head').innerHTML = HEAD[view];
    var cols = view === 'archive' ? 3 : (view === 'pend' ? 6 : 5);
    var empty = { done: 'Nada encontrado.', pend: 'Nenhuma pendência: os resumos estão em dia.', archive: 'Nada em _archive/.' }[view];
    $('#done-rows').innerHTML = slice.length ? slice.map(function (x) { return view === 'archive' ? archiveRow(x) : doneRow(x, view === 'pend'); }).join('') :
      '<tr><td colspan="' + cols + '" class="empty">' + empty + '</td></tr>';
    $('#page-info').textContent = list.length + (list.length === 1 ? ' item encontrado' : ' itens encontrados') + ' · página ' + ui.page + ' de ' + pages;
    $('#page-num').value = ui.page;
    $('#page-num').max = pages;
    $('#page-size').value = String(ui.pageSize);
    $('#page-prev').disabled = ui.page <= 1;
    $('#page-next').disabled = ui.page >= pages;
    $$('.list th button').forEach(function (b) {
      var on = b.getAttribute('data-sort') === k;
      b.querySelector('.sort').textContent = on ? (dir < 0 ? '▼' : '▲') : '';
      b.parentNode.setAttribute('aria-sort', on ? (dir < 0 ? 'descending' : 'ascending') : 'none');
    });
    updatePendBar();
    return lists.done.length;
  }

  /* ---------- Time ---------- */
  function delegHtml(d) {
    var open = ui.expanded[d.id];
    var more = (d.analysis || []).map(function (a) {
      return '<div class="an-row"><span class="an-label">' + a.label + '</span><span class="an-text">' + a.html + '</span></div>';
    }).join('');
    if (d.review) {
      more += '<div class="an-row"><span class="an-label">Review (' + d.review.count + (d.review.count > 1 ? ' rodadas' : ' rodada') + ')</span><span class="an-text">' + esc(d.review.heading) + (d.review.html ? '<br>' + d.review.html : '') + '</span></div>';
    }
    var links = '<a class="chip" href="' + esc(d.doc) + '" target="_blank">Delegada</a>' + (d.reqs || []).map(function (r) { return '<a class="chip chip-task-planning" href="' + esc(r) + '" target="_blank">REQ</a>'; }).join('');
    return '<article class="card' + (open ? ' expanded' : '') + '" data-id="' + esc(d.id) + '">' +
      '<div class="card-head"><span class="card-title" title="' + esc(d.title) + '">' + esc(d.title) + '</span><a class="icon-btn" href="' + esc(d.doc) + '" target="_blank" title="Abrir doc da delegada">' + BOOK + '</a></div>' +
      '<div class="card-meta">' + idHtml(d) + reposHtml(d.repos) + '</div>' +
      ((d.prs && d.prs.length) ? '<div class="pills">' + d.prs.map(prPill).join('') + '</div>' : '') +
      '<div class="card-row"><span class="stage stage-' + esc(d.stage.key) + '">' + d.stage.label + '</span>' + (d.diff ? '<span class="diff-chip" title="Dificuldade estimada na análise">' + esc(d.diff) + '</span>' : '') + '</div>' +
      '<div class="deleg-more">' + more + '<div class="pills">' + links + '</div></div>' +
      '<div class="card-foot"><span class="updated">' + esc(d.updated) + '</span><div class="btns">' +
      (d.reviewCmd ? '<a class="btn" href="' + esc(d.reviewCmd.uri) + '" data-cmd="' + esc(d.reviewCmd.cmd) + '">Revisar PR</a>' : '') +
      '<button type="button" class="expand-btn" title="Detalhes" aria-label="Detalhes">' + CHEV + '</button></div></div>' +
      '</article>';
  }
  function devColHtml(col, triagem) {
    var active = col.active.filter(function (d) { return matches(d); });
    var done = col.done.filter(function (d) { return matches(d); });
    var gh = col.github ? '<a class="dev-gh" href="https://github.com/' + esc(col.github) + '" target="_blank">@' + esc(col.github) + '</a>' : (triagem ? '<span class="dev-gh">analisadas, aguardando atribuição</span>' : (col.known ? '' : '<span class="dev-gh">fora do devs.json</span>'));
    return '<section class="dev-col' + (triagem ? ' triagem' : '') + '"' + (col.accent ? ' style="--dev-accent:' + esc(col.accent) + '"' : '') + ' data-dev="' + esc(col.id) + '">' +
      '<header class="dev-head"><span class="avatar">' + esc(col.initials) + '</span><div class="dev-id"><div class="dev-name">' + esc(col.nome) + '</div>' + gh + '</div><span class="dev-count" title="Tasks ativas">' + active.length + '</span></header>' +
      '<div class="dev-cards">' + (active.length ? active.map(delegHtml).join('') : '<p class="empty">Nenhuma task ativa.</p>') + '</div>' +
      (done.length ? '<details class="dev-done"' + (ui.doneOpen[col.id] ? ' open' : '') + ' data-dev="' + esc(col.id) + '"><summary>Concluídas (' + done.length + ')</summary><div class="dev-cards">' + done.map(delegHtml).join('') + '</div></details>' : '') +
      '</section>';
  }
  function renderTime() {
    var T = B.time;
    if (!T) { return 0; }
    var cols = T.columns.slice();
    var html = '';
    if (T.unassigned && T.unassigned.length) {
      html += devColHtml({ id: '_triagem', nome: 'Sem dev', initials: '?', active: T.unassigned, done: [], known: true }, true);
    }
    html += cols.map(function (c) { return devColHtml(c, false); }).join('');
    $('#team-board').innerHTML = cols.length || (T.unassigned || []).length ? '<div class="team-board">' + html + '</div>' :
      '<p class="empty">Nenhum dev cadastrado. Use Time ▸ Gerenciar devs.</p>';
    $('#time-meta').textContent = cols.length + (cols.length === 1 ? ' dev' : ' devs') + ' · ' + T.activeTotal + (T.activeTotal === 1 ? ' delegada ativa' : ' delegadas ativas') + ' · ações no menu Time, acima à direita';
    var n = 0;
    cols.concat([{ active: T.unassigned || [] }]).forEach(function (c) { n += c.active.filter(function (d) { return matches(d); }).length; });
    return n;
  }

  /* ---------- painel lateral (resumo) ---------- */
  function findCard(id) {
    var all = VIEW.active.concat(VIEW.done);
    for (var i = 0; i < all.length; i++) { if (all[i].id === id) { return all[i]; } }
    return null;
  }
  function sec(title, html) { return '<section class="sec"><h3>' + title + '</h3>' + html + '</section>'; }
  var lastFocus = null;
  function renderDrawer() {
    var c = findCard(ui.drawerId);
    if (!c) { closeDrawer(); return; }
    $('#drawer-title').textContent = c.title;
    $('#drawer-meta').innerHTML = idHtml(c) + '<span class="repos" title="' + esc(c.repos.join('\n')) + '">' + esc(c.repos.join(' · ')) + '</span><span class="updated">' + esc(fmtDate(c.updated, c.time)) + '</span>';
    var s = c.summary;
    var actions = (c.commands || []).map(cmdBtn).join('');
    if (s) {
      actions += '<button type="button" class="btn btn-ghost" data-copy="' + esc(s.teams) + '" title="Título, status e o que falta, em texto puro, só com o id do card">Copiar texto pro Teams</button>';
    }
    var body = '<div class="drawer-actions">' + actions + '</div>';
    if (c.layers && c.layers.length) { body += sec('Camadas', layersHtml(c.layers)); }
    if (s) {
      body += sec('Status atual', s.status) + sec('O que falta', s.falta) + sec('O que foi implementado', s.implementado) + sec('REQs seguidas', s.reqs);
    } else if (c.func) {
      body += sec('Descrição', '<p>' + esc(c.func) + '</p><p class="empty">Sem resumo para esta task.</p>');
    }
    var prs = s && s.prs && s.prs.length ? s.prs : (c.prs || []);
    if (prs.length) { body += sec('Pull requests', '<div class="pills">' + prs.map(prPill).join('') + '</div>'); }
    if (c.qa && c.qa.length) {
      body += sec('Rodadas de QA', c.qa.map(function (q) {
        return '<p><strong>' + esc(q.label) + '</strong> · ' + esc(fmtDate(q.date)) + '</p>' + qaBoxes(q).replace(/class="qa-text"/g, 'class=""');
      }).join(''));
    }
    var docs = (c.docs || []).map(function (d) {
      return '<a class="chip chip-' + esc(d.type) + '" href="' + esc(d.url) + '" target="_blank" title="' + esc(d.statusLabel) + '">' + esc(d.label) + ' · ' + esc(d.statusLabel) + '</a>';
    });
    ((s && s.related) || []).forEach(function (r) { docs.push('<a class="chip" href="' + esc(r.url) + '" target="_blank">' + esc(r.label) + '</a>'); });
    if (docs.length) { body += sec('Documentos', '<div class="pills">' + docs.join('') + '</div>'); }
    $('#drawer-body').innerHTML = body;
  }
  function openDrawer(id, opener) {
    ui.drawerId = id;
    lastFocus = opener || document.activeElement;
    renderDrawer();
    $('#drawer').hidden = false;
    document.body.style.overflow = 'hidden';
    $('.drawer-close').focus();
  }
  function closeDrawer() {
    ui.drawerId = null;
    $('#drawer').hidden = true;
    document.body.style.overflow = '';
    if (lastFocus && document.contains(lastFocus)) { lastFocus.focus(); }
  }

  /* ---------- cabeçalho ---------- */
  function renderHeader() {
    $('#brand-meta').innerHTML = '<span class="dot"></span>' + VIEW.active.length + ' ativas<span class="sep">·</span>' + VIEW.done.length + ' completas<span class="sep">·</span>atualizado ' + esc(B.today);
    var total = (B.spine || []).reduce(function (a, s) { return a + s.count; }, 0);
    $('#spine').innerHTML = (B.spine || []).map(function (s) {
      return '<span class="spine-seg" data-type="' + esc(s.type) + '" style="width:' + (s.count / total * 100).toFixed(2) + '%;background:' + esc(s.color) + '"></span>';
    }).join('') + '<div class="spine-legend">' + (B.spine || []).map(function (s) {
      return '<div class="legend-row" data-type="' + esc(s.type) + '"><i style="background:' + esc(s.color) + '"></i>' + esc(s.label) + ': ' + s.count + '</div>';
    }).join('') + '</div>';
    var hasTime = !!B.time;
    $$('.time-only, #tab-time').forEach(function (el) { el.hidden = !hasTime; });
    if (hasTime) {
      var n = B.time.activeTotal;
      $('#time-count').hidden = !n; $('#time-count').textContent = n;
      $('#time-count-menu').textContent = n + (n === 1 ? ' ativa' : ' ativas');
      var sp = $('#sync-prs');
      sp.href = B.time.syncPrs.uri; sp.setAttribute('data-cmd', B.time.syncPrs.cmd);
      $('#dev-remove').innerHTML = (B.time.removeDevs || []).length ? '<h3>Remover</h3><p class="hint">Só remove quem não tem task ativa (o script recusa e explica no terminal).</p>' +
        B.time.removeDevs.map(function (d) { return '<div class="rm-row"><span>' + esc(d.nome) + ' <span class="dev-gh">@' + esc(d.github) + '</span></span><a class="btn btn-ghost" href="' + esc(d.uri) + '" data-cmd="' + esc(d.cmd) + '">Remover</a></div>'; }).join('') : '';
    }
    $('#quick-open-btn').hidden = !B.config.reposBasePath;
    $('.quick-repo-wrap').hidden = !B.config.reposBasePath;
    renderRepoOptions();
  }

  // Repositórios fixados (até 5, no navegador): grupo "Fixados" no topo da lista.
  var FAV_MAX = 5;
  function favRepos() {
    var names = (B.repos || []).map(function (r) { return r.name; });
    try { return (JSON.parse(store('bibFavRepos') || '[]') || []).filter(function (n) { return names.indexOf(n) !== -1; }); } catch (e) { return []; }
  }
  var PIN = '<svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"><path d="M6 1.8h4l-.6 4.1 2.6 2.4v1.2H4V8.3l2.6-2.4z"/><path d="M8 9.5v4.7"/></svg>';
  function renderRepoOptions() {
    var fav = favRepos(), byName = {};
    (B.repos || []).forEach(function (r) { byName[r.name] = r; });
    function opt(r, isFav) {
      return '<div role="option" class="repo-opt' + (isFav ? ' fav' : '') + '" data-v="' + esc(r.name) + '"><span class="repo-name" title="' + esc(r.name) + '">' + esc(r.name) + '</span>' +
        '<span class="layer-tag ' + esc(r.layer || 'geral') + '">' + ({ backend: 'Backend', frontend: 'Frontend', migrations: 'Migrations' }[r.layer] || 'Geral') + '</span>' +
        '<button type="button" class="pin-btn" data-pin="' + esc(r.name) + '" tabindex="-1" aria-pressed="' + isFav + '" title="' + (isFav ? 'Desafixar' : 'Fixar no topo (até ' + FAV_MAX + ')') + ' — teclado: Ctrl+Enter" aria-label="' + (isFav ? 'Desafixar ' : 'Fixar ') + esc(r.name) + '">' + PIN + '</button></div>';
    }
    $('#repo-pop').innerHTML =
      (fav.length ? '<div class="repo-group fav-group">Fixados</div>' + fav.map(function (n) { return opt(byName[n], true); }).join('') + '<div class="menu-sep fav-group"></div>' : '') +
      (B.repos || []).filter(function (r) { return fav.indexOf(r.name) === -1; }).map(function (r) { return opt(r, false); }).join('') +
      '<p class="repo-empty" hidden>Nenhum repositório com esse nome.</p>';
  }
  function togglePin(name) {
    var fav = favRepos(), i = fav.indexOf(name);
    if (i !== -1) { fav.splice(i, 1); }
    else if (fav.length >= FAV_MAX) { toast('Máximo de ' + FAV_MAX + ' repositórios fixados. Desafixe um antes.'); return false; }
    else { fav.push(name); }
    store('bibFavRepos', JSON.stringify(fav));
    renderRepoOptions();
    return true;
  }

  function renderLists() {
    var a = renderActive(), t = renderTime(), d = renderDone();
    $('#n-ativas').textContent = a;
    $('#n-time').textContent = t;
    $('#n-completas').textContent = d;
    if (ui.drawerId) { renderDrawer(); }
  }
  // data.js vem do PowerShell 5.1: lista com 0 ou 1 item pode chegar como
  // null ou objeto solto - normaliza antes de desenhar.
  function normalize() {
    ['active', 'done', 'archive', 'pendencias', 'repos', 'spine'].forEach(function (k) {
      if (!Array.isArray(B[k])) { B[k] = B[k] ? [B[k]] : []; }
    });
  }
  function renderAll() { normalize(); rebuildViews(); renderHeader(); renderLists(); }

  /* ---------- abas (hash) ---------- */
  function showTab(name) {
    if (!$('.tab-panel[data-panel="' + name + '"]') || (name === 'time' && !B.time)) { name = 'ativas'; }
    $$('.tab-panel').forEach(function (p) { p.hidden = p.getAttribute('data-panel') !== name; });
    $$('.tab[data-tab]').forEach(function (t) { t.setAttribute('aria-selected', t.getAttribute('data-tab') === name ? 'true' : 'false'); });
  }
  window.addEventListener('hashchange', function () { showTab(location.hash.slice(1)); window.scrollTo(0, 0); });

  /* ---------- clipboard e comandos ---------- */
  function toast(msg) {
    var t = document.createElement('div');
    t.className = 'toast'; t.setAttribute('role', 'status'); t.textContent = msg;
    document.body.appendChild(t);
    setTimeout(function () { t.remove(); }, 1600);
  }
  function copy(text, done) {
    function fallback() {
      var ta = document.createElement('textarea'); ta.value = text; document.body.appendChild(ta); ta.select();
      try { document.execCommand('copy'); } catch (e) { /* sem clipboard */ }
      ta.remove(); if (done) { done(); }
    }
    if (navigator.clipboard && navigator.clipboard.writeText) { navigator.clipboard.writeText(text).then(done, fallback); } else { fallback(); }
  }
  // biblioteca-cmd-run: abre um cmd e roda o comando (launch-command.vbs);
  // o clipboard é o fallback para máquina sem o protocolo registrado.
  function launch(el, cmd) {
    el.setAttribute('href', 'biblioteca-cmd-run:' + encodeURIComponent(cmd));
    copy(cmd);
    var o = el.textContent; el.textContent = 'Abrindo...';
    setTimeout(function () { el.textContent = o; }, 1500);
  }
  function claudeCmd(dir, prompt) {
    var one = prompt.replace(/\r\n|\r|\n/g, '\\n').replace(/"/g, "'").replace(/'/g, "''");
    return 'powershell -NoProfile -Command "cd \'' + dir + '\'; claude \'' + one + '\'"';
  }

  /* ---------- eventos ---------- */
  document.addEventListener('click', function (e) {
    var t = e.target;
    var el;
    if ((el = t.closest('[data-cmd]'))) { launch(el, el.getAttribute('data-cmd')); return; }
    if ((el = t.closest('[data-copy]'))) { copy(el.getAttribute('data-copy'), function () { toast('Texto copiado'); }); return; }
    if ((el = t.closest('[data-close-drawer]'))) { closeDrawer(); return; }
    if ((el = t.closest('.star-btn'))) {
      var id = el.closest('.card').getAttribute('data-id');
      store('taskHubCurrent', store('taskHubCurrent') === id ? null : id);
      renderActive();
      return;
    }
    if ((el = t.closest('.expand-btn, [data-toggle-expand]'))) {
      var card = el.closest('.card'), cid = card.getAttribute('data-id');
      ui.expanded[cid] = !ui.expanded[cid];
      card.classList.toggle('expanded', ui.expanded[cid]);
      if (el.hasAttribute('data-toggle-expand')) { el.textContent = ui.expanded[cid] ? 'Mostrar menos' : 'Mostrar tudo'; }
      return;
    }
    if ((el = t.closest('.seg [data-view]'))) { ui.doneView = el.getAttribute('data-view'); ui.page = 1; renderDone(); return; }
    if (t.closest('input[type="checkbox"]')) { return; }
    if ((el = t.closest('[data-summary]')) && !t.closest('a')) { openDrawer(el.getAttribute('data-summary'), el); return; }
    if ((el = t.closest('[data-open]'))) { document.getElementById(el.getAttribute('data-open')).showModal(); return; }
    if ((el = t.closest('[data-close]'))) { el.closest('dialog').close(); return; }
    if ((el = t.closest('.list th button'))) {
      var key = el.getAttribute('data-sort');
      ui.sort = { key: key, dir: ui.sort.key === key ? -ui.sort.dir : (key === 'updated' ? -1 : 1) };
      ui.page = 1; renderDone(); return;
    }
  });
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && !$('#drawer').hidden) { closeDrawer(); return; }
    if ((e.key === 'Enter' || e.key === ' ') && e.target.matches('tr[data-summary]')) { e.preventDefault(); openDrawer(e.target.getAttribute('data-summary'), e.target); }
  });
  document.addEventListener('toggle', function (e) {
    if (e.target.classList && e.target.classList.contains('dev-done')) { ui.doneOpen[e.target.getAttribute('data-dev')] = e.target.open; }
  }, true);

  // Pendências: resumos que ficaram para trás (status não reflete o que já
  // foi feito). Marca as linhas e manda um agente conferir merge e status.
  document.addEventListener('change', function (e) {
    var t = e.target;
    if (t.classList.contains('pend-check')) { pendChecked[t.getAttribute('data-id')] = t.checked; updatePendBar(); }
    if (t.id === 'pend-all') {
      $$('.pend-check').forEach(function (c) { c.checked = t.checked; pendChecked[c.getAttribute('data-id')] = t.checked; });
      updatePendBar();
    }
  });
  $('#pend-launch').addEventListener('click', function (e) {
    var items = VIEW.done.filter(function (c) { return pendChecked[c.id]; }).map(function (c) { return (c.isNum ? c.task : c.label) + ' (' + c.repos.join(', ') + ')'; });
    if (!items.length) { e.preventDefault(); return; }
    var cmd = claudeCmd(B.config.hubRoot, 'verificar o estado real de merge/PR e atualizar a documentacao (status e resumo/doc da task) das tasks pendentes na Biblioteca: ' + items.join('; '));
    launch(this, cmd);
  });

  // paginação
  $('#page-size').addEventListener('change', function () { ui.pageSize = parseInt(this.value, 10); store('bibPageSize', String(ui.pageSize)); ui.page = 1; renderDone(); });
  $('#page-num').addEventListener('change', function () { ui.page = parseInt(this.value, 10) || 1; renderDone(); });
  $('#page-prev').addEventListener('click', function () { ui.page--; renderDone(); });
  $('#page-next').addEventListener('click', function () { ui.page++; renderDone(); });

  // busca + repositório
  var search = $('#search'), repoIn = $('#quick-repo');
  function applyFilter() {
    ui.q = search.value.trim().toLowerCase();
    ui.repo = repoIn.value.trim().toLowerCase();
    ui.page = 1;
    renderLists();
  }
  function wireClear(input, btn) {
    function sync() { btn.classList.toggle('visible', input.value.length > 0); }
    input.addEventListener('input', sync);
    btn.addEventListener('click', function () { input.value = ''; sync(); applyFilter(); input.focus(); });
    sync();
  }
  search.addEventListener('input', applyFilter);
  repoIn.addEventListener('input', applyFilter);
  wireClear(search, $('#search-clear'));
  wireClear(repoIn, $('#quick-repo-clear'));

  // lista de repositórios (combobox próprio)
  (function () {
    var pop = $('#repo-pop'), active = -1, picking = false;
    function opts() { return $$('.repo-opt', pop); }
    function shown() { return opts().filter(function (o) { return !o.hidden; }); }
    function setActive(i) {
      var v = shown();
      opts().forEach(function (o) { o.classList.remove('active'); o.removeAttribute('aria-selected'); });
      active = v.length ? Math.max(-1, Math.min(i, v.length - 1)) : -1;
      if (active >= 0) { v[active].classList.add('active'); v[active].setAttribute('aria-selected', 'true'); v[active].scrollIntoView({ block: 'nearest' }); }
    }
    function filter() {
      var q = repoIn.value.trim().toLowerCase();
      opts().forEach(function (o) { o.hidden = !!q && o.getAttribute('data-v').toLowerCase().indexOf(q) === -1; });
      var anyFav = $$('.repo-opt.fav', pop).some(function (o) { return !o.hidden; });
      $$('.fav-group', pop).forEach(function (g) { g.hidden = !anyFav; });
      $('.repo-empty', pop).hidden = shown().length > 0;
      setActive(-1);
    }
    function openList() { pop.hidden = false; repoIn.setAttribute('aria-expanded', 'true'); filter(); }
    function closeList() { pop.hidden = true; repoIn.setAttribute('aria-expanded', 'false'); active = -1; }
    function pick(v) { picking = true; repoIn.value = v; repoIn.dispatchEvent(new Event('input')); picking = false; closeList(); }
    repoIn.addEventListener('focus', openList);
    repoIn.addEventListener('click', openList);
    repoIn.addEventListener('input', function () { if (!picking && document.activeElement === repoIn) { openList(); } });
    repoIn.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowDown') { e.preventDefault(); if (pop.hidden) { openList(); } setActive(active + 1); }
      else if (e.key === 'ArrowUp') { e.preventDefault(); setActive(active - 1); }
      else if (e.key === 'Enter' && e.ctrlKey && active >= 0) {
        e.preventDefault();
        var name = shown()[active].getAttribute('data-v');
        if (togglePin(name)) { filter(); setActive(shown().map(function (o) { return o.getAttribute('data-v'); }).indexOf(name)); }
      }
      else if (e.key === 'Enter') {
        var v = shown(), tgt = active >= 0 ? v[active] : (v.length === 1 ? v[0] : null);
        if (tgt && !pop.hidden) { e.preventDefault(); pick(tgt.getAttribute('data-v')); }
      } else if (e.key === 'Escape' || e.key === 'Tab') { closeList(); }
    });
    pop.addEventListener('mousedown', function (e) {
      e.preventDefault(); // mantém o foco no campo (lista continua aberta)
      // a lista é redesenhada ao fixar; sem isso o "clicou fora" do document
      // vê o botão antigo (já fora da página) e fecha a lista
      e.stopPropagation();
      var pin = e.target.closest('.pin-btn');
      if (pin) { if (togglePin(pin.getAttribute('data-pin'))) { filter(); } return; }
      var o = e.target.closest('.repo-opt');
      if (o) { pick(o.getAttribute('data-v')); }
    });
    document.addEventListener('mousedown', function (e) { if (!pop.hidden && !repoIn.parentNode.contains(e.target)) { closeList(); } });
  })();

  // Abrir Claude no repositório escolhido ("Biblioteca" = raiz da própria Biblioteca)
  $('#quick-open-btn').addEventListener('click', function () {
    var repo = repoIn.value.trim();
    var base = B.config.reposBasePath;
    var dir = repo.toLowerCase() === 'biblioteca' ? B.config.libRoot : (repo ? base + '\\' + repo : base);
    launch(this, 'powershell -NoProfile -Command "cd \'' + dir + '\'; claude"');
  });

  // menus do cabeçalho: um aberto por vez; fecha ao escolher, clicar fora ou Esc
  var menus = $$('details.menu');
  menus.forEach(function (m) {
    m.addEventListener('toggle', function () { if (m.open) { menus.forEach(function (o) { if (o !== m) { o.open = false; } }); } });
    m.addEventListener('click', function (e) { if (e.target.closest('.menu-item')) { m.open = false; } });
  });
  document.addEventListener('click', function (e) { menus.forEach(function (m) { if (m.open && !m.contains(e.target)) { m.open = false; } }); });
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') { return; }
    menus.forEach(function (m) { if (m.open) { m.open = false; m.querySelector('summary').focus(); } });
  });

  // lombada: destaca a linha da legenda do segmento sob o mouse
  $('#spine').addEventListener('mousemove', function (e) {
    var legend = $('.spine-legend', this), rect = this.getBoundingClientRect();
    if (legend) { legend.style.left = (e.clientX - rect.left) + 'px'; }
    var seg = e.target.closest('.spine-seg');
    $$('.legend-row', this).forEach(function (r) { r.classList.toggle('active', !!seg && r.getAttribute('data-type') === seg.getAttribute('data-type')); });
  });

  // diálogos do Time
  function lines(id) { return $('#' + id).value.split(/\r?\n/).map(function (l) { return l.trim(); }).filter(Boolean); }
  function wireLaunch(btnId, warnId, build) {
    var btn = $('#' + btnId);
    btn.addEventListener('click', function (e) {
      var r = build();
      if (r.error) { e.preventDefault(); $('#' + warnId).textContent = r.error; return; }
      $('#' + warnId).textContent = '';
      launch(btn, r.cmd);
      setTimeout(function () { var d = btn.closest('dialog'); if (d) { d.close(); } }, 400);
    });
  }
  wireLaunch('an-launch', 'an-warn', function () {
    var items = lines('an-links');
    if (!items.length) { return { error: 'Cole pelo menos uma task.' }; }
    var notes = $('#an-notes').value.trim();
    var prompt = 'Use a skill ' + B.config.delegarSkill + ' no modo analisar para as tasks abaixo. Fluxo completo da skill: buscar REQ, Task Code e parent via MCP azure-devops (somente leitura, nunca ferramentas de escrita), investigar o codigo sem editar nada nem trocar de branch, montar a tabela de analise no chat e depois perguntar qual dev pegou cada task. Biblioteca: ' + B.config.libRoot + '\nTasks:\n' + items.join('\n') + (notes ? '\nObservacoes: ' + notes : '');
    return { cmd: claudeCmd(B.config.timeClaudeDir, prompt) };
  });
  wireLaunch('rv-launch', 'rv-warn', function () {
    var found = $('#rv-links').value.match(/https:\/\/github\.com\/[^\/\s]+\/[^\/\s]+\/pull\/\d+/g) || [];
    var items = found.filter(function (l, i) { return found.indexOf(l) === i; });
    if (!items.length) { return { error: 'Nenhum link de PR do GitHub encontrado no texto.' }; }
    var prompt = 'Use a skill ' + B.config.delegarSkill + ' no modo revisar para os PRs abaixo: para cada PR, localizar a task delegada em ' + B.config.libRoot + '\\delegadas, usar a analise, o escopo e o REQ dela como referencia na revisao e registrar a rodada de review no doc da delegada.\nPRs:\n' + items.join('\n');
    return { cmd: claudeCmd(B.config.timeClaudeDir, prompt) };
  });
  wireLaunch('dev-launch', 'dev-warn', function () {
    var nome = $('#dev-nome').value.trim().replace(/\s+/g, ' ');
    var gh = $('#dev-gh').value.trim().replace(/^@/, '');
    if (!nome || nome.length > 60) { return { error: 'Nome obrigatório (até 60 caracteres).' }; }
    if (!/^[A-Za-z0-9-]{1,39}$/.test(gh)) { return { error: 'Login do GitHub inválido (letras, números e hífen).' }; }
    // nome em base64 (UTF-8): o launch-command.vbs decodifica byte a byte e quebraria acento
    var b64 = btoa(unescape(encodeURIComponent(nome)));
    return { cmd: 'powershell -NoProfile -Command "cd \'' + B.time.scriptsDir + '\'; powershell -NoProfile -ExecutionPolicy Bypass -File .\\time-dev.ps1 -NomeB64 \'' + b64 + '\' -Github \'' + gh + '\'"' };
  });

  // Atualização automática: relê data.js a cada 20s e só redesenha se o
  // sync gerou dados novos. Sem recarregar a página: busca, aba, painel
  // aberto e rolagem ficam como estão. Pula com diálogo, menu ou lista aberta.
  setInterval(function () {
    if ($('dialog[open], details.menu[open]') || !$('#repo-pop').hidden) { return; }
    var s = document.createElement('script');
    s.src = 'data.js?t=' + Date.now();
    s.onload = function () {
      s.remove();
      var next = window.BIBLIOTECA;
      if (next && next.generatedAt !== B.generatedAt) { B = next; renderAll(); }
    };
    s.onerror = function () { s.remove(); window.BIBLIOTECA = B; };
    document.body.appendChild(s);
  }, 20000);

  renderAll();
  showTab(location.hash.slice(1));
})();
