const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const root = path.resolve(__dirname, '..');
const html = fs.readFileSync(path.join(root, 'nui/ui.html'), 'utf8');
const script = fs.readFileSync(path.join(root, 'nui/app.js'), 'utf8');

function harness() {
  const nodes = new Map();
  const nodeHandlers = new Map();
  const documentHandlers = {};
  for (const [, id] of html.matchAll(/\bid="([^"]+)"/g)) {
    nodes.set(id, {
      id, value: '', textContent: '', innerHTML: '', hidden: true, checked: false,
      disabled: false, dataset: {}, classList: { toggle() {} },
      style: { setProperty() {} }, addEventListener(event, fn) { nodeHandlers.set(`${id}:${event}`, fn); }, reset() {},
      setSelectionRange(start, end) { this.selectionStart = start; this.selectionEnd = end; },
    });
  }
  const handlers = {};
  const intervals = [];
  const calls = [];
  const replies = [];
  let now = 1800000000000;
  class Clock extends Date { static now() { return now; } }
  const context = vm.createContext({
    Date: Clock, console,
    document: {
      getElementById: (id) => nodes.get(id) || null,
      querySelectorAll: () => [], addEventListener(event, fn) { documentHandlers[event] = fn; },
      body: { classList: { toggle() {} } },
    },
    window: {
      addEventListener: (event, fn) => { handlers[event] = fn; },
      setTimeout: () => 0, clearTimeout() {}, setInterval: (fn) => intervals.push(fn),
    },
    fetch: async (url, options) => {
      calls.push({ name: url.split('/').pop(), body: JSON.parse(options.body) });
      const result = replies.length ? await replies.shift() : { ok: true, claims: [], server_time: Math.floor(now / 1000) };
      return { json: async () => result };
    },
  });
  nodes.get('event-type').value = 'encontro';
  nodes.get('status').value = 'active';
  vm.runInContext(script, context, { filename: 'app.js' });
  return {
    context, nodes, calls, replies, intervals,
    message: (data) => handlers.message({ data }),
    input: (id, value, caret = value.length) => {
      const target = nodes.get(id);
      target.value = value;
      target.selectionStart = caret;
      target.selectionEnd = caret;
      nodeHandlers.get(`${id}:input`)?.({ target });
    },
    keydown: (key) => documentHandlers.keydown({ key }),
    advance: (seconds) => { now += seconds * 1000; },
    now: () => Math.floor(now / 1000),
  };
}

const tables = {
  pecas_carro: { label: 'Peças de carro', enabled: true },
  pecas_moto: { label: 'Peças de moto', enabled: true },
  pecas_caminhao: { label: 'Peças de caminhão', enabled: false },
  encontro: { label: 'Premiação antiga' },
};
const active = {
  id: 12, title: 'Encontro de testes', event_type: 'encontro', coords: { x: 1, y: 2, z: 3 },
  reward_enabled: 1, start_time: 1800000000, duration: 60, radius: 80,
};

test('form exposes only two fixed categories and a disabled truck option', () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables });
  const options = h.nodes.get('reward-table').innerHTML;
  assert.match(options, /value="pecas_carro"/);
  assert.match(options, /value="pecas_moto"/);
  assert.match(options, /value="pecas_caminhao" disabled/);
  assert.doesNotMatch(options, /Premiação antiga|value="encontro"/);
  assert.doesNotMatch(html, /id="(?:reward-mode|npc-coords|custom-rewards-panel)"/);
  h.nodes.get('reward-enabled').checked = true;
  h.nodes.get('event-type').value = 'marcador';
  h.context.applyEventTypeDefaults();
  assert.equal(h.nodes.get('reward-enabled').checked, false);
  assert.equal(h.nodes.get('reward-enabled').disabled, true);
  assert.equal(h.nodes.get('reward-table').disabled, true);
});

test('reward payload reserves a confirmed NPC and exposes no item, quantity, kit or model fields', () => {
  const h = harness();
  h.nodes.get('coords').value = '1, 2, 3';
  h.nodes.get('reward-table').value = 'pecas_moto';
  h.nodes.get('reward-enabled').checked = true;
  const data = JSON.parse(JSON.stringify(h.context.getEventFormData()));
  assert.equal(data.reward_mode, 'table');
  assert.equal(data.reward_table, 'pecas_moto');
  assert.equal(data.reward_enabled, true);
  assert.equal(data.npc_coords, null, 'an unpositioned NPC cannot silently inherit another point');
  for (const key of ['npc_model', 'reward_item', 'reward_custom', 'amount', 'reward_amount']) {
    assert.equal(key in data, false, key);
  }
});

