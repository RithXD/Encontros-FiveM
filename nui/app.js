<<<<<<< HEAD
/* ============================================================
   Utilitarios NUI
   ============================================================ */

const resourceName = () => (
  typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'Encontrinhos_Pog'
);

const nuiCallback = (name, data = {}) => fetch(`https://${resourceName()}/${name}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
}).then((response) => response.json());

const getElement = (id) => document.getElementById(id);
let pendingConfirmation = null;
let toastTimer = null;
let blipIcons = [];
let blipConfigs = {};
let rewardTables = {};
let publicUiConfig = {};
let adminEvents = [];
let activeEvents = [];
let attendance = {};
let claims = [];
let currentView = null;
let claimsClockOffset = 0;
let claimsRefreshInFlight = false;
let claimingId = null;
let claimsPickupKind = null;
let fixedClaimNpc = null;
let startNoticeId = null;
let startNoticeDuration = 10000;
let rewardNpcCoords = null;
let npcPlacementActive = false;
let npcPlacementRequestPending = false;

const escapeHtml = (value) => String(value || '').replace(/[&<>'"]/g, (character) => ({
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  "'": '&#39;',
  '"': '&quot;',
}[character]));

// Lua owns the queue and deadline. Opening/closing a panel never changes this
// overlay, and stale updates cannot change the next event's notice.
function showStartNotice(data) {
  const notice = data.notice || {};
  const id = String(notice.id || '');
  if (!/^\d+:\d+$/.test(id)) return;
  applyPublicUiConfig(data.publicUi || {});
  startNoticeId = id;
  const duration = Number(notice.durationMs);
  startNoticeDuration = Number.isFinite(duration) && duration > 0 ? duration : 10000;
  getElement('start-notice-title').textContent = String(notice.title || 'Encontro');
  getElement('start-notice-location').textContent = String(notice.location || 'Confira o local no mapa');
  updateStartNotice({ ...notice, id });
  getElement('start-notice').hidden = false;
}

function updateStartNotice(notice) {
  if (!notice || startNoticeId === null || String(notice.id) !== startNoticeId) return;
  const marked = notice.marked === true;
  getElement('start-notice').classList.toggle('is-marked', marked);
  getElement('start-notice-key').hidden = marked;
  getElement('start-notice-action-text').textContent = marked ? 'Local marcado no mapa' : 'Marcar no mapa';
  const remaining = Number(notice.remainingMs);
  const progress = Number.isFinite(remaining) ? Math.max(0, Math.min(1, remaining / startNoticeDuration)) : 1;
  getElement('start-notice-progress-bar').style.transform = `scaleX(${progress})`;
}

function hideStartNotice(id) {
  if (id !== undefined && id !== null && String(id) !== startNoticeId) return;
  startNoticeId = null;
  getElement('start-notice').hidden = true;
}

function getTypeLabel(type) {
  if (type === 'marcador') return 'Marcador';
  if (type === 'carros') return 'Encontro de carros';
  return 'Encontro';
}

function formatTimestamp(timestamp) {
  return new Date(timestamp * 1000).toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  });
}

/* ============================================================
   Paineis
   ============================================================ */

function closePanel() {
  if (npcPlacementActive) return;
  currentView = null;
  nuiCallback('closePanel');
  getElement('panel').hidden = true;
  closeConfirmation();
  hideToast();
}

function openPanel(view) {
  currentView = view;
  const panel = getElement('panel');
  panel.hidden = false;
  document.body.classList.toggle('admin-nui', view === 'admin');
  document.body.classList.toggle('public-nui', view !== 'admin');
  panel.classList.toggle('admin-mode', view === 'admin');
  panel.classList.toggle('public-mode', view !== 'admin');
  getElement('admin-view').hidden = view !== 'admin';
  getElement('info-view').hidden = view !== 'info';
  getElement('claims-view').hidden = view !== 'claims';
}

function openAdminTab(tabName) {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.classList.toggle('active', tab.dataset.tab === tabName);
  });

  getElement('events-tab').hidden = tabName !== 'events';
  getElement('create-tab').hidden = tabName !== 'create';
}

function closeConfirmation() {
  pendingConfirmation = null;
  getElement('confirm-dialog').hidden = true;
}

function openConfirmation({ title, message, acceptLabel, onAccept }) {
  pendingConfirmation = onAccept;
  getElement('confirm-title').textContent = title;
  getElement('confirm-message').textContent = message;
  getElement('confirm-accept').textContent = acceptLabel || 'Confirmar';
  getElement('confirm-dialog').hidden = false;
}

function acceptConfirmation() {
  const action = pendingConfirmation;
  closeConfirmation();
  if (typeof action === 'function') action();
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  getElement('nui-toast-message').textContent = message;
  getElement('nui-toast').hidden = false;
  toastTimer = window.setTimeout(hideToast, 3500);
}

function hideToast() {
  window.clearTimeout(toastTimer);
  getElement('nui-toast').hidden = true;
}

/* ============================================================
   Lista de eventos
   ============================================================ */

function getStatusLabel(event) {
  if (event.status === 'active') return 'Em andamento';
  if (event.status === 'scheduled') return `Agendado para ${formatTimestamp(event.start_time)}`;
  if (event.status === 'blocked') return 'Bloqueado';
  if (event.status === 'cancelled') return 'Cancelado';
  if (event.status === 'interrupted') return 'Interrompido';
  return 'Encerrado';
}

function buildEventCard(event) {
  const id = Number(event.id);
  const finishButton = event.status === 'active'
    ? `<button class="finish" onclick="finishEvent(${id})" title="Encerrar" aria-label="Encerrar encontro"><i class="fa-solid fa-check"></i></button>`
    : '';
  const canRecreate = ['blocked', 'cancelled', 'interrupted'].includes(event.status);
  const recreateButton = canRecreate
    ? `<button class="secondary" onclick="recreateEvent(${id})">Recriar</button>`
    : '';
  const cancelButton = ['active', 'scheduled'].includes(event.status)
    ? `<button class="danger" onclick="deleteEvent(${id})" title="Cancelar" aria-label="Cancelar encontro"><i class="fa-solid fa-ban"></i></button>`
    : '';

  const recurringLabel = Number(event.recurring) === 1 ? ' - diario' : '';
  const rewardLabel = Number(event.reward_enabled) === 1 || String(event.reward_item || '').trim() !== ''
    ? ' - com premiacao'
    : '';

  return `
    <article class="event-card ${escapeHtml(event.event_type)}">
      <div>
        <h3>
          ${escapeHtml(event.title)}
          <span class="badge">${getTypeLabel(event.event_type)}</span>
        </h3>
        <p>${escapeHtml(event.location)} - raio ${Number(event.radius)}m - ${Number(event.duration)} min</p>
        <small>${getStatusLabel(event)}${recurringLabel}${rewardLabel}</small>
        ${event.status_reason ? `<p class="event-status-reason">${escapeHtml(event.status_reason)}</p>` : ''}
      </div>
      <div class="actions">
        ${finishButton}
        ${recreateButton}
        ${cancelButton}
      </div>
    </article>
  `;
}

function renderEvents(events) {
  adminEvents = Array.isArray(events) ? events : [];
  const list = getElement('events-list');

  if (!adminEvents.length) {
    list.innerHTML = '<p class="empty">Nenhum encontro cadastrado.</p>';
    return;
  }

  list.innerHTML = adminEvents.map(buildEventCard).join('');
}

function populateBlipIcons() {
  const select = getElement('blip-sprite');
  const manualInput = getElement('blip-sprite-id');
  const icons = blipIcons.length ? blipIcons : [
    { sprite: 280, label: 'Grupo / encontro' },
    { sprite: 225, label: 'Carro' },
    { sprite: 38, label: 'Bandeira de corrida' },
  ];

  select.innerHTML = icons
    .map((icon) => `<option value="${Number(icon.sprite)}">${escapeHtml(icon.label)} (#${Number(icon.sprite)})</option>`)
    .join('');

  manualInput.value = select.value || '';
}

function syncBlipSpriteInput() {
  getElement('blip-sprite-id').value = getElement('blip-sprite').value || '';
}

function populateRewardTables() {
  const select = getElement('reward-table');
  select.innerHTML = ['pecas_carro', 'pecas_moto'].map((key) => {
    const table = rewardTables[key];
    const fallback = key === 'pecas_carro' ? 'Peças de carro' : 'Peças de moto';
    return `<option value="${key}" ${!table || table.enabled === false ? 'disabled' : ''}>${escapeHtml(table?.label || fallback)}</option>`;
  }).join('') + '<option value="pecas_caminhao" disabled>Peças de caminhão — bloqueado</option>';
  const enabled = ['pecas_carro', 'pecas_moto'].find((key) => rewardTables[key] && rewardTables[key].enabled !== false);
  select.value = enabled || '';
}

function isRandomLocationEnabled() {
  return getElement('random-location').checked === true;
}

function updateRandomLocationVisibility() {
  const random = isRandomLocationEnabled();
  const location = getElement('location');
  const coords = getElement('coords');
  const useCurrent = getElement('use-current-coords');
  const radius = getElement('radius');
  const heightTolerance = getElement('height-tolerance');
  const rewardEnabled = getElement('reward-enabled');
  const marker = getElement('event-type').value === 'marcador';
  location.disabled = random;
  coords.disabled = random;
  useCurrent.disabled = random;
  radius.disabled = random;
  heightTolerance.disabled = random;
  location.required = !random;
  coords.required = !random;
  rewardEnabled.disabled = marker;
  if (marker) {
    rewardEnabled.checked = false;
  }
  if (random) {
    rewardNpcCoords = null;
    renderRewardNpcSummary();
  }
  updateRewardVisibility();
}

function updateRewardVisibility() {
  const random = isRandomLocationEnabled();
  const enabled = getElement('event-type').value !== 'marcador' && getElement('reward-enabled').checked;
  getElement('reward-table').disabled = !enabled;
  getElement('reward-npc-wrapper').hidden = !enabled || random;
  getElement('place-reward-npc').disabled = !enabled || random || npcPlacementRequestPending;
}

function getSelectedBlipConfig() {
  const type = getElement('event-type').value;
  return blipConfigs[type] || blipConfigs.encontro || {};
}

function applyEventTypeDefaults() {
  const config = getSelectedBlipConfig();
  const isMarker = getElement('event-type').value === 'marcador';
  const radius = getElement('radius');
  const rewardEnabled = getElement('reward-enabled');

  radius.value = Number(config.radius ?? (isMarker ? 0 : 80));
  radius.readOnly = isMarker;

  rewardEnabled.disabled = isMarker;
  if (isMarker) {
    rewardEnabled.checked = false;
  }
  updateRandomLocationVisibility();
}

/* ============================================================
   Formulario de criacao
   ============================================================ */

function formatVector3(coords) {
  return `${Number(coords.x).toFixed(2)}, ${Number(coords.y).toFixed(2)}, ${Number(coords.z).toFixed(2)}`;
}

function parseVector3(value) {
  const normalized = String(value || '').trim().replace(/^vector3\s*\(/i, '').replace(/\)$/, '');
  const match = normalized.split(',').map((part) => part.trim());
  if (match.length !== 3 || match.some((part) => !/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(part))) return null;

  const coords = {
    x: Number(match[0]),
    y: Number(match[1]),
    z: Number(match[2]),
  };

  return Number.isFinite(coords.x) && Number.isFinite(coords.y) && Number.isFinite(coords.z)
    ? coords
    : null;
}

function useCurrentCoords() {
  nuiCallback('getPlayerCoords').then((coords) => {
    getElement('coords').value = formatVector3(coords);
  });
}

function formatScheduledDate(date) {
  const pad = (value) => String(value).padStart(2, '0');
  return `${pad(date.getDate())}/${pad(date.getMonth() + 1)}/${date.getFullYear()}`;
}

function formatScheduledHour(date) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

// Construct in the player's local timezone and compare every component. Date's
// automatic rollover must not turn 31/02 or 24:00 into a different booking.
function parseScheduledDate(dateValue, hourValue) {
  const dateMatch = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(String(dateValue || '').trim());
  const hourMatch = /^(\d{2}):(\d{2})$/.exec(String(hourValue || '').trim());
  if (!dateMatch || !hourMatch) return null;
  const [, day, month, year] = dateMatch.map(Number);
  const [, hour, minute] = hourMatch.map(Number);
  if (year < 1000 || month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59) return null;
  const date = new Date(year, month - 1, day, hour, minute, 0, 0);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
    && date.getHours() === hour && date.getMinutes() === minute ? date : null;
}

function maskScheduleInput(event) {
  const input = event.target;
  const raw = input.value;
  const dateField = input.id === 'scheduled-date';
  const groups = dateField ? [2, 2, 4] : [2, 2];
  const separator = dateField ? '/' : ':';
  const digits = raw.replace(/\D/g, '').slice(0, dateField ? 8 : 4);
  const caret = input.selectionStart ?? raw.length;
  const before = raw.slice(0, caret).replace(/\D/g, '').length;
  let offset = 0;
  const formatted = groups.map((length) => {
    const value = digits.slice(offset, offset + length);
    offset += length;
    return value;
  }).filter(Boolean).join(separator);
  if (formatted === raw) return;
  input.value = formatted;
  let newCaret = 0;
  let seenDigits = 0;
  while (newCaret < formatted.length && seenDigits < before) {
    if (/\d/.test(formatted[newCaret])) seenDigits += 1;
    newCaret += 1;
  }
  // Keep editing in the same digit position, including selection replacements
  // and pasted values; never jump the cursor to the end of a partial edit.
  input.setSelectionRange?.(newCaret, newCaret);
}

function updateScheduledTimeVisibility() {
  const isScheduled = getElement('status').value === 'scheduled';
  const wrapper = getElement('scheduled-time-wrapper');
  wrapper.hidden = !isScheduled;
  const dateInput = getElement('scheduled-date');
  const hourInput = getElement('scheduled-hour');
  for (const input of [dateInput, hourInput]) {
    input.required = isScheduled;
    input.disabled = !isScheduled;
  }

  if (!isScheduled) return;
  if (!dateInput.value && !hourInput.value) {
    const defaultTime = new Date(Date.now() + 5 * 60 * 1000);
    defaultTime.setSeconds(0, 0);
    dateInput.value = formatScheduledDate(defaultTime);
    hourInput.value = formatScheduledHour(defaultTime);
  }
}

function getEventFormData() {
  const status = getElement('status').value;
  const now = Math.floor(Date.now() / 1000);
  const scheduledDate = parseScheduledDate(getElement('scheduled-date').value, getElement('scheduled-hour').value);
  const randomLocation = isRandomLocationEnabled();
  const rewardEnabled = getElement('event-type').value !== 'marcador' && getElement('reward-enabled').checked;

  return {
    title: getElement('title').value,
    description: getElement('description').value,
    event_type: getElement('event-type').value,
    blip_sprite: getElement('blip-sprite-id').value || getElement('blip-sprite').value,
    random_location: randomLocation,
    location: randomLocation ? '' : getElement('location').value,
    coords: randomLocation ? null : parseVector3(getElement('coords').value),
    reward_enabled: rewardEnabled,
    ...(rewardEnabled && !randomLocation ? { npc_coords: rewardNpcCoords ? { ...rewardNpcCoords } : null } : {}),
    reward_mode: 'table',
    reward_table: getElement('reward-table').value,
    radius: getElement('radius').value,
    height_tolerance: getElement('height-tolerance').value,
    duration: getElement('duration').value,
    start_time: status === 'scheduled' ? (scheduledDate ? Math.floor(scheduledDate.getTime() / 1000) : null) : now,
    status,
    recurring: getElement('recurring').checked,
  };
}

function submitEventForm(event) {
  event.preventDefault();
  const randomLocation = isRandomLocationEnabled();

  if (!randomLocation && !parseVector3(getElement('coords').value)) {
    showToast('Informe um vector3 valido para o encontro.');
    return;
  }

  if (getElement('status').value === 'scheduled') {
    const scheduledDate = parseScheduledDate(getElement('scheduled-date').value, getElement('scheduled-hour').value);
    if (!scheduledDate) {
      showToast('Informe uma data válida em DD/MM/AAAA e um horário de 00:00 a 23:59.');
      return;
    }
    if (scheduledDate.getTime() <= Date.now()) {
      showToast('Escolha uma data e um horário futuros no horário local do seu computador.');
      return;
    }
  }

  if (getElement('event-type').value !== 'marcador' && getElement('reward-enabled').checked) {
    const key = getElement('reward-table').value;
    if (!['pecas_carro', 'pecas_moto'].includes(key) || !rewardTables[key] || rewardTables[key].enabled === false) {
      showToast('Escolha uma categoria de performance disponível: carro ou moto.');
      return;
    }
    if (!randomLocation && !rewardNpcCoords) {
      showToast('Posicione e confirme o NPC mecânico para retirar a premiação deste encontro.');
      return;
    }
  }

  return nuiCallback('createEvent', getEventFormData()).then((response) => {
    if (!response.ok) {
      showToast(response.reason || 'Nao foi possivel criar o encontro.');
    }
  }).catch(() => showToast('Não foi possível salvar. Consulte a lista de encontros antes de tentar novamente.'));
}

function normalizeNpcCoords(coords) {
  if (!coords || typeof coords !== 'object' || !['x', 'y', 'z', 'w'].every((key) => coords[key] !== null && coords[key] !== '' && Number.isFinite(Number(coords[key])))) return null;
  return { x: Number(coords.x), y: Number(coords.y), z: Number(coords.z), w: ((Number(coords.w) % 360) + 360) % 360 };
}

function formatNpcCoords(coords) {
  return `${formatVector3(coords)} · Rotação: ${Number(coords.w).toFixed(1)}°`;
}

function renderRewardNpcSummary() {
  getElement('reward-npc-summary').textContent = rewardNpcCoords ? formatNpcCoords(rewardNpcCoords) : 'Não posicionado';
}

async function placeRewardNpc() {
  if (npcPlacementActive || npcPlacementRequestPending || isRandomLocationEnabled() || getElement('event-type').value === 'marcador' || !getElement('reward-enabled').checked) return;
  const eventCoords = parseVector3(getElement('coords').value);
  if (!eventCoords) {
    showToast('Informe uma posição válida para o encontro antes de posicionar o NPC.');
    return;
  }
  npcPlacementRequestPending = true;
  updateRewardVisibility();
  try {
    const result = await nuiCallback('placeRewardNpc', {
      coords: rewardNpcCoords ? { ...rewardNpcCoords } : null,
      eventCoords,
      radius: Number(getElement('radius').value),
      heightTolerance: Number(getElement('height-tolerance').value),
    });
    if (!result.ok) showToast(result.reason || 'Não foi possível posicionar o NPC.');
  } catch (_) {
    showToast('Não foi possível iniciar o posicionamento do NPC. Tente novamente.');
  } finally {
    npcPlacementRequestPending = false;
    updateRewardVisibility();
  }
}

function updateNpcPlacement(data) {
  const coords = normalizeNpcCoords(data.coords);
  if (!npcPlacementActive || !coords) return;
  getElement('npc-placement-coords').textContent = formatNpcCoords(coords);
}

function showNpcPlacement(data) {
  if (currentView !== 'admin') return;
  npcPlacementActive = true;
  getElement('panel').hidden = true;
  getElement('npc-placement').hidden = false;
  hideToast();
  updateNpcPlacement(data);
}

function finishNpcPlacement(data) {
  if (!npcPlacementActive) return;
  npcPlacementActive = false;
  getElement('npc-placement').hidden = true;
  openPanel('admin');
  openAdminTab('create');
  const coords = normalizeNpcCoords(data.coords);
  if (data.confirmed === true && coords) {
    rewardNpcCoords = coords;
    renderRewardNpcSummary();
    showToast('Posição do NPC mecânico confirmada.');
  } else if (data.reason) {
    showToast(String(data.reason));
  }
}

/* ============================================================
   Acoes administrativas
   ============================================================ */

function deleteEvent(id) {
  openConfirmation({
    title: 'Cancelar encontro',
    message: 'O encontro será cancelado sem novo sorteio. O histórico será preservado.',
    acceptLabel: 'Cancelar encontro',
    onAccept: () => nuiCallback('deleteEvent', { id }),
  });
}

function recreateEvent(id) {
  const event = adminEvents.find((entry) => Number(entry.id) === Number(id));
  if (!event || !['blocked', 'cancelled', 'interrupted'].includes(event.status)) return;
  getElement('event-form').reset();
  getElement('random-location').checked = Number(event.random_location) === 1 || event.random_location === true;
  getElement('event-type').value = event.event_type === 'marcador' ? 'marcador' : 'encontro';
  applyEventTypeDefaults();
  getElement('title').value = event.title || '';
  getElement('description').value = event.description || '';
  getElement('location').value = event.location || '';
  getElement('coords').value = event.coords ? formatVector3(event.coords) : '';
  getElement('radius').value = event.radius ?? 80;
  getElement('height-tolerance').value = event.height_tolerance ?? 15;
  getElement('duration').value = event.duration || 60;
  getElement('blip-sprite-id').value = event.blip_sprite || 280;
  getElement('blip-sprite').value = String(event.blip_sprite || 280);
  getElement('recurring').checked = Number(event.recurring) === 1;
  getElement('reward-enabled').checked = event.event_type !== 'marcador' && (Number(event.reward_enabled) === 1 || Boolean(event.reward_item));
  getElement('reward-table').value = ['pecas_carro', 'pecas_moto'].includes(event.reward_table) ? event.reward_table : '';
  rewardNpcCoords = normalizeNpcCoords(event.npc_coords || { x: event.npc_x, y: event.npc_y, z: event.npc_z, w: event.npc_w });
  renderRewardNpcSummary();
  getElement('status').value = 'active';
  updateRandomLocationVisibility();
  updateScheduledTimeVisibility();
  openAdminTab('create');
  showToast('Revise a categoria e o início. A recriação gera um novo encontro com presença zerada.');
}

function finishEvent(id) {
  openConfirmation({
    title: 'Encerrar encontro',
    message: 'O encontro ativo sera encerrado agora para todos os jogadores.',
    acceptLabel: 'Encerrar',
    onAccept: () => nuiCallback('finishEvent', { id }),
  });
}

/* ============================================================
   Informacoes do encontro ativo
   ============================================================ */

function setCssVariable(name, value) {
  if (value === undefined || value === null || value === '') return;
  getElement('panel').style.setProperty(name, String(value));
}

function applyPublicUiConfig(config = {}) {
  publicUiConfig = config || {};
  const theme = publicUiConfig.theme || {};
  const publicLogo = getElement('public-logo');
  const publicMascot = getElement('public-mascot');
  const publicPowered = getElement('public-powered');

  setCssVariable('--public-bg', theme.background);
  setCssVariable('--public-surface', theme.surface);
  setCssVariable('--public-card', theme.card);
  setCssVariable('--public-primary', theme.primary);
  setCssVariable('--public-secondary', theme.secondary);
  setCssVariable('--public-text', theme.text);
  setCssVariable('--public-muted', theme.muted);
  setCssVariable('--public-border', theme.border);

  getElement('public-title').textContent = publicUiConfig.title || 'Encontros da Cidade';
  getElement('public-subtitle').textContent = publicUiConfig.subtitle || 'Confira os encontros ativos agora';
  getElement('public-eyebrow').textContent = publicUiConfig.eyebrow || 'ENCONTROS';
  publicPowered.textContent = publicUiConfig.footer || '';
  publicPowered.hidden = !publicUiConfig.footer;

  const logo = publicUiConfig.logo === undefined ? 'Fueltecson_Nome.png' : publicUiConfig.logo;
  const mascot = publicUiConfig.mascot === undefined ? 'Fueltecson.png' : publicUiConfig.mascot;

  publicLogo.hidden = publicUiConfig.showBrand === false || !logo;
  if (logo) publicLogo.src = logo;

  publicMascot.hidden = publicUiConfig.showMascot === false || !mascot;
  if (mascot) publicMascot.src = mascot;
}

function publicEventDate(timestamp) {
  const seconds = Number(timestamp);
  if (!Number.isFinite(seconds) || seconds <= 0) return null;
  const date = new Date(seconds * 1000);
  return Number.isFinite(date.getTime()) ? date : null;
}

function publicEventSchedule(event) {
  const scheduled = publicEventDate(event.start_time);
  const started = publicEventDate(event.started_at) || scheduled;
  const duration = Number(event.duration);
  // The server deadline stays tied to the scheduled start, even if activation was delayed.
  const end = scheduled && Number.isFinite(duration) && duration > 0
    ? publicEventDate(Number(event.start_time) + duration * 60) : null;
  const dateLabel = (date) => date ? date.toLocaleDateString('pt-BR') : '—';
  const timeLabel = (date) => date ? date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', hour12: false }) : '—';
  const endDate = end && started && end.toDateString() !== started.toDateString() ? ` (${dateLabel(end)})` : '';
  return { date: dateLabel(started), hours: `${timeLabel(started)} – ${timeLabel(end)}${endDate}` };
}

function buildEventInfoCard(event) {
  const schedule = publicEventSchedule(event);

  return `
    <article class="public-event-card ${escapeHtml(event.event_type)}">
      <div class="public-event-main">
        <h3>${escapeHtml(event.title)}</h3>
      </div>
      <div class="public-event-meta">
        <div><i class="fa-regular fa-calendar"></i><span>Data: ${schedule.date}</span></div>
        <div><i class="fa-regular fa-clock"></i><span>Horário: ${schedule.hours}</span></div>
        <div class="public-event-location"><i class="fa-solid fa-location-dot"></i><span>Local: ${escapeHtml(event.location || 'Não informado')}</span></div>
      </div>
      <div class="public-event-actions">
        <button class="public-map-btn" onclick="markEventOnMap(${Number(event.coords.x)}, ${Number(event.coords.y)}, ${Number(event.coords.z)})">
          <i class="fa-solid fa-map-location-dot"></i>
          Marcar no mapa
        </button>
      </div>
    </article>
  `;
}

function formatDuration(seconds) {
  const value = Math.max(0, Math.floor(Number(seconds) || 0));
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  const rest = value % 60;
  return `${hours ? `${hours}h ` : ''}${minutes}min ${String(rest).padStart(2, '0')}s`;
}

function renderEventInfo(events) {
  const infoView = getElement('public-events-list');
  const eventList = Array.isArray(events) ? events : (events ? [events] : []);
  activeEvents = eventList;

  if (!eventList.length) {
    const title = escapeHtml(publicUiConfig.emptyTitle || 'Nenhum encontro ativo');
    const text = escapeHtml(publicUiConfig.emptyText || 'Quando um encontro estiver acontecendo, ele aparecera aqui.');
    infoView.innerHTML = `
      <div class="public-empty">
        <i class="fa-regular fa-calendar-xmark"></i>
        <h3>${title}</h3>
        <p>${text}</p>
      </div>
    `;
    return;
  }

  infoView.innerHTML = eventList.map(buildEventInfoCard).join('');
}

function markEventOnMap(x, y, z) {
  nuiCallback('markOnMap', { x, y, z });
}

/* ============================================================
   Retirada de peças no encontro e no NPC fixo
   ============================================================ */

function claimsNow() {
  return Math.floor((Date.now() + claimsClockOffset) / 1000);
}

function claimStatus(claim) {
  if (claim.status === 'pending' && Number(claim.expires_at) <= claimsNow()) return 'expired';
  return claim.status;
}

function claimImageUrl(claim) {
  const filename = String(claim.image || `${claim.item || ''}.png`);
  // Inventory images are local assets, never markup or a remote URL supplied by a row.
  if (!/^[a-zA-Z0-9_.-]+\.(?:png|webp|jpg|jpeg)$/i.test(filename)) return '';
  return `https://cfx-nui-qb-inventory/html/images/${filename}`;
}

function buildClaimCard(claim) {
  const id = Number(claim.id);
  const state = claimStatus(claim);
  const image = claimImageUrl(claim);
  const statusLabel = { pending: 'Disponível para retirada', expired: 'Prazo expirado', claimed: 'Peça recebida', suspended: 'Prêmio suspenso' }[state] || 'Indisponível';
  const canClaim = state === 'pending' && Number.isSafeInteger(id) && id > 0;
  const expiry = Number(claim.expires_at) || 0;
  const amount = Math.max(0, Math.floor(Number(claim.amount) || 0));
  return `
    <article class="claim-card ${state === 'pending' ? 'claim-available' : 'claim-unavailable'}">
      <div class="claim-image" aria-hidden="true">
        <i class="fa-solid fa-gears"></i>
        ${image ? `<img src="${image}" alt="" loading="lazy" onerror="this.remove()" />` : ''}
      </div>
      <div class="claim-details">
        <span class="public-type">${escapeHtml(claim.event_title || 'Encontro')}</span>
        <h3>${escapeHtml(claim.label || claim.item || 'Premiação suspensa')}</h3>
        <p>${amount ? `Quantidade: <strong>${amount} ${amount === 1 ? 'unidade' : 'unidades'}</strong> · ` : ''}${statusLabel}</p>
        ${state === 'pending' ? `<p class="claim-deadline">Restam <strong class="claim-countdown" data-expires="${expiry}">${formatDuration(expiry - claimsNow())}</strong></p>` : ''}
        ${expiry ? `<small>Prazo: ${formatTimestamp(expiry)}</small>` : ''}
        ${claim.reason ? `<p class="claim-reason">${escapeHtml(claim.reason)}</p>` : ''}
      </div>
      <button class="public-map-btn claim-button" type="button" onclick="claimReward(${id})" ${!canClaim || claimingId !== null ? 'disabled' : ''}>
        ${claimingId === id ? 'Resgatando…' : canClaim ? 'Reivindicar peça' : statusLabel}
      </button>
    </article>`;
}

function renderClaims() {
  const list = getElement('claims-list');
  if (!claims.length) {
    const emptyText = claimsPickupKind === 'fixed'
      ? 'As peças não retiradas no encontro ficam disponíveis aqui 10 minutos após o término, até completar 24 horas do sorteio.'
      : 'A peça fica neste encontro por 10 minutos após o término. Depois desse período, procure o NPC fixo de retirada.';
    list.innerHTML = `<div class="public-empty"><i class="fa-solid fa-gift"></i><h3>Nenhuma peça para retirar</h3><p>${emptyText}</p></div>`;
    return;
  }
  const sorted = [...claims].sort((left, right) => (Number(left.expires_at) || Number.MAX_SAFE_INTEGER) - (Number(right.expires_at) || Number.MAX_SAFE_INTEGER) || Number(left.id) - Number(right.id));
  list.innerHTML = sorted.map(buildClaimCard).join('');
}

function setClaims(data) {
  if (Object.prototype.hasOwnProperty.call(data, 'pickup_kind')) {
    claimsPickupKind = ['fixed', 'event'].includes(data.pickup_kind) ? data.pickup_kind : null;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'fixed_npc_coords')) {
    const coords = data.fixed_npc_coords;
    fixedClaimNpc = coords && ['x', 'y', 'z'].every((key) => typeof coords[key] === 'number' && Number.isFinite(coords[key]))
      ? { x: coords.x, y: coords.y, z: coords.z } : null;
  }
  getElement('claims-pickup-help').textContent = claimsPickupKind === 'fixed'
    ? 'Uma peça por encontro. Retire sua unidade neste NPC fixo em até 24 horas após o sorteio.'
    : 'Retire no encontro até 10 minutos após o término. Depois, procure o NPC fixo. O prazo total é de 24 horas após o sorteio.';
  getElement('claims-fixed-map').hidden = claimsPickupKind === 'fixed' || !fixedClaimNpc;
  claims = Array.isArray(data.claims) ? data.claims : [];
  if (Number.isFinite(Number(data.server_time)) && Number(data.server_time) > 0) {
    claimsClockOffset = Number(data.server_time) * 1000 - Date.now();
  }
  renderClaims();
}

