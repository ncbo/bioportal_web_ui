import { Application } from '/node_modules/@hotwired/stimulus/dist/stimulus.js';

const identifier = 'submissions-toggle';
const root = document.getElementById('fixtures');
let application;

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function source(path) {
  const response = await fetch(path, { cache: 'no-store' });
  assert(response.ok, 'Cannot load ' + path);
  return response.text();
}

async function until(predicate, message) {
  const deadline = Date.now() + 3000;
  while (!predicate()) {
    assert(Date.now() < deadline, message);
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
}

function controller(table) {
  return application.getControllerForElementAndIdentifier(table, identifier);
}

async function mount(limit, count = limit + 2, expanded = false) {
  const table = document.createElement('table');
  // Deliberately share the legacy ID: controller targets must remain instance-scoped.
  table.id = 'ontology_versions';
  table.dataset.controller = identifier;
  table.innerHTML = `<tbody>
    ${Array.from(
      { length: count },
      (_, index) => `<tr
      ${index >= limit ? 'data-submissions-toggle-target="row"' : ''}
      class="${index >= limit && !expanded ? 'hidden_ont' : ''}"><td>Submission ${index}</td></tr>`,
    ).join('')}
    ${
      count > limit
        ? `<tr><td><a href="#unexpected-navigation" data-action="click->submissions-toggle#toggle"
      data-submissions-toggle-target="toggle" aria-expanded="false">more...</a></td></tr>`
        : ''
    }
    </tbody>`;
  root.appendChild(table);
  await until(() => controller(table), 'Controller did not connect after insertion');
  return table;
}

function toggle(table) {
  return table.querySelector('[data-submissions-toggle-target="toggle"]');
}

function click(table) {
  const event = new MouseEvent('click', { bubbles: true, cancelable: true });
  toggle(table).dispatchEvent(event);
  assert(event.defaultPrevented, 'Click must prevent the link default action');
}

function visible(row) {
  return getComputedStyle(row).display !== 'none';
}

function assertState(table, expanded) {
  const rows = [...table.querySelectorAll('[data-submissions-toggle-target="row"]')];
  assert(
    rows.every((row) => visible(row) === expanded),
    'Extra row visibility is incorrect',
  );
  assert(toggle(table).textContent === (expanded ? 'less...' : 'more...'), 'Label must match row visibility');
  assert(toggle(table).getAttribute('aria-expanded') === String(expanded), 'Accessible state must match visibility');
  assert(
    [...table.querySelectorAll('tr:not([data-submissions-toggle-target="row"])')].every(visible),
    'Initial submissions and toggle row must remain visible',
  );
}

async function repeatedClicks() {
  for (const limit of [5, 10]) {
    const table = await mount(limit);
    assertState(table, false);
    for (let i = 0; i < 6; i++) {
      click(table);
      assertState(table, i % 2 === 0);
    }
    // A stale label or externally changed visibility must not create click-history drift.
    table
      .querySelectorAll('[data-submissions-toggle-target="row"]')
      .forEach((row) => row.classList.remove('hidden_ont'));
    click(table);
    assertState(table, false);
    toggle(table).textContent = 'less...';
    click(table);
    assertState(table, true);
  }
}

async function independentTables() {
  const ontology = await mount(5);
  const admin = await mount(10);
  click(ontology);
  assertState(ontology, true);
  assertState(admin, false);
  click(admin);
  assertState(ontology, true);
  assertState(admin, true);
  click(ontology);
  assertState(ontology, false);
  assertState(admin, true);
}

async function reopenedDialog() {
  const oldTable = await mount(10);
  click(oldTable);
  assertState(oldTable, true);
  oldTable.remove();
  await until(() => !controller(oldTable), 'Removed dialog controller did not disconnect');
  const newTable = await mount(10);
  assertState(newTable, false);
  click(newTable);
  assertState(newTable, true);
  click(newTable);
  assertState(newTable, false);
}

async function reconnectedTable() {
  const table = await mount(5);
  click(table);
  table.remove();
  await until(() => !controller(table), 'Controller did not disconnect');
  root.appendChild(table);
  await until(() => controller(table), 'Controller did not reconnect');
  assertState(table, true);
  click(table);
  assertState(table, false);
}

async function initiallyExpanded() {
  const table = await mount(10, 12, true);
  assertState(table, true);
  click(table);
  assertState(table, false);
}

async function noExtraSubmissions() {
  for (const limit of [5, 10]) {
    for (const count of [0, limit - 1, limit]) {
      const table = await mount(limit, count);
      assert(!toggle(table), 'No toggle is needed at or below the initial limit');
      const rows = [...table.querySelectorAll('tr')];
      assert(rows.length === count && rows.every(visible), 'All available submissions must remain visible');
    }
  }
}

async function run() {
  const results = [];
  const errors = [];
  window.submissionsToggleTestResults = { done: false, results };
  const capture = (event) => errors.push(event.message || String(event.reason));
  window.addEventListener('error', capture);
  window.addEventListener('unhandledrejection', capture);
  let controllerURL;
  try {
    assert(typeof window.jQuery === 'undefined', 'Run without jQuery or Migrate');
    const stylesheet = await source('/app/assets/stylesheets/bioportal.scss');
    const hiddenRule = stylesheet.match(/\.hidden_ont\s*\{[^}]*\}/);
    assert(hiddenRule, 'Hidden-row CSS must exist');
    const style = document.createElement('style');
    style.textContent = hiddenRule[0];
    document.head.appendChild(style);
    // Import the production controller using the locally installed Stimulus module.
    const code = await source('/app/javascript/controllers/submissions_toggle_controller.js');
    const stimulusURL = location.origin + '/node_modules/@hotwired/stimulus/dist/stimulus.js';
    controllerURL = URL.createObjectURL(
      new Blob([code.replace("'@hotwired/stimulus'", JSON.stringify(stimulusURL))], { type: 'text/javascript' }),
    );
    const { default: SubmissionsToggle } = await import(controllerURL);
    application = Application.start(root);
    application.handleError = (error) => errors.push(error.message);
    application.register(identifier, SubmissionsToggle);
    for (const test of [
      repeatedClicks,
      independentTables,
      reopenedDialog,
      reconnectedTable,
      initiallyExpanded,
      noExtraSubmissions,
    ]) {
      const item = document.createElement('li');
      document.querySelector('#results').appendChild(item);
      errors.length = 0;
      try {
        await test();
        assert(errors.length === 0, errors.join('; '));
        results.push({ label: test.name, passed: true });
        item.textContent = test.name + ': PASS';
      } catch (error) {
        results.push({ label: test.name, passed: false, error: error.message, errors: [...errors] });
        item.textContent = test.name + ': FAIL — ' + error.message;
      } finally {
        root.replaceChildren();
      }
    }
  } catch (error) {
    results.push({ label: 'Test setup', passed: false, error: error.message });
  } finally {
    application?.stop();
    if (controllerURL) URL.revokeObjectURL(controllerURL);
    window.removeEventListener('error', capture);
    window.removeEventListener('unhandledrejection', capture);
  }
  const passed = results.filter((result) => result.passed).length;
  document.querySelector('#status').textContent = `${passed}/${results.length} cases passed`;
  window.submissionsToggleTestResults.done = true;
}

run();