test('vector3 form accepts a pasted vector without including the type digit in coordinates', () => {
  const h = harness();
  assert.equal(JSON.stringify(h.context.parseVector3('vector3(1702.51, 4916.65, 42.08)')), JSON.stringify({ x: 1702.51, y: 4916.65, z: 42.08 }));
  assert.equal(h.context.parseVector3('text 1, 2, 3'), null);
  assert.equal(h.context.parseVector3('1, 2, 3, 4'), null);
});

test('public event shows only name, date, time and location while preserving the map action', () => {
  const h = harness();
  h.message({ action: 'showInfo', events: [{ ...active, title: '<b>Encontro</b>', location: '<img src=x onerror=bad()>', description: 'Descrição que não aparece' }] });
  const initial = h.nodes.get('public-events-list').innerHTML;
  h.message({ action: 'updateAttendance', attendance: { 12: { seconds: 600, current_required_seconds: 600, planned_required_seconds: 1800, inside: true } } });
  const content = h.nodes.get('public-events-list').innerHTML;
  assert.equal(content, initial, 'attendance updates do not add participant details to the public card');
  assert.match(content, /&lt;b&gt;Encontro&lt;\/b&gt;/);
  assert.match(content, /Local: &lt;img src=x onerror=bad\(\)&gt;/);
  assert.match(content, /Data: /);
  assert.match(content, /Horário: /);
  assert.match(content, /class="public-event-location"/);
  assert.match(content, /Marcar no mapa/);
  assert.match(content, /markEventOnMap\(1, 2, 3\)/);
  assert.doesNotMatch(content, /Descrição que não aparece|public-type|public-chip|attendance-panel|Sua presença|Consultando sua presença|Tempo acumulado|Mínimo|Você está|peça sorteada|Área de|fa-bullseye/);
  h.message({ action: 'updateAttendance', attendance: { 12: { seconds: 600, current_required_seconds: 650, planned_required_seconds: 1800, inside: false } } });
  assert.equal(h.nodes.get('public-events-list').innerHTML, initial);
  h.message({ action: 'activeEventRemoved', id: 12 });
  assert.match(h.nodes.get('public-events-list').innerHTML, /Nenhum encontro ativo/);
});

test('public schedule uses actual start and server deadline, including the next day date', () => {
  const h = harness();
  const scheduled = new Date(2026, 9, 8, 23, 40).getTime() / 1000;
  const info = h.context.publicEventSchedule({ start_time: scheduled, started_at: scheduled + 600, duration: 60 });
  assert.equal(info.date, '08/10/2026');
  assert.equal(info.hours, '23:50 – 00:40 (09/10/2026)');
  const sameDay = h.context.publicEventSchedule({ start_time: new Date(2026, 9, 8, 10, 0).getTime() / 1000, duration: 60 });
  assert.equal(sameDay.hours, '10:00 – 11:00');
});

test('public schedule falls back to scheduled start and never renders invalid dates', () => {
  const h = harness();
  const scheduled = new Date(2026, 9, 8, 10, 0).getTime() / 1000;
  for (const invalid of [undefined, null, 0, -1, 'broken', Infinity, 1e20]) {
    const fallback = h.context.publicEventSchedule({ start_time: scheduled, started_at: invalid, duration: 60 });
    assert.equal(fallback.date, '08/10/2026');
    assert.equal(fallback.hours, '10:00 – 11:00');
    const unavailable = h.context.publicEventSchedule({ start_time: invalid, started_at: invalid, duration: 60 });
    assert.equal(unavailable.date, '—');
    assert.equal(unavailable.hours, '— – —');
  }
  const missingDuration = h.context.publicEventSchedule({ start_time: scheduled, duration: 'broken' });
  assert.equal(missingDuration.hours, '10:00 – —');
});