function markFixedClaimNpc() {
  if (currentView === 'claims' && fixedClaimNpc) {
    markEventOnMap(fixedClaimNpc.x, fixedClaimNpc.y, fixedClaimNpc.z);
  }
}

async function refreshClaims() {
  if (currentView !== 'claims' || claimsRefreshInFlight) return;
  claimsRefreshInFlight = true;
  try {
    const result = await nuiCallback('refreshClaims');
    if (currentView !== 'claims') return;
    if (result.ok) setClaims(result);
    else showToast(result.reason || 'Não foi possível consultar os prêmios.');
  } catch (_) {
    if (currentView === 'claims') showToast('Não foi possível consultar os prêmios. Tente atualizar novamente.');
  } finally {
    claimsRefreshInFlight = false;
  }
}

async function claimReward(id) {
  const claim = claims.find((entry) => Number(entry.id) === Number(id));
  if (currentView !== 'claims' || claimingId !== null || !claim || claimStatus(claim) !== 'pending') return;
  claimingId = Number(id);
  renderClaims();
  try {
    const result = await nuiCallback('claimReward', { id: Number(id) });
    if (result.ok) claim.status = 'claimed';
    if (currentView === 'claims') showToast(result.message || result.reason || (result.ok ? 'Você recebeu uma unidade da sua peça!' : 'Não foi possível retirar. Sua peça continua registrada.'));
  } catch (_) {
    if (currentView === 'claims') showToast('Resposta do resgate indisponível. Atualize a lista para consultar o resultado.');
  } finally {
    claimingId = null;
    if (currentView === 'claims') {
      renderClaims();
      await refreshClaims();
    }
  }
}

