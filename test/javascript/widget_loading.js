const server = location.origin + '/public';
const pluginURL = server + '/javascripts/JqueryPlugins/autocomplete/crossdomain_autocomplete.js';
const both = ['quick_jump', 'form_complete'];
const cases = [
  { label: 'Jump To without host jQuery', widgets: ['quick_jump'] },
  { label: 'Form Autocomplete without host jQuery', widgets: ['form_complete'] },
  { label: 'Concurrent widgets without host jQuery', widgets: both },
  { label: 'Concurrent widgets in reverse order', widgets: [...both].reverse() },
  ...['1.8.3', '1.11.2', '2.2.4', '3.7.1'].map((version) => ({
    label: 'Host jQuery ' + version,
    version,
    widgets: both,
  })),
  { label: 'Host Migrate 1.2.1 is preserved', version: '2.2.4', migrate: '1.2.1', widgets: both },
  { label: 'Host Migrate 1.3.0 is preserved', version: '2.2.4', migrate: '1.3.0', widgets: both },
  {
    label: 'Existing autocomplete and definition loading',
    version: '3.7.1',
    plugin: true,
    definitions: true,
    widgets: both,
  },
  { label: 'Retry failed jQuery download', fail: 'jquery-1.11.2.min.js', widgets: both },
  { label: 'Retry failed autocomplete download', version: '2.2.4', fail: 'crossdomain_autocomplete.js', widgets: both },
];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function until(condition, message, errors = []) {
  const deadline = Date.now() + 15000;
  while (!condition()) {
    assert(errors.length === 0, errors.join('; '));
    assert(Date.now() < deadline, message);
    await new Promise((resolve) => setTimeout(resolve, 10));
  }
  assert(errors.length === 0, errors.join('; '));
}

function script(win, src) {
  return new Promise((resolve, reject) => {
    const element = win.document.createElement('script');
    const timer = setTimeout(() => reject(new Error('Timed out loading ' + src)), 15000);
    element.src = src;
    element.onload = () => {
      clearTimeout(timer);
      resolve();
    };
    element.onerror = () => {
      clearTimeout(timer);
      reject(new Error('Cannot load ' + src));
    };
    win.document.head.appendChild(element);
  });
}

function fixtures(win, scenario) {
  win.document.body.innerHTML = `
    ${scenario.widgets.includes('quick_jump') ? '<div id="bp_quick_jump"></div>' : ''}
    ${
      scenario.widgets.includes('form_complete')
        ? ['uri', 'shortid', 'name']
            .map(
              (kind) =>
                `<input id="${kind}" name="${kind}" class="bp_form_complete-TEST-${kind}"
        ${scenario.definitions ? 'data-bp_include_definitions="true"' : ''}>`,
            )
            .join('')
        : ''
    }`;
}

function inputs(win) {
  return [...win.document.querySelectorAll('#BP_search_box, input[class*="bp_form_complete"]')];
}