test('claims sort by expiry and escape labels/reasons, use only local inventory images', () => {
  const h = harness();
  h.message({ action: 'showClaims', server_time: h.now(), claims: [
    { id: 2, event_title: 'Later', label: '<script>bad</script>', item: 'jv_piston_forjado', image: 'https://other.invalid/x.png', expires_at: h.now() + 90, status: 'pending' },
    { id: 1, event_title: 'First', label: 'Pistão', item: 'jv_piston_forjado', image: 'jv_piston_forjado.png', amount: 1, expires_at: h.now() + 30, status: 'pending' },
    { id: 3, event_title: 'Old', status: 'suspended', reason: '<b>Blocked</b>' },
  ] });
  const content = h.nodes.get('claims-list').innerHTML;
  assert.ok(content.indexOf('First') < content.indexOf('Later'));
  assert.match(content, /&lt;script&gt;bad&lt;\/script&gt;/);
  assert.match(content, /&lt;b&gt;Blocked&lt;\/b&gt;/);
  assert.doesNotMatch(content, /https:\/\/other.invalid/);
  assert.match(content, /https:\/\/cfx-nui-qb-inventory\/html\/images\/jv_piston_forjado.png/);
  assert.match(content, /1 unidade/);
  assert.match(content, /Prêmio suspenso/);
});

test('pickup instructions distinguish the ten-minute local window from the fixed NPC without changing claim expiry', async () => {
  const h = harness();
  const point = { x: 1829.39, y: 3844.86, z: 36.75, w: 122.80 };
  const expiry = h.now() + 86400;
  const prize = { id: 1, label: 'Pistão', status: 'pending', expires_at: expiry };
  h.message({ action: 'showClaims', pickup_kind: 'event', fixed_npc_coords: point, claims: [prize], server_time: h.now() });
  assert.match(h.nodes.get('claims-pickup-help').textContent, /10 minutos após o término/);
  assert.equal(h.nodes.get('claims-fixed-map').hidden, false);
  h.context.markFixedClaimNpc();
  assert.deepEqual(h.calls.at(-1), { name: 'markOnMap', body: { x: point.x, y: point.y, z: point.z } });
  h.advance(600);
  h.message({ action: 'showClaims', pickup_kind: 'fixed', fixed_npc_coords: point, claims: [prize], server_time: h.now() });
  assert.match(h.nodes.get('claims-pickup-help').textContent, /neste NPC fixo em até 24 horas após o sorteio/);
  assert.equal(h.nodes.get('claims-fixed-map').hidden, true);
  assert.match(h.nodes.get('claims-list').innerHTML, new RegExp(`data-expires="${expiry}"`));
  h.message({ action: 'showClaims', pickup_kind: 'event', fixed_npc_coords: { x: '1829.39', y: 0, z: 0 }, claims: [] });
  assert.equal(h.nodes.get('claims-fixed-map').hidden, true, 'invalid route cannot reuse the previous NPC point');
  h.message({ action: 'showClaims', pickup_kind: 'fixed', claims: [] });
  assert.match(h.nodes.get('claims-list').innerHTML, /10 minutos após o término/);
});

test('expiry disables claiming at the exact deadline using the server clock', async () => {
  const h = harness();
  h.message({ action: 'showClaims', server_time: h.now() + 3600, claims: [
    { id: 1, label: 'Pistão', expires_at: h.now() + 3601, status: 'pending' },
  ] });
  assert.match(h.nodes.get('claims-list').innerHTML, /Reivindicar peça/);
  h.advance(1);
  h.intervals.forEach((fn) => fn());
  assert.match(h.nodes.get('claims-list').innerHTML, /Prazo expirado/);
  await h.context.claimReward(1);
  assert.equal(h.calls.length, 0);
});

test('one click in flight per claim and only claim ID is sent; response refreshes status', async () => {
  const h = harness();
  h.message({ action: 'showClaims', server_time: h.now(), claims: [
    { id: 7, label: 'Pistão', expires_at: h.now() + 30, status: 'pending' },
  ] });
  let resolve;
  h.replies.push(new Promise((done) => { resolve = done; }));
  h.replies.push({ ok: true, server_time: h.now(), claims: [{ id: 7, label: 'Pistão', status: 'claimed', expires_at: h.now() + 30 }] });
  const first = h.context.claimReward(7);
  await h.context.claimReward(7);
  assert.deepEqual(h.calls, [{ name: 'claimReward', body: { id: 7 } }]);
  assert.match(h.nodes.get('claims-list').innerHTML, /Resgatando…/);
  resolve({ ok: true, message: 'Entregue' });
  await first;
  assert.equal(h.calls[1].name, 'refreshClaims');
  assert.match(h.nodes.get('claims-list').innerHTML, /Peça recebida/);
  await h.context.claimReward(7);
  assert.equal(h.calls.length, 2);
});