window.setInterval(() => {
  if (currentView !== 'claims' || getElement('panel').hidden) return;
  let expired = false;
  claims.forEach((claim) => {
    if (claim.status === 'pending' && claimStatus(claim) === 'expired') {
      claim.status = 'expired';
      expired = true;
    }
  });
  if (expired) renderClaims();
  document.querySelectorAll('.claim-countdown').forEach((element) => {
    element.textContent = formatDuration(Number(element.dataset.expires) - claimsNow());
  });
}, 1000);

/* ============================================================
   Eventos da NUI
   ============================================================ */

document.querySelectorAll('.tab').forEach((tab) => {
  tab.addEventListener('click', () => openAdminTab(tab.dataset.tab));
});

getElement('event-form').addEventListener('submit', submitEventForm);
getElement('event-type').addEventListener('change', applyEventTypeDefaults);
getElement('blip-sprite').addEventListener('change', syncBlipSpriteInput);
getElement('random-location').addEventListener('change', updateRandomLocationVisibility);
getElement('reward-enabled').addEventListener('change', updateRewardVisibility);
getElement('status').addEventListener('change', updateScheduledTimeVisibility);
getElement('use-current-coords').addEventListener('click', useCurrentCoords);
getElement('place-reward-npc').addEventListener('click', placeRewardNpc);
getElement('scheduled-date').addEventListener('input', maskScheduleInput);
getElement('scheduled-hour').addEventListener('input', maskScheduleInput);
getElement('confirm-cancel').addEventListener('click', closeConfirmation);
getElement('confirm-accept').addEventListener('click', acceptConfirmation);

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || typeof data !== 'object') return;

  if (data.action === 'showStartNotice') showStartNotice(data);
  if (data.action === 'updateStartNotice') updateStartNotice(data.notice);
  if (data.action === 'hideStartNotice') hideStartNotice(data.id);
  if (data.action === 'showNpcPlacement') showNpcPlacement(data);
  if (data.action === 'updateNpcPlacement') updateNpcPlacement(data);
  if (data.action === 'finishNpcPlacement') finishNpcPlacement(data);
  if (data.action === 'hidePanel') {
    npcPlacementActive = false;
    npcPlacementRequestPending = false;
    rewardNpcCoords = null;
    getElement('random-location').checked = false;
    updateRandomLocationVisibility();
    renderRewardNpcSummary();
    getElement('npc-placement').hidden = true;
    currentView = null;
    getElement('panel').hidden = true;
    closeConfirmation();
    hideToast();
  }

  if (data.action === 'showAdmin') {
    blipIcons = data.blipIcons || [];
    blipConfigs = data.blipConfigs || {};
    rewardTables = data.rewardTables || {};
    openPanel('admin');
    openAdminTab('events');
    renderEvents(data.events || []);
    populateBlipIcons();
    populateRewardTables();
    getElement('radius').value = data.defaultRadius ?? 80;
    getElement('height-tolerance').value = data.defaultHeight ?? 15;
    applyEventTypeDefaults();
    renderRewardNpcSummary();
    updateScheduledTimeVisibility();
  }

  if (data.action === 'showInfo') {
    attendance = data.attendance || {};
    applyPublicUiConfig(data.publicUi || {});
    openPanel('info');
    renderEventInfo(data.events || data.event);
  }

  if (data.action === 'updateAttendance' && currentView === 'info') {
    attendance = data.attendance || {};
    renderEventInfo(activeEvents);
  }

  if (data.action === 'activeEventStarted' && currentView === 'info') {
    renderEventInfo([...activeEvents.filter((entry) => Number(entry.id) !== Number(data.event.id)), data.event]);
  }

  if (data.action === 'activeEventRemoved' && currentView === 'info') {
    renderEventInfo(activeEvents.filter((entry) => Number(entry.id) !== Number(data.id)));
  }

  if (data.action === 'showClaims') {
    claimsPickupKind = null;
    fixedClaimNpc = null;
    applyPublicUiConfig(data.publicUi || {});
    openPanel('claims');
    setClaims(data);
  }

  if (data.action === 'refreshClaims') refreshClaims();
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (npcPlacementActive) return;
  if (!getElement('confirm-dialog').hidden) {
    closeConfirmation();
    return;
  }
  closePanel();
});
=======
/* ============================================================
   Utilitarios NUI
   ============================================================ */