async function exercise(win, scenario, errors, expectedRequests) {
  const $ = win.jQuery;
  const requests = [];
  let selections = 0;
  let definitions = 0;
  $.getJSON = (url, callback) => {
    if (url.includes('/ajax/json_class')) {
      definitions++;
      win.setTimeout(() => callback({ definition: ['Fixture definition'] }), 0);
    } else {
      requests.push(url);
      win.setTimeout(() => callback({ data: 'Alpha|A|class|TEST|urn:alpha|Alpha|Alpha|Test ontology' }), 0);
    }
  };
  $(win.document).on('autocomplete_selected.widgetTest', () => selections++);
  for (const input of inputs(win)) {
    const before = requests.length;
    const selectedBefore = selections;
    input.focus();
    input.value = 'Alp';
    input.dispatchEvent(new win.KeyboardEvent('keydown', { bubbles: true, keyCode: 80, which: 80 }));
    await until(() => $('.ac_results li:visible').length === 1, 'Widget suggestions did not appear', errors);
    if (scenario.definitions) await until(() => definitions > 0, 'Definitions must load while the host owns $', errors);
    input.dispatchEvent(new win.KeyboardEvent('keydown', { bubbles: true, cancelable: true, keyCode: 40, which: 40 }));
    input.dispatchEvent(new win.KeyboardEvent('keydown', { bubbles: true, cancelable: true, keyCode: 13, which: 13 }));
    await until(() => selections > selectedBefore, 'Widget did not select the suggestion', errors);
    assert(selections === selectedBefore + 1, 'Selection must fire exactly once');
    assert(requests.length === before + 1, 'Typing must issue exactly one search');
    if (input.id === 'BP_search_box') {
      assert(
        $('#jump_to_concept_id').val() === 'A' && $('#jump_to_ontology_id').val() === 'TEST',
        'Jump To must retain navigation metadata',
      );
    } else {
      const expected = { uri: 'urn:alpha', shortid: 'A', name: 'Alpha' };
      assert(input.value === expected[input.id], 'Form autocomplete must return the requested value');
      assert(
        $('#' + input.name + '_bioportal_full_id').val() === 'urn:alpha',
        'Form autocomplete must retain hidden URI metadata',
      );
      assert(
        $('#' + input.name + '_bioportal_ontology_id').val() === 'TEST',
        'Form autocomplete must retain hidden ontology metadata',
      );
    }
  }
  if (scenario.definitions)
    await until(() => definitions > 0, 'Definitions must load using jQuery while the host owns $', errors);
  assert(requests.length === expectedRequests, 'Unexpected number of widget search requests');
  $(win.document).off('.widgetTest');
}