test('failed delivery preserves the same pending item and surfaces the server reason', async () => {
  const h = harness();
  const claim = { id: 7, label: 'Biela H-Beam', item: 'jv_connectingrod_hbeam', expires_at: h.now() + 30, status: 'pending' };
  h.message({ action: 'showClaims', server_time: h.now(), claims: [claim] });
  h.replies.push({ ok: false, reason: 'Inventário cheio' });
  h.replies.push({ ok: true, claims: [claim], server_time: h.now() });
  await h.context.claimReward(7);
  assert.match(h.nodes.get('claims-list').innerHTML, /Biela H-Beam/);
  assert.match(h.nodes.get('claims-list').innerHTML, /Reivindicar peça/);
  assert.equal(h.nodes.get('nui-toast-message').textContent, 'Inventário cheio');
});

test('recreation preserves description/area but invalid old category needs a fresh choice', () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables, events: [{ ...active, status: 'cancelled', status_reason: 'Política antiga', reward_table: 'pecas_caminhao', description: 'Histórico' }] });
  assert.match(h.nodes.get('events-list').innerHTML, /Recriar/);
  assert.match(h.nodes.get('events-list').innerHTML, /Política antiga/);
  assert.doesNotMatch(h.nodes.get('events-list').innerHTML, /deleteEvent/);
  h.context.recreateEvent(12);
  assert.equal(h.nodes.get('description').value, 'Histórico');
  assert.equal(h.nodes.get('reward-table').value, '');
  assert.equal(h.nodes.get('status').value, 'active');
  assert.equal(h.nodes.get('coords').value, '1.00, 2.00, 3.00');
  assert.equal('id' in h.context.getEventFormData(), false);
});

test('closed panel does not refresh claim data', async () => {
  const h = harness();
  h.message({ action: 'showClaims', claims: [], server_time: h.now() });
  h.context.closePanel();
  await h.context.refreshClaims();
  assert.equal(h.calls.length, 1);
  assert.equal(h.calls[0].name, 'closePanel');
});

test('blocked events can be recreated but cannot be cancelled again', () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables, events: [{ ...active, status: 'blocked', status_reason: 'Categoria bloqueada' }] });
  const content = h.nodes.get('events-list').innerHTML;
  assert.match(content, /Recriar/);
  assert.doesNotMatch(content, /deleteEvent|Cancelar encontro/);
});

test('start notice is independent of panels and renders untrusted titles as text', () => {
  const h = harness();
  h.message({ action: 'showStartNotice', notice: {
    id: '12:1800000000', title: '<img src=x onerror=bad()>', location: '<b>Pier</b>', durationMs: 10000, remainingMs: 10000, marked: false,
  } });
  assert.equal(h.nodes.get('panel').hidden, true);
  assert.equal(h.nodes.get('start-notice').hidden, false);
  assert.equal(h.nodes.get('start-notice-title').textContent, '<img src=x onerror=bad()>');
  assert.equal(h.nodes.get('start-notice-title').innerHTML, '');
  assert.equal(h.nodes.get('start-notice-location').textContent, '<b>Pier</b>');
  assert.equal(h.nodes.get('start-notice-progress-bar').style.transform, 'scaleX(1)');
  h.message({ action: 'showInfo', events: [active] });
  h.context.closePanel();
  assert.equal(h.nodes.get('start-notice').hidden, false);
  assert.equal(h.nodes.get('start-notice-key').hidden, false);
});