const resourceName = () => (
  typeof GetParentResourceName === 'function'
    ? GetParentResourceName()
    : 'Encontrinhos_Pog'
);

const nuiCallback = (name, data = {}) => fetch(`https://${resourceName()}/${name}`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
}).then((response) => response.json());

const getElement = (id) => document.getElementById(id);
let pendingConfirmation = null;
let toastTimer = null;
let blipIcons = [];
let blipConfigs = {};
let rewardTables = {};
let publicUiConfig = {};
let adminEvents = [];
let activeEvents = [];
let attendance = {};
let claims = [];
let currentView = null;
let claimsClockOffset = 0;
let claimsRefreshInFlight = false;
let claimingId = null;
let claimsPickupKind = null;
let fixedClaimNpc = null;
let startNoticeId = null;
let startNoticeDuration = 10000;
let rewardNpcCoords = null;
let npcPlacementActive = false;
let npcPlacementRequestPending = false;

const escapeHtml = (value) => String(value || '').replace(/[&<>'"]/g, (character) => ({
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  "'": '&#39;',
  '"': '&quot;',
}[character]));

// Lua owns the queue and deadline. Opening/closing a panel never changes this
// overlay, and stale updates cannot change the next event's notice.
function showStartNotice(data) {
  const notice = data.notice || {};
  const id = String(notice.id || '');
  if (!/^\d+:\d+$/.test(id)) return;
  applyPublicUiConfig(data.publicUi || {});
  startNoticeId = id;
  const duration = Number(notice.durationMs);
  startNoticeDuration = Number.isFinite(duration) && duration > 0 ? duration : 10000;
  getElement('start-notice-title').textContent = String(notice.title || 'Encontro');
  getElement('start-notice-location').textContent = String(notice.location || 'Confira o local no mapa');
  updateStartNotice({ ...notice, id });
  getElement('start-notice').hidden = false;
}