async function check(win, scenario, errors) {
  if (scenario.version) await script(win, 'https://code.jquery.com/jquery-' + scenario.version + '.js');
  if (scenario.migrate) await script(win, 'https://code.jquery.com/jquery-migrate-' + scenario.migrate + '.js');
  if (scenario.plugin) {
    await script(win, pluginURL);
    await until(
      () => typeof win.jQuery.fn.bioportal_autocomplete === 'function',
      'Host autocomplete not ready',
      errors,
    );
  }
  const hostJQuery = win.jQuery;
  const hostInit = hostJQuery?.fn.init;
  const hostWarnings = hostJQuery?.migrateWarnings;
  const hostDollar = { hostLibrary: true };
  win.$ = hostDollar;
  win.BP_SEARCH_SERVER = server;
  win.BP_ontology_id = 'TEST';
  win.BP_include_definitions = Boolean(scenario.definitions);
  fixtures(win, scenario);

  const downloads = [];
  const append = win.document.head.appendChild;
  let failed = false;
  const reported = [];
  win.console.error = (error) => reported.push(String(error));
  win.document.head.appendChild = function (element) {
    if (element.tagName === 'SCRIPT') {
      downloads.push(element.src);
      if (scenario.fail && !failed && element.src.endsWith(scenario.fail)) {
        failed = true;
        win.setTimeout(() => element.dispatchEvent(new win.Event('error')), 0);
        return element;
      }
    }
    return append.call(this, element);
  };
  const loadWidgets = () =>
    Promise.all(scenario.widgets.map((widget) => script(win, server + '/javascripts/widgets/' + widget + '.js')));
  const expected = scenario.widgets.includes('quick_jump')
    ? 1 + (scenario.widgets.includes('form_complete') ? 3 : 0)
    : 3;
  const initialized = () => inputs(win).length === expected && inputs(win).every((input) => input.autocompleter);
  await loadWidgets();
  if (scenario.fail) {
    await until(
      () => reported.length === scenario.widgets.length,
      'Each widget must report dependency failure',
      errors,
    );
    assert(!initialized(), 'A failed dependency must not initialize widgets');
    reported.length = 0;
    await loadWidgets();
  }
  await until(initialized, 'Widgets did not initialize', errors);
  assert(reported.length === 0, reported.join('; '));
  assert(win.$ === hostDollar, 'The host must retain ownership of $');
  assert(win.jQuery.fn.jquery === (scenario.version || '1.11.2'), 'Unexpected jQuery version');
  if (hostJQuery)
    assert(win.jQuery === hostJQuery && win.jQuery.fn.init === hostInit, 'Host jQuery must not be replaced or patched');
  assert(win.jQuery.migrateWarnings === hostWarnings, 'Host Migrate state must remain unchanged');
  assert(!downloads.some((url) => url.includes('jquery-migrate')), 'Widgets must not request Migrate');
  const count = (suffix) => downloads.filter((url) => url.endsWith(suffix)).length;
  assert(count('dependencies.js') === 1, 'Widgets must share the dependency helper');
  assert(
    count('jquery-1.11.2.min.js') === (hostJQuery ? 0 : scenario.fail === 'jquery-1.11.2.min.js' ? 2 : 1),
    'Widgets must share the fallback jQuery download',
  );
  assert(
    count('crossdomain_autocomplete.js') ===
      (scenario.plugin ? 0 : scenario.fail === 'crossdomain_autocomplete.js' ? 2 : 1),
    'Widgets must share or reuse autocomplete',
  );
  assert(
    win.document.querySelectorAll('link[href$="jquery.autocomplete.css"]').length === 1,
    'Stylesheet must be inserted once',
  );

  // Reload entry points in the same DOM; do not duplicate controls or event handlers.
  const originalInputs = inputs(win);
  const originalCompleters = originalInputs.map((input) => input.autocompleter);
  await loadWidgets();
  await win.BioPortalWidgetLoader;
  await new Promise((resolve) => setTimeout(resolve, 30));
  assert(
    inputs(win).length === expected &&
      inputs(win).every(
        (input, index) => input === originalInputs[index] && input.autocompleter === originalCompleters[index],
      ),
    'Repeated entry points must reuse initialized controls',
  );
  await exercise(win, scenario, errors, expected);

  // Reopening the tab replaces its DOM but should reuse all downloaded dependencies.
  const dependencyCount = downloads.filter(
    (url) => !scenario.widgets.some((widget) => url.endsWith(widget + '.js')),
  ).length;
  fixtures(win, scenario);
  await loadWidgets();
  await until(initialized, 'Replacement widget DOM did not initialize', errors);
  assert(
    downloads.filter((url) => !scenario.widgets.some((widget) => url.endsWith(widget + '.js'))).length ===
      dependencyCount,
    'Reopening widgets must not download dependencies again',
  );
  assert(win.$ === hostDollar, 'Reopening widgets must preserve host $');
  assert(!downloads.some((url) => url.includes('jquery-migrate')), 'Reopening widgets must not request Migrate');
}

async function run() {
  const results = [];
  window.widgetLoadingTestResults = { done: false, results };
  const filter = new URLSearchParams(location.search).get('case');
  for (const scenario of cases.filter((item) => !filter || item.label === filter)) {
    const item = document.createElement('li');
    item.textContent = scenario.label + ': running';
    document.querySelector('#results').appendChild(item);
    const frame = document.createElement('iframe');
    frame.title = scenario.label;
    const loaded = new Promise((resolve) => {
      frame.onload = resolve;
    });
    frame.src = './widget_loading.html?fixture=1';
    document.body.appendChild(frame);
    await loaded;
    const win = frame.contentWindow;
    win.document.body.innerHTML = '';
    const errors = [];
    win.addEventListener('error', (event) => errors.push(event.message));
    win.addEventListener('unhandledrejection', (event) => errors.push(String(event.reason)));
    try {
      await check(win, scenario, errors);
      results.push({ label: scenario.label, passed: true });
      item.textContent = scenario.label + ': PASS';
    } catch (error) {
      results.push({ label: scenario.label, passed: false, error: error.message, errors });
      item.textContent = scenario.label + ': FAIL — ' + error.message;
    } finally {
      frame.remove();
    }
  }
  document.querySelector('#status').textContent =
    results.filter((result) => result.passed).length + '/' + results.length + ' cases passed';
  window.widgetLoadingTestResults.done = true;
}

if (!new URLSearchParams(location.search).has('fixture')) run();