test('notice progress and marked state follow Lua without a browser expiry timer', () => {
  const h = harness();
  h.message({ action: 'showStartNotice', notice: { id: '12:1800000000', durationMs: 10000, remainingMs: 10000 } });
  h.advance(12);
  h.intervals.forEach((fn) => fn());
  assert.equal(h.nodes.get('start-notice').hidden, false, 'only Lua hides an expired notice');
  h.message({ action: 'updateStartNotice', notice: { id: '12:1800000000', remainingMs: 2500, marked: true } });
  assert.equal(h.nodes.get('start-notice-progress-bar').style.transform, 'scaleX(0.25)');
  assert.equal(h.nodes.get('start-notice-action-text').textContent, 'Local marcado no mapa');
  assert.equal(h.nodes.get('start-notice-key').hidden, true);
  assert.equal(h.nodes.get('start-notice').hidden, false);
  h.message({ action: 'hideStartNotice', id: '12:1800000000' });
  assert.equal(h.nodes.get('start-notice').hidden, true);
});

test('stale notice messages cannot alter or hide the next activation', () => {
  const h = harness();
  h.message({ action: 'showStartNotice', notice: { id: '12:1800000000', title: 'First', remainingMs: 10000 } });
  h.message({ action: 'showStartNotice', notice: { id: '12:1800000600', title: 'Next', remainingMs: 10000 } });
  h.message({ action: 'updateStartNotice', notice: { id: '12:1800000000', remainingMs: 0, marked: true } });
  h.message({ action: 'hideStartNotice', id: '12:1800000000' });
  assert.equal(h.nodes.get('start-notice').hidden, false);
  assert.equal(h.nodes.get('start-notice-title').textContent, 'Next');
  assert.equal(h.nodes.get('start-notice-progress-bar').style.transform, 'scaleX(1)');
  assert.equal(h.nodes.get('start-notice-key').hidden, false);
  h.message({ action: 'hideStartNotice' });
  h.message({ action: 'showStartNotice', notice: { id: 'invalid' } });
  assert.equal(h.nodes.get('start-notice').hidden, true);
});

test('schedule uses explicit Brazilian dates and 24-hour time with exact calendar validation', () => {
  const h = harness();
  assert.doesNotMatch(html, /datetime-local|id="scheduled-time"/);
  assert.match(html, /Horário local do seu computador/);
  for (const [date, hour] of [
    ['31/02/2032', '12:00'], ['29/02/2031', '12:00'], ['31/04/2032', '12:00'],
    ['10/13/2032', '12:00'], ['00/01/2032', '12:00'], ['10/10/2032', '24:00'],
    ['10/10/2032', '12:60'], ['10/10/32', '12:00'], ['10/10/2032', '1:00'],
    ['2032-10-10', '12:00'], ['10/10/2032garbage', '12:00'],
  ]) assert.equal(h.context.parseScheduledDate(date, hour), null, `${date} ${hour}`);
  const leap = h.context.parseScheduledDate('29/02/2032', '23:59');
  assert.equal(leap.getDate(), 29);
  assert.equal(leap.getMonth(), 1);
  assert.equal(leap.getHours(), 23);
  assert.equal(leap.getMinutes(), 59);
  h.nodes.get('status').value = 'scheduled';
  h.context.updateScheduledTimeVisibility();
  const defaultTime = h.context.parseScheduledDate(h.nodes.get('scheduled-date').value, h.nodes.get('scheduled-hour').value);
  assert.ok(defaultTime.getTime() > h.now() * 1000 + 240000);
  assert.ok(defaultTime.getTime() <= h.now() * 1000 + 300000);
  for (const id of ['scheduled-date', 'scheduled-hour']) {
    assert.equal(h.nodes.get(id).required, true);
    assert.equal(h.nodes.get(id).disabled, false);
  }
  h.nodes.get('scheduled-date').value = '31/02/2032';
  h.nodes.get('status').value = 'active';
  h.context.updateScheduledTimeVisibility();
  assert.equal(h.nodes.get('scheduled-time-wrapper').hidden, true);
  for (const id of ['scheduled-date', 'scheduled-hour']) {
    assert.equal(h.nodes.get(id).required, false);
    assert.equal(h.nodes.get(id).disabled, true);
  }
  h.nodes.get('status').value = 'scheduled';
  h.context.updateScheduledTimeVisibility();
  assert.equal(h.nodes.get('scheduled-date').value, '31/02/2032', 'invalid input stays visible for correction instead of silently changing the booking');
});