function updateStartNotice(notice) {
  if (!notice || startNoticeId === null || String(notice.id) !== startNoticeId) return;
  const marked = notice.marked === true;
  getElement('start-notice').classList.toggle('is-marked', marked);
  getElement('start-notice-key').hidden = marked;
  getElement('start-notice-action-text').textContent = marked ? 'Local marcado no mapa' : 'Marcar no mapa';
  const remaining = Number(notice.remainingMs);
  const progress = Number.isFinite(remaining) ? Math.max(0, Math.min(1, remaining / startNoticeDuration)) : 1;
  getElement('start-notice-progress-bar').style.transform = `scaleX(${progress})`;
}

function hideStartNotice(id) {
  if (id !== undefined && id !== null && String(id) !== startNoticeId) return;
  startNoticeId = null;
  getElement('start-notice').hidden = true;
}

function getTypeLabel(type) {
  if (type === 'marcador') return 'Marcador';
  if (type === 'carros') return 'Encontro de carros';
  return 'Encontro';
}

function formatTimestamp(timestamp) {
  return new Date(timestamp * 1000).toLocaleString('pt-BR', {
    dateStyle: 'short',
    timeStyle: 'short',
  });
}

/* ============================================================
   Paineis
   ============================================================ */

function closePanel() {
  if (npcPlacementActive) return;
  currentView = null;
  nuiCallback('closePanel');
  getElement('panel').hidden = true;
  closeConfirmation();
  hideToast();
}

function openPanel(view) {
  currentView = view;
  const panel = getElement('panel');
  panel.hidden = false;
  document.body.classList.toggle('admin-nui', view === 'admin');
  document.body.classList.toggle('public-nui', view !== 'admin');
  panel.classList.toggle('admin-mode', view === 'admin');
  panel.classList.toggle('public-mode', view !== 'admin');
  getElement('admin-view').hidden = view !== 'admin';
  getElement('info-view').hidden = view !== 'info';
  getElement('claims-view').hidden = view !== 'claims';
}

function openAdminTab(tabName) {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.classList.toggle('active', tab.dataset.tab === tabName);
  });

  getElement('events-tab').hidden = tabName !== 'events';
  getElement('create-tab').hidden = tabName !== 'create';
}

function closeConfirmation() {
  pendingConfirmation = null;
  getElement('confirm-dialog').hidden = true;
}

function openConfirmation({ title, message, acceptLabel, onAccept }) {
  pendingConfirmation = onAccept;
  getElement('confirm-title').textContent = title;
  getElement('confirm-message').textContent = message;
  getElement('confirm-accept').textContent = acceptLabel || 'Confirmar';
  getElement('confirm-dialog').hidden = false;
}

function acceptConfirmation() {
  const action = pendingConfirmation;
  closeConfirmation();
  if (typeof action === 'function') action();
}

function showToast(message) {
  window.clearTimeout(toastTimer);
  getElement('nui-toast-message').textContent = message;
  getElement('nui-toast').hidden = false;
  toastTimer = window.setTimeout(hideToast, 3500);
}

function hideToast() {
  window.clearTimeout(toastTimer);
  getElement('nui-toast').hidden = true;
}

/* ============================================================
   Lista de eventos
   ============================================================ */

function getStatusLabel(event) {
  if (event.status === 'active') return 'Em andamento';
  if (event.status === 'scheduled') return `Agendado para ${formatTimestamp(event.start_time)}`;
  if (event.status === 'blocked') return 'Bloqueado';
  if (event.status === 'cancelled') return 'Cancelado';
  if (event.status === 'interrupted') return 'Interrompido';
  return 'Encerrado';
}

function buildEventCard(event) {
  const id = Number(event.id);
  const finishButton = event.status === 'active'
    ? `<button class="finish" onclick="finishEvent(${id})" title="Encerrar" aria-label="Encerrar encontro"><i class="fa-solid fa-check"></i></button>`
    : '';
  const canRecreate = ['blocked', 'cancelled', 'interrupted'].includes(event.status);
  const recreateButton = canRecreate
    ? `<button class="secondary" onclick="recreateEvent(${id})">Recriar</button>`
    : '';
  const cancelButton = ['active', 'scheduled'].includes(event.status)
    ? `<button class="danger" onclick="deleteEvent(${id})" title="Cancelar" aria-label="Cancelar encontro"><i class="fa-solid fa-ban"></i></button>`
    : '';

  const recurringLabel = Number(event.recurring) === 1 ? ' - diario' : '';
  const rewardLabel = Number(event.reward_enabled) === 1 || String(event.reward_item || '').trim() !== ''
    ? ' - com premiacao'
    : '';

  return `
    <article class="event-card ${escapeHtml(event.event_type)}">
      <div>
        <h3>
          ${escapeHtml(event.title)}
          <span class="badge">${getTypeLabel(event.event_type)}</span>
        </h3>
        <p>${escapeHtml(event.location)} - raio ${Number(event.radius)}m - ${Number(event.duration)} min</p>
        <small>${getStatusLabel(event)}${recurringLabel}${rewardLabel}</small>
        ${event.status_reason ? `<p class="event-status-reason">${escapeHtml(event.status_reason)}</p>` : ''}
      </div>
      <div class="actions">
        ${finishButton}
        ${recreateButton}
        ${cancelButton}
      </div>
    </article>
  `;
}

function renderEvents(events) {
  adminEvents = Array.isArray(events) ? events : [];
  const list = getElement('events-list');

  if (!adminEvents.length) {
    list.innerHTML = '<p class="empty">Nenhum encontro cadastrado.</p>';
    return;
  }

  list.innerHTML = adminEvents.map(buildEventCard).join('');
}

function populateBlipIcons() {
  const select = getElement('blip-sprite');
  const manualInput = getElement('blip-sprite-id');
  const icons = blipIcons.length ? blipIcons : [
    { sprite: 280, label: 'Grupo / encontro' },
    { sprite: 225, label: 'Carro' },
    { sprite: 38, label: 'Bandeira de corrida' },
  ];

  select.innerHTML = icons
    .map((icon) => `<option value="${Number(icon.sprite)}">${escapeHtml(icon.label)} (#${Number(icon.sprite)})</option>`)
    .join('');

  manualInput.value = select.value || '';
}

function syncBlipSpriteInput() {
  getElement('blip-sprite-id').value = getElement('blip-sprite').value || '';
}

function populateRewardTables() {
  const select = getElement('reward-table');
  select.innerHTML = ['pecas_carro', 'pecas_moto'].map((key) => {
    const table = rewardTables[key];
    const fallback = key === 'pecas_carro' ? 'Peças de carro' : 'Peças de moto';
    return `<option value="${key}" ${!table || table.enabled === false ? 'disabled' : ''}>${escapeHtml(table?.label || fallback)}</option>`;
  }).join('') + '<option value="pecas_caminhao" disabled>Peças de caminhão — bloqueado</option>';
  const enabled = ['pecas_carro', 'pecas_moto'].find((key) => rewardTables[key] && rewardTables[key].enabled !== false);
  select.value = enabled || '';
}

function isRandomLocationEnabled() {
  return getElement('random-location').checked === true;
}

function updateRandomLocationVisibility() {
  const random = isRandomLocationEnabled();
  const location = getElement('location');
  const coords = getElement('coords');
  const useCurrent = getElement('use-current-coords');
  const radius = getElement('radius');
  const heightTolerance = getElement('height-tolerance');
  const rewardEnabled = getElement('reward-enabled');
  const marker = getElement('event-type').value === 'marcador';
  location.disabled = random;
  coords.disabled = random;
  useCurrent.disabled = random;
  radius.disabled = random;
  heightTolerance.disabled = random;
  location.required = !random;
  coords.required = !random;
  rewardEnabled.disabled = marker;
  if (marker) {
    rewardEnabled.checked = false;
  }
  if (random) {
    rewardNpcCoords = null;
    renderRewardNpcSummary();
  }
  updateRewardVisibility();
}

function updateRewardVisibility() {
  const random = isRandomLocationEnabled();
  const enabled = getElement('event-type').value !== 'marcador' && getElement('reward-enabled').checked;
  getElement('reward-table').disabled = !enabled;
  getElement('reward-npc-wrapper').hidden = !enabled || random;
  getElement('place-reward-npc').disabled = !enabled || random || npcPlacementRequestPending;
}

function getSelectedBlipConfig() {
  const type = getElement('event-type').value;
  return blipConfigs[type] || blipConfigs.encontro || {};
}

function applyEventTypeDefaults() {
  const config = getSelectedBlipConfig();
  const isMarker = getElement('event-type').value === 'marcador';
  const radius = getElement('radius');
  const rewardEnabled = getElement('reward-enabled');

  radius.value = Number(config.radius ?? (isMarker ? 0 : 80));
  radius.readOnly = isMarker;

  rewardEnabled.disabled = isMarker;
  if (isMarker) {
    rewardEnabled.checked = false;
  }
  updateRandomLocationVisibility();
}

/* ============================================================
   Formulario de criacao
   ============================================================ */

function formatVector3(coords) {
  return `${Number(coords.x).toFixed(2)}, ${Number(coords.y).toFixed(2)}, ${Number(coords.z).toFixed(2)}`;
}

function parseVector3(value) {
  const normalized = String(value || '').trim().replace(/^vector3\s*\(/i, '').replace(/\)$/, '');
  const match = normalized.split(',').map((part) => part.trim());
  if (match.length !== 3 || match.some((part) => !/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(part))) return null;

  const coords = {
    x: Number(match[0]),
    y: Number(match[1]),
    z: Number(match[2]),
  };

  return Number.isFinite(coords.x) && Number.isFinite(coords.y) && Number.isFinite(coords.z)
    ? coords
    : null;
}

function useCurrentCoords() {
  nuiCallback('getPlayerCoords').then((coords) => {
    getElement('coords').value = formatVector3(coords);
  });
}

function formatScheduledDate(date) {
  const pad = (value) => String(value).padStart(2, '0');
  return `${pad(date.getDate())}/${pad(date.getMonth() + 1)}/${date.getFullYear()}`;
}