test('schedule masks pasted digits and keeps the caret at the edited position', () => {
  const h = harness();
  h.input('scheduled-date', '29122032');
  assert.equal(h.nodes.get('scheduled-date').value, '29/12/2032');
  h.input('scheduled-hour', '2359');
  assert.equal(h.nodes.get('scheduled-hour').value, '23:59');
  h.input('scheduled-date', '29/12/2032');
  assert.equal(h.nodes.get('scheduled-date').value, '29/12/2032');
  h.input('scheduled-date', '2912/2032', 2);
  assert.equal(h.nodes.get('scheduled-date').value, '29/12/2032');
  assert.equal(h.nodes.get('scheduled-date').selectionStart, 2);
  h.input('scheduled-hour', '12');
  assert.equal(h.nodes.get('scheduled-hour').value, '12', 'partial editing does not force a trailing separator');
  h.input('scheduled-date', '');
  assert.equal(h.nodes.get('scheduled-date').value, '');
});

test('schedule rejects impossible and past dates and sends a future local time as unix epoch', async () => {
  const h = harness();
  h.nodes.get('coords').value = '1, 2, 3';
  h.nodes.get('status').value = 'scheduled';
  h.nodes.get('scheduled-date').value = '31/02/2032';
  h.nodes.get('scheduled-hour').value = '10:00';
  const submit = () => h.context.submitEventForm({ preventDefault() {} });
  await submit();
  assert.equal(h.calls.length, 0);
  assert.match(h.nodes.get('nui-toast-message').textContent, /data válida/);
  const past = new Date((h.now() - 60) * 1000);
  h.nodes.get('scheduled-date').value = h.context.formatScheduledDate(past);
  h.nodes.get('scheduled-hour').value = h.context.formatScheduledHour(past);
  await submit();
  assert.equal(h.calls.length, 0);
  assert.match(h.nodes.get('nui-toast-message').textContent, /futuros/);
  const future = new Date((h.now() + 600) * 1000);
  future.setSeconds(0, 0);
  h.nodes.get('scheduled-date').value = h.context.formatScheduledDate(future);
  h.nodes.get('scheduled-hour').value = h.context.formatScheduledHour(future);
  await submit();
  assert.equal(h.calls.length, 1);
  assert.equal(h.calls[0].body.start_time, future.getTime() / 1000);
  assert.equal('npc_coords' in h.calls[0].body, false, 'unrewarded events do not ask for a reward NPC');
});

test('placement preserves the form, ignores Escape in JS and only confirmation saves the reward point', async () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables });
  h.nodes.get('title').value = 'Rascunho do encontro';
  h.nodes.get('coords').value = '1, 2, 3';
  h.nodes.get('radius').value = '80';
  h.nodes.get('height-tolerance').value = '15';
  h.nodes.get('description').value = 'Texto que não pode sumir';
  h.nodes.get('reward-enabled').checked = true;
  h.context.updateRewardVisibility();
  assert.equal(h.nodes.get('reward-npc-wrapper').hidden, false);
  await h.context.placeRewardNpc();
  assert.deepEqual(h.calls[0], { name: 'placeRewardNpc', body: { coords: null, eventCoords: { x: 1, y: 2, z: 3 }, radius: 80, heightTolerance: 15 } });
  h.message({ action: 'showNpcPlacement', coords: { x: 1, y: 2, z: 3, w: 90 } });
  assert.equal(h.nodes.get('panel').hidden, true);
  assert.equal(h.nodes.get('npc-placement').hidden, false);
  h.keydown('Escape');
  assert.equal(h.calls.length, 1, 'Lua handles cancel and JS must not close the draft');
  h.message({ action: 'updateNpcPlacement', coords: { x: 3, y: 4, z: 5, w: 120 } });
  assert.match(h.nodes.get('npc-placement-coords').textContent, /3.00, 4.00, 5.00/);
  h.message({ action: 'finishNpcPlacement', confirmed: false });
  assert.equal(h.nodes.get('panel').hidden, false);
  assert.equal(h.nodes.get('create-tab').hidden, false);
  assert.equal(h.nodes.get('npc-placement').hidden, true);
  assert.equal(h.nodes.get('title').value, 'Rascunho do encontro');
  assert.equal(h.nodes.get('description').value, 'Texto que não pode sumir');
  assert.equal(h.context.getEventFormData().npc_coords, null);
  h.message({ action: 'showNpcPlacement', coords: { x: 1, y: 2, z: 3, w: 90 } });
  h.message({ action: 'finishNpcPlacement', confirmed: true, coords: { x: 4, y: 5, z: 6, w: 180 } });
  assert.match(h.nodes.get('reward-npc-summary').textContent, /4.00, 5.00, 6.00.*180.0°/);
  assert.deepEqual(JSON.parse(JSON.stringify(h.context.getEventFormData().npc_coords)), { x: 4, y: 5, z: 6, w: 180 });
  h.message({ action: 'showNpcPlacement', coords: { x: 9, y: 9, z: 9, w: 0 } });
  h.message({ action: 'finishNpcPlacement', confirmed: false, coords: { x: 9, y: 9, z: 9, w: 0 } });
  assert.equal(h.context.getEventFormData().npc_coords.x, 4, 'cancelling a new attempt preserves the last confirmed position');
});