function formatScheduledHour(date) {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

// Construct in the player's local timezone and compare every component. Date's
// automatic rollover must not turn 31/02 or 24:00 into a different booking.
function parseScheduledDate(dateValue, hourValue) {
  const dateMatch = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(String(dateValue || '').trim());
  const hourMatch = /^(\d{2}):(\d{2})$/.exec(String(hourValue || '').trim());
  if (!dateMatch || !hourMatch) return null;
  const [, day, month, year] = dateMatch.map(Number);
  const [, hour, minute] = hourMatch.map(Number);
  if (year < 1000 || month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59) return null;
  const date = new Date(year, month - 1, day, hour, minute, 0, 0);
  return date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day
    && date.getHours() === hour && date.getMinutes() === minute ? date : null;
}

function maskScheduleInput(event) {
  const input = event.target;
  const raw = input.value;
  const dateField = input.id === 'scheduled-date';
  const groups = dateField ? [2, 2, 4] : [2, 2];
  const separator = dateField ? '/' : ':';
  const digits = raw.replace(/\D/g, '').slice(0, dateField ? 8 : 4);
  const caret = input.selectionStart ?? raw.length;
  const before = raw.slice(0, caret).replace(/\D/g, '').length;
  let offset = 0;
  const formatted = groups.map((length) => {
    const value = digits.slice(offset, offset + length);
    offset += length;
    return value;
  }).filter(Boolean).join(separator);
  if (formatted === raw) return;
  input.value = formatted;
  let newCaret = 0;
  let seenDigits = 0;
  while (newCaret < formatted.length && seenDigits < before) {
    if (/\d/.test(formatted[newCaret])) seenDigits += 1;
    newCaret += 1;
  }
  // Keep editing in the same digit position, including selection replacements
  // and pasted values; never jump the cursor to the end of a partial edit.
  input.setSelectionRange?.(newCaret, newCaret);
}

function updateScheduledTimeVisibility() {
  const isScheduled = getElement('status').value === 'scheduled';
  const wrapper = getElement('scheduled-time-wrapper');
  wrapper.hidden = !isScheduled;
  const dateInput = getElement('scheduled-date');
  const hourInput = getElement('scheduled-hour');
  for (const input of [dateInput, hourInput]) {
    input.required = isScheduled;
    input.disabled = !isScheduled;
  }

  if (!isScheduled) return;
  if (!dateInput.value && !hourInput.value) {
    const defaultTime = new Date(Date.now() + 5 * 60 * 1000);
    defaultTime.setSeconds(0, 0);
    dateInput.value = formatScheduledDate(defaultTime);
    hourInput.value = formatScheduledHour(defaultTime);
  }
}

function getEventFormData() {
  const status = getElement('status').value;
  const now = Math.floor(Date.now() / 1000);
  const scheduledDate = parseScheduledDate(getElement('scheduled-date').value, getElement('scheduled-hour').value);
  const randomLocation = isRandomLocationEnabled();
  const rewardEnabled = getElement('event-type').value !== 'marcador' && getElement('reward-enabled').checked;

  return {
    title: getElement('title').value,
    description: getElement('description').value,
    event_type: getElement('event-type').value,
    blip_sprite: getElement('blip-sprite-id').value || getElement('blip-sprite').value,
    random_location: randomLocation,
    location: randomLocation ? '' : getElement('location').value,
    coords: randomLocation ? null : parseVector3(getElement('coords').value),
    reward_enabled: rewardEnabled,
    ...(rewardEnabled && !randomLocation ? { npc_coords: rewardNpcCoords ? { ...rewardNpcCoords } : null } : {}),
    reward_mode: 'table',
    reward_table: getElement('reward-table').value,
    radius: getElement('radius').value,
    height_tolerance: getElement('height-tolerance').value,
    duration: getElement('duration').value,
    start_time: status === 'scheduled' ? (scheduledDate ? Math.floor(scheduledDate.getTime() / 1000) : null) : now,
    status,
    recurring: getElement('recurring').checked,
  };
}

function submitEventForm(event) {
  event.preventDefault();
  const randomLocation = isRandomLocationEnabled();

  if (!randomLocation && !parseVector3(getElement('coords').value)) {
    showToast('Informe um vector3 valido para o encontro.');
    return;
  }

  if (getElement('status').value === 'scheduled') {
    const scheduledDate = parseScheduledDate(getElement('scheduled-date').value, getElement('scheduled-hour').value);
    if (!scheduledDate) {
      showToast('Informe uma data válida em DD/MM/AAAA e um horário de 00:00 a 23:59.');
      return;
    }
    if (scheduledDate.getTime() <= Date.now()) {
      showToast('Escolha uma data e um horário futuros no horário local do seu computador.');
      return;
    }
  }

  if (getElement('event-type').value !== 'marcador' && getElement('reward-enabled').checked) {
    const key = getElement('reward-table').value;
    if (!['pecas_carro', 'pecas_moto'].includes(key) || !rewardTables[key] || rewardTables[key].enabled === false) {
      showToast('Escolha uma categoria de performance disponível: carro ou moto.');
      return;
    }
    if (!randomLocation && !rewardNpcCoords) {
      showToast('Posicione e confirme o NPC mecânico para retirar a premiação deste encontro.');
      return;
    }
  }

  return nuiCallback('createEvent', getEventFormData()).then((response) => {
    if (!response.ok) {
      showToast(response.reason || 'Nao foi possivel criar o encontro.');
    }
  }).catch(() => showToast('Não foi possível salvar. Consulte a lista de encontros antes de tentar novamente.'));
}

function normalizeNpcCoords(coords) {
  if (!coords || typeof coords !== 'object' || !['x', 'y', 'z', 'w'].every((key) => coords[key] !== null && coords[key] !== '' && Number.isFinite(Number(coords[key])))) return null;
  return { x: Number(coords.x), y: Number(coords.y), z: Number(coords.z), w: ((Number(coords.w) % 360) + 360) % 360 };
}

function formatNpcCoords(coords) {
  return `${formatVector3(coords)} · Rotação: ${Number(coords.w).toFixed(1)}°`;
}

function renderRewardNpcSummary() {
  getElement('reward-npc-summary').textContent = rewardNpcCoords ? formatNpcCoords(rewardNpcCoords) : 'Não posicionado';
}

async function placeRewardNpc() {
  if (npcPlacementActive || npcPlacementRequestPending || isRandomLocationEnabled() || getElement('event-type').value === 'marcador' || !getElement('reward-enabled').checked) return;
  const eventCoords = parseVector3(getElement('coords').value);
  if (!eventCoords) {
    showToast('Informe uma posição válida para o encontro antes de posicionar o NPC.');
    return;
  }
  npcPlacementRequestPending = true;
  updateRewardVisibility();
  try {
    const result = await nuiCallback('placeRewardNpc', {
      coords: rewardNpcCoords ? { ...rewardNpcCoords } : null,
      eventCoords,
      radius: Number(getElement('radius').value),
      heightTolerance: Number(getElement('height-tolerance').value),
    });
    if (!result.ok) showToast(result.reason || 'Não foi possível posicionar o NPC.');
  } catch (_) {
    showToast('Não foi possível iniciar o posicionamento do NPC. Tente novamente.');
  } finally {
    npcPlacementRequestPending = false;
    updateRewardVisibility();
  }
}

function updateNpcPlacement(data) {
  const coords = normalizeNpcCoords(data.coords);
  if (!npcPlacementActive || !coords) return;
  getElement('npc-placement-coords').textContent = formatNpcCoords(coords);
}

function showNpcPlacement(data) {
  if (currentView !== 'admin') return;
  npcPlacementActive = true;
  getElement('panel').hidden = true;
  getElement('npc-placement').hidden = false;
  hideToast();
  updateNpcPlacement(data);
}

function finishNpcPlacement(data) {
  if (!npcPlacementActive) return;
  npcPlacementActive = false;
  getElement('npc-placement').hidden = true;
  openPanel('admin');
  openAdminTab('create');
  const coords = normalizeNpcCoords(data.coords);
  if (data.confirmed === true && coords) {
    rewardNpcCoords = coords;
    renderRewardNpcSummary();
    showToast('Posição do NPC mecânico confirmada.');
  } else if (data.reason) {
    showToast(String(data.reason));
  }
}

/* ============================================================
   Acoes administrativas
   ============================================================ */

function deleteEvent(id) {
  openConfirmation({
    title: 'Cancelar encontro',
    message: 'O encontro será cancelado sem novo sorteio. O histórico será preservado.',
    acceptLabel: 'Cancelar encontro',
    onAccept: () => nuiCallback('deleteEvent', { id }),
  });
}

function recreateEvent(id) {
  const event = adminEvents.find((entry) => Number(entry.id) === Number(id));
  if (!event || !['blocked', 'cancelled', 'interrupted'].includes(event.status)) return;
  getElement('event-form').reset();
  getElement('random-location').checked = Number(event.random_location) === 1 || event.random_location === true;
  getElement('event-type').value = event.event_type === 'marcador' ? 'marcador' : 'encontro';
  applyEventTypeDefaults();
  getElement('title').value = event.title || '';
  getElement('description').value = event.description || '';
  getElement('location').value = event.location || '';
  getElement('coords').value = event.coords ? formatVector3(event.coords) : '';
  getElement('radius').value = event.radius ?? 80;
  getElement('height-tolerance').value = event.height_tolerance ?? 15;
  getElement('duration').value = event.duration || 60;
  getElement('blip-sprite-id').value = event.blip_sprite || 280;
  getElement('blip-sprite').value = String(event.blip_sprite || 280);
  getElement('recurring').checked = Number(event.recurring) === 1;
  getElement('reward-enabled').checked = event.event_type !== 'marcador' && (Number(event.reward_enabled) === 1 || Boolean(event.reward_item));
  getElement('reward-table').value = ['pecas_carro', 'pecas_moto'].includes(event.reward_table) ? event.reward_table : '';
  rewardNpcCoords = normalizeNpcCoords(event.npc_coords || { x: event.npc_x, y: event.npc_y, z: event.npc_z, w: event.npc_w });
  renderRewardNpcSummary();
  getElement('status').value = 'active';
  updateRandomLocationVisibility();
  updateScheduledTimeVisibility();
  openAdminTab('create');
  showToast('Revise a categoria e o início. A recriação gera um novo encontro com presença zerada.');
}

function finishEvent(id) {
  openConfirmation({
    title: 'Encerrar encontro',
    message: 'O encontro ativo sera encerrado agora para todos os jogadores.',
    acceptLabel: 'Encerrar',
    onAccept: () => nuiCallback('finishEvent', { id }),
  });
}

/* ============================================================
   Informacoes do encontro ativo
   ============================================================ */

function setCssVariable(name, value) {
  if (value === undefined || value === null || value === '') return;
  getElement('panel').style.setProperty(name, String(value));
}

function applyPublicUiConfig(config = {}) {
  publicUiConfig = config || {};
  const theme = publicUiConfig.theme || {};
  const publicLogo = getElement('public-logo');
  const publicMascot = getElement('public-mascot');
  const publicPowered = getElement('public-powered');

  setCssVariable('--public-bg', theme.background);
  setCssVariable('--public-surface', theme.surface);
  setCssVariable('--public-card', theme.card);
  setCssVariable('--public-primary', theme.primary);
  setCssVariable('--public-secondary', theme.secondary);
  setCssVariable('--public-text', theme.text);
  setCssVariable('--public-muted', theme.muted);
  setCssVariable('--public-border', theme.border);

  getElement('public-title').textContent = publicUiConfig.title || 'Encontros da Cidade';
  getElement('public-subtitle').textContent = publicUiConfig.subtitle || 'Confira os encontros ativos agora';
  getElement('public-eyebrow').textContent = publicUiConfig.eyebrow || 'ENCONTROS';
  publicPowered.textContent = publicUiConfig.footer || '';
  publicPowered.hidden = !publicUiConfig.footer;

  const logo = publicUiConfig.logo === undefined ? 'Fueltecson_Nome.png' : publicUiConfig.logo;
  const mascot = publicUiConfig.mascot === undefined ? 'Fueltecson.png' : publicUiConfig.mascot;

  publicLogo.hidden = publicUiConfig.showBrand === false || !logo;
  if (logo) publicLogo.src = logo;

  publicMascot.hidden = publicUiConfig.showMascot === false || !mascot;
  if (mascot) publicMascot.src = mascot;
}

function publicEventDate(timestamp) {
  const seconds = Number(timestamp);
  if (!Number.isFinite(seconds) || seconds <= 0) return null;
  const date = new Date(seconds * 1000);
  return Number.isFinite(date.getTime()) ? date : null;
}

function publicEventSchedule(event) {
  const scheduled = publicEventDate(event.start_time);
  const started = publicEventDate(event.started_at) || scheduled;
  const duration = Number(event.duration);
  // The server deadline stays tied to the scheduled start, even if activation was delayed.
  const end = scheduled && Number.isFinite(duration) && duration > 0
    ? publicEventDate(Number(event.start_time) + duration * 60) : null;
  const dateLabel = (date) => date ? date.toLocaleDateString('pt-BR') : '—';
  const timeLabel = (date) => date ? date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit', hour12: false }) : '—';
  const endDate = end && started && end.toDateString() !== started.toDateString() ? ` (${dateLabel(end)})` : '';
  return { date: dateLabel(started), hours: `${timeLabel(started)} – ${timeLabel(end)}${endDate}` };
}

function buildEventInfoCard(event) {
  const schedule = publicEventSchedule(event);

  return `
    <article class="public-event-card ${escapeHtml(event.event_type)}">
      <div class="public-event-main">
        <h3>${escapeHtml(event.title)}</h3>
      </div>
      <div class="public-event-meta">
        <div><i class="fa-regular fa-calendar"></i><span>Data: ${schedule.date}</span></div>
        <div><i class="fa-regular fa-clock"></i><span>Horário: ${schedule.hours}</span></div>
        <div class="public-event-location"><i class="fa-solid fa-location-dot"></i><span>Local: ${escapeHtml(event.location || 'Não informado')}</span></div>
      </div>
      <div class="public-event-actions">
        <button class="public-map-btn" onclick="markEventOnMap(${Number(event.coords.x)}, ${Number(event.coords.y)}, ${Number(event.coords.z)})">
          <i class="fa-solid fa-map-location-dot"></i>
          Marcar no mapa
        </button>
      </div>
    </article>
  `;
}

function formatDuration(seconds) {
  const value = Math.max(0, Math.floor(Number(seconds) || 0));
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  const rest = value % 60;
  return `${hours ? `${hours}h ` : ''}${minutes}min ${String(rest).padStart(2, '0')}s`;
}

function renderEventInfo(events) {
  const infoView = getElement('public-events-list');
  const eventList = Array.isArray(events) ? events : (events ? [events] : []);
  activeEvents = eventList;

  if (!eventList.length) {
    const title = escapeHtml(publicUiConfig.emptyTitle || 'Nenhum encontro ativo');
    const text = escapeHtml(publicUiConfig.emptyText || 'Quando um encontro estiver acontecendo, ele aparecera aqui.');
    infoView.innerHTML = `
      <div class="public-empty">
        <i class="fa-regular fa-calendar-xmark"></i>
        <h3>${title}</h3>
        <p>${text}</p>
      </div>
    `;
    return;
  }

  infoView.innerHTML = eventList.map(buildEventInfoCard).join('');
}

function markEventOnMap(x, y, z) {
  nuiCallback('markOnMap', { x, y, z });
}

/* ============================================================
   Retirada de peças no encontro e no NPC fixo
   ============================================================ */

function claimsNow() {
  return Math.floor((Date.now() + claimsClockOffset) / 1000);
}

function claimStatus(claim) {
  if (claim.status === 'pending' && Number(claim.expires_at) <= claimsNow()) return 'expired';
  return claim.status;
}

function claimImageUrl(claim) {
  const filename = String(claim.image || `${claim.item || ''}.png`);
  // Inventory images are local assets, never markup or a remote URL supplied by a row.
  if (!/^[a-zA-Z0-9_.-]+\.(?:png|webp|jpg|jpeg)$/i.test(filename)) return '';
  return `https://cfx-nui-qb-inventory/html/images/${filename}`;
}

function buildClaimCard(claim) {
  const id = Number(claim.id);
  const state = claimStatus(claim);
  const image = claimImageUrl(claim);
  const statusLabel = { pending: 'Disponível para retirada', expired: 'Prazo expirado', claimed: 'Peça recebida', suspended: 'Prêmio suspenso' }[state] || 'Indisponível';
  const canClaim = state === 'pending' && Number.isSafeInteger(id) && id > 0;
  const expiry = Number(claim.expires_at) || 0;
  const amount = Math.max(0, Math.floor(Number(claim.amount) || 0));
  return `
    <article class="claim-card ${state === 'pending' ? 'claim-available' : 'claim-unavailable'}">
      <div class="claim-image" aria-hidden="true">
        <i class="fa-solid fa-gears"></i>
        ${image ? `<img src="${image}" alt="" loading="lazy" onerror="this.remove()" />` : ''}
      </div>
      <div class="claim-details">
        <span class="public-type">${escapeHtml(claim.event_title || 'Encontro')}</span>
        <h3>${escapeHtml(claim.label || claim.item || 'Premiação suspensa')}</h3>
        <p>${amount ? `Quantidade: <strong>${amount} ${amount === 1 ? 'unidade' : 'unidades'}</strong> · ` : ''}${statusLabel}</p>
        ${state === 'pending' ? `<p class="claim-deadline">Restam <strong class="claim-countdown" data-expires="${expiry}">${formatDuration(expiry - claimsNow())}</strong></p>` : ''}
        ${expiry ? `<small>Prazo: ${formatTimestamp(expiry)}</small>` : ''}
        ${claim.reason ? `<p class="claim-reason">${escapeHtml(claim.reason)}</p>` : ''}
      </div>
      <button class="public-map-btn claim-button" type="button" onclick="claimReward(${id})" ${!canClaim || claimingId !== null ? 'disabled' : ''}>
        ${claimingId === id ? 'Resgatando…' : canClaim ? 'Reivindicar peça' : statusLabel}
      </button>
    </article>`;
}

function renderClaims() {
  const list = getElement('claims-list');
  if (!claims.length) {
    const emptyText = claimsPickupKind === 'fixed'
      ? 'As peças não retiradas no encontro ficam disponíveis aqui 10 minutos após o término, até completar 24 horas do sorteio.'
      : 'A peça fica neste encontro por 10 minutos após o término. Depois desse período, procure o NPC fixo de retirada.';
    list.innerHTML = `<div class="public-empty"><i class="fa-solid fa-gift"></i><h3>Nenhuma peça para retirar</h3><p>${emptyText}</p></div>`;
    return;
  }
  const sorted = [...claims].sort((left, right) => (Number(left.expires_at) || Number.MAX_SAFE_INTEGER) - (Number(right.expires_at) || Number.MAX_SAFE_INTEGER) || Number(left.id) - Number(right.id));
  list.innerHTML = sorted.map(buildClaimCard).join('');
}

function setClaims(data) {
  if (Object.prototype.hasOwnProperty.call(data, 'pickup_kind')) {
    claimsPickupKind = ['fixed', 'event'].includes(data.pickup_kind) ? data.pickup_kind : null;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'fixed_npc_coords')) {
    const coords = data.fixed_npc_coords;
    fixedClaimNpc = coords && ['x', 'y', 'z'].every((key) => typeof coords[key] === 'number' && Number.isFinite(coords[key]))
      ? { x: coords.x, y: coords.y, z: coords.z } : null;
  }
  getElement('claims-pickup-help').textContent = claimsPickupKind === 'fixed'
    ? 'Uma peça por encontro. Retire sua unidade neste NPC fixo em até 24 horas após o sorteio.'
    : 'Retire no encontro até 10 minutos após o término. Depois, procure o NPC fixo. O prazo total é de 24 horas após o sorteio.';
  getElement('claims-fixed-map').hidden = claimsPickupKind === 'fixed' || !fixedClaimNpc;
  claims = Array.isArray(data.claims) ? data.claims : [];
  if (Number.isFinite(Number(data.server_time)) && Number(data.server_time) > 0) {
    claimsClockOffset = Number(data.server_time) * 1000 - Date.now();
  }
  renderClaims();
}

function markFixedClaimNpc() {
  if (currentView === 'claims' && fixedClaimNpc) {
    markEventOnMap(fixedClaimNpc.x, fixedClaimNpc.y, fixedClaimNpc.z);
  }
}

async function refreshClaims() {
  if (currentView !== 'claims' || claimsRefreshInFlight) return;
  claimsRefreshInFlight = true;
  try {
    const result = await nuiCallback('refreshClaims');
    if (currentView !== 'claims') return;
    if (result.ok) setClaims(result);
    else showToast(result.reason || 'Não foi possível consultar os prêmios.');
  } catch (_) {
    if (currentView === 'claims') showToast('Não foi possível consultar os prêmios. Tente atualizar novamente.');
  } finally {
    claimsRefreshInFlight = false;
  }
}

async function claimReward(id) {
  const claim = claims.find((entry) => Number(entry.id) === Number(id));
  if (currentView !== 'claims' || claimingId !== null || !claim || claimStatus(claim) !== 'pending') return;
  claimingId = Number(id);
  renderClaims();
  try {
    const result = await nuiCallback('claimReward', { id: Number(id) });
    if (result.ok) claim.status = 'claimed';
    if (currentView === 'claims') showToast(result.message || result.reason || (result.ok ? 'Você recebeu uma unidade da sua peça!' : 'Não foi possível retirar. Sua peça continua registrada.'));
  } catch (_) {
    if (currentView === 'claims') showToast('Resposta do resgate indisponível. Atualize a lista para consultar o resultado.');
  } finally {
    claimingId = null;
    if (currentView === 'claims') {
      renderClaims();
      await refreshClaims();
    }
  }
}

window.setInterval(() => {
  if (currentView !== 'claims' || getElement('panel').hidden) return;
  let expired = false;
  claims.forEach((claim) => {
    if (claim.status === 'pending' && claimStatus(claim) === 'expired') {
      claim.status = 'expired';
      expired = true;
    }
  });
  if (expired) renderClaims();
  document.querySelectorAll('.claim-countdown').forEach((element) => {
    element.textContent = formatDuration(Number(element.dataset.expires) - claimsNow());
  });
}, 1000);

/* ============================================================
   Eventos da NUI
   ============================================================ */

document.querySelectorAll('.tab').forEach((tab) => {
  tab.addEventListener('click', () => openAdminTab(tab.dataset.tab));
});

getElement('event-form').addEventListener('submit', submitEventForm);
getElement('event-type').addEventListener('change', applyEventTypeDefaults);
getElement('blip-sprite').addEventListener('change', syncBlipSpriteInput);
getElement('random-location').addEventListener('change', updateRandomLocationVisibility);
getElement('reward-enabled').addEventListener('change', updateRewardVisibility);
getElement('status').addEventListener('change', updateScheduledTimeVisibility);
getElement('use-current-coords').addEventListener('click', useCurrentCoords);
getElement('place-reward-npc').addEventListener('click', placeRewardNpc);
getElement('scheduled-date').addEventListener('input', maskScheduleInput);
getElement('scheduled-hour').addEventListener('input', maskScheduleInput);
getElement('confirm-cancel').addEventListener('click', closeConfirmation);
getElement('confirm-accept').addEventListener('click', acceptConfirmation);

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || typeof data !== 'object') return;

  if (data.action === 'showStartNotice') showStartNotice(data);
  if (data.action === 'updateStartNotice') updateStartNotice(data.notice);
  if (data.action === 'hideStartNotice') hideStartNotice(data.id);
  if (data.action === 'showNpcPlacement') showNpcPlacement(data);
  if (data.action === 'updateNpcPlacement') updateNpcPlacement(data);
  if (data.action === 'finishNpcPlacement') finishNpcPlacement(data);
  if (data.action === 'hidePanel') {
    npcPlacementActive = false;
    npcPlacementRequestPending = false;
    rewardNpcCoords = null;
    getElement('random-location').checked = false;
    updateRandomLocationVisibility();
    renderRewardNpcSummary();
    getElement('npc-placement').hidden = true;
    currentView = null;
    getElement('panel').hidden = true;
    closeConfirmation();
    hideToast();
  }

  if (data.action === 'showAdmin') {
    blipIcons = data.blipIcons || [];
    blipConfigs = data.blipConfigs || {};
    rewardTables = data.rewardTables || {};
    openPanel('admin');
    openAdminTab('events');
    renderEvents(data.events || []);
    populateBlipIcons();
    populateRewardTables();
    getElement('radius').value = data.defaultRadius ?? 80;
    getElement('height-tolerance').value = data.defaultHeight ?? 15;
    applyEventTypeDefaults();
    renderRewardNpcSummary();
    updateScheduledTimeVisibility();
  }

  if (data.action === 'showInfo') {
    attendance = data.attendance || {};
    applyPublicUiConfig(data.publicUi || {});
    openPanel('info');
    renderEventInfo(data.events || data.event);
  }

  if (data.action === 'updateAttendance' && currentView === 'info') {
    attendance = data.attendance || {};
    renderEventInfo(activeEvents);
  }

  if (data.action === 'activeEventStarted' && currentView === 'info') {
    renderEventInfo([...activeEvents.filter((entry) => Number(entry.id) !== Number(data.event.id)), data.event]);
  }

  if (data.action === 'activeEventRemoved' && currentView === 'info') {
    renderEventInfo(activeEvents.filter((entry) => Number(entry.id) !== Number(data.id)));
  }

  if (data.action === 'showClaims') {
    claimsPickupKind = null;
    fixedClaimNpc = null;
    applyPublicUiConfig(data.publicUi || {});
    openPanel('claims');
    setClaims(data);
  }

  if (data.action === 'refreshClaims') refreshClaims();
});

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (npcPlacementActive) return;
  if (!getElement('confirm-dialog').hidden) {
    closeConfirmation();
    return;
  }
  closePanel();
});
>>>>>>> e0632c7a61e4d7d804debcb67e0c49d9ead74b61