test('rewarded creation requires a confirmed mechanic position while markers remain unawarded', async () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables });
  h.nodes.get('coords').value = '1, 2, 3';
  h.nodes.get('reward-enabled').checked = true;
  const submit = () => h.context.submitEventForm({ preventDefault() {} });
  await submit();
  assert.equal(h.calls.length, 0);
  assert.match(h.nodes.get('nui-toast-message').textContent, /Posicione e confirme o NPC mecânico/);
  h.message({ action: 'showNpcPlacement', coords: { x: 1, y: 2, z: 3, w: 0 } });
  h.message({ action: 'finishNpcPlacement', confirmed: true, coords: { x: 1, y: 2, z: 3, w: -90 } });
  await submit();
  assert.equal(h.calls[0].name, 'createEvent');
  assert.deepEqual(h.calls[0].body.npc_coords, { x: 1, y: 2, z: 3, w: 270 });
  assert.equal('npc_model' in h.calls[0].body, false);
  h.nodes.get('event-type').value = 'marcador';
  h.context.applyEventTypeDefaults();
  assert.equal(h.nodes.get('reward-npc-wrapper').hidden, true);
  await submit();
  assert.equal(h.calls[1].body.reward_enabled, false);
  assert.equal('npc_coords' in h.calls[1].body, false);
});

test('recreation uses saved NPC coordinates and never inherits the previous draft point', () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables, events: [
    { ...active, status: 'cancelled', reward_table: 'pecas_carro', npc_x: 10, npc_y: 20, npc_z: 30, npc_w: 45 },
    { ...active, id: 13, status: 'cancelled', reward_table: 'pecas_moto' },
  ] });
  h.context.recreateEvent(12);
  assert.deepEqual(JSON.parse(JSON.stringify(h.context.getEventFormData().npc_coords)), { x: 10, y: 20, z: 30, w: 45 });
  h.context.recreateEvent(13);
  assert.equal(h.context.getEventFormData().npc_coords, null);
  assert.equal(h.nodes.get('reward-npc-summary').textContent, 'Não posicionado');
});

test('placement failure preserves its confirmed point and logout hides the draft without a callback', () => {
  const h = harness();
  h.message({ action: 'showAdmin', rewardTables: tables });
  h.nodes.get('reward-enabled').checked = true;
  h.message({ action: 'showNpcPlacement', coords: { x: 1, y: 2, z: 3, w: 4 } });
  h.message({ action: 'finishNpcPlacement', confirmed: true, coords: { x: 1, y: 2, z: 3, w: 4 } });
  h.message({ action: 'showNpcPlacement', coords: { x: 8, y: 8, z: 8, w: 8 } });
  h.message({ action: 'finishNpcPlacement', confirmed: false, reason: 'Posicionamento interrompido.' });
  assert.equal(h.nodes.get('nui-toast-message').textContent, 'Posicionamento interrompido.');
  assert.equal(h.context.getEventFormData().npc_coords.x, 1);
  h.message({ action: 'hidePanel' });
  assert.equal(h.nodes.get('panel').hidden, true);
  assert.equal(h.nodes.get('npc-placement').hidden, true);
  assert.equal(h.calls.length, 0);
  assert.equal(h.context.getEventFormData().npc_coords, null, 'changing character cannot retain the previous reward point');
  assert.equal(h.nodes.get('reward-npc-summary').textContent, 'Não posicionado');
});
