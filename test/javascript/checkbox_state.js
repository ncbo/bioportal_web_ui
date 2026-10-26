function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function source(path) {
  const response = await fetch(path);
  assert(response.ok, 'Cannot load ' + path);
  return response.text();
}

function loadScript(doc, src) {
  return new Promise((resolve, reject) => {
    const script = doc.createElement('script');
    const timer = setTimeout(() => reject(new Error('Timed out loading ' + src)), 15000);
    script.src = src;
    script.onload = () => {
      clearTimeout(timer);
      resolve();
    };
    script.onerror = () => {
      clearTimeout(timer);
      reject(new Error('Cannot load ' + src));
    };
    doc.head.appendChild(script);
  });
}

function evaluateBeforeReady(win, code, runReady = true) {
  // Reproduce script evaluation followed by DOM ready, even in an already loaded iframe.
  const callbacks = [];
  const originalReady = win.jQuery.fn.ready;
  win.jQuery.fn.ready = function (callback) {
    callbacks.push(callback);
    return this;
  };
  try {
    win.eval(code);
  } finally {
    win.jQuery.fn.ready = originalReady;
  }
  if (runReady) callbacks.forEach((callback) => callback.call(win.document));
}

async function ontologyPicker(win) {
  const $ = win.jQuery;
  const names = { A: 'Alpha', B: 'Beta', C: 'Gamma' };
  win.document.body.innerHTML = `
    <select id="ontology_ontologyId" multiple>
      <option value="A" selected>Alpha</option><option value="B">Beta</option><option value="C">Gamma</option>
    </select>
    <button id="ont_select_clear">Clear selections</button>
    <div id="ont_select_adv">
      <input id="advanced_filter_input" type="text">
      <table id="group_list"><tr class="group_select_boxes_tr"><td>
        <input type="checkbox" id="group_G" value="G"><label for="group_G">Group</label>
      </td></tr></table>
      <table id="category_list"><tr class="category_select_boxes_tr"><td>
        <input type="checkbox" id="category_C" value="C"><label for="category_C">Category</label>
      </td></tr></table>
      <div id="groups_categories_names_container"><span id="groups_and_category_names"></span></div>
      <table id="ont_list">
        <tr id="select_all_filtered_row" style="display:none"><td>
          <input type="checkbox" id="ont_select_all_filtered"><a id="show_all_filtered_ontologies">Show all</a>
        </td></tr>
        ${Object.entries(names)
          .map(
            ([id, name]) => `<tr class="ont_select_boxes_tr"><td>
              <input type="checkbox" id="ont_select_adv_check${id}" value="${id}">${name}</td></tr>`,
          )
          .join('')}
      </table>
    </div>`;
  win.bp_popup_init = win.bp_popup_cleanup = () => {};
  const template = await source('/app/views/shared/_ontology_picker_advanced.html.erb');
  const script = template.match(/<script[^>]*>([\s\S]*?)<\/script>/);
  assert(script, 'Ontology picker script must exist');
  const values = {
    '@onts_for_js.html_safe': { Alpha: 'A', Beta: 'B', Gamma: 'C' },
    '@groups_for_js.html_safe': { G: ['A', 'B'] },
    '@categories_for_js.html_safe': { C: ['B', 'C'] },
    '@onts_in_gp_or_cat_for_js.html_safe': {},
    '(align_to_dom_id || @select_id).to_json.html_safe': 'ontology_ontologyId',
  };
  const code = script[1].replace(/<%=\s*([\s\S]*?)\s*%>/g, (_, expression) => {
    const key = expression.trim();
    if (key === '@select_id') return 'ontology_ontologyId';
    assert(Object.hasOwn(values, key), 'Unknown Rails fixture value: ' + key);
    return JSON.stringify(values[key]);
  });
  evaluateBeforeReady(win, code);

  const click = (id) => win.document.getElementById(id).click();
  const checked = (id) => win.document.getElementById(id).checked;
  const selected = () => ($('#ontology_ontologyId').val() || []).join(',');
  const filter = (value) => $('#advanced_filter_input').val(value).trigger('change');
  const visible = () =>
    $('.ont_select_boxes_tr input:visible')
      .map((_, element) => element.value)
      .get()
      .join(',');

  assert(
    checked('ont_select_adv_checkA') && !checked('ont_select_adv_checkB'),
    'Initial selection must reach checkboxes',
  );
  click('ont_select_adv_checkA');
  assert(selected() === '', 'Unchecking an ontology must clear the select list');
  click('ont_select_adv_checkA');
  assert(selected() === 'A', 'Rechecking an ontology must restore selection');
  $('#ontology_ontologyId').val(['B']).trigger('change');
  assert(
    !checked('ont_select_adv_checkA') && checked('ont_select_adv_checkB'),
    'Select list must update previously clicked checkboxes',
  );
  $('#ontology_ontologyId').val(['A']).trigger('change');
  assert(
    checked('ont_select_adv_checkA') && !checked('ont_select_adv_checkB'),
    'Select list synchronization must work repeatedly',
  );

  filter('Beta');
  assert(visible() === 'B', 'Text filter must expose only matching ontologies');
  click('ont_select_all_filtered');
  assert(selected() === 'A,B', 'Selecting filtered ontologies must preserve hidden selections');
  click('ont_select_all_filtered');
  assert(selected() === 'A', 'Deselecting filtered ontologies must preserve hidden selections');
  click('ont_select_adv_checkB');
  filter('Gamma');
  assert(!checked('ont_select_all_filtered') && visible() === 'C', 'Changing the filter must reset its checkbox');
  click('ont_select_all_filtered');
  assert(selected() === 'A,B,C', 'Filtered selection must work after changing filters');

  click('group_G');
  assert(
    !checked('ont_select_all_filtered') && visible() === 'A,B',
    'Group filter must reset the filtered-selection checkbox',
  );
  click('category_C');
  assert(visible() === 'A,B,C', 'Group and category filters must combine');
  click('ont_select_clear');
  assert(
    selected() === '' && $('.ont_select_boxes_tr input:checked').length === 0,
    'Clear must reset all ontology selections',
  );
  assert(
    !checked('group_G') && !checked('category_C'),
    'Clear must reset previously clicked group and category checkboxes',
  );

  $('#ont_select_adv').show(); // Reopen the picker after the outside Clear selections click closed it.
  click('group_G');
  click('category_C');
  filter('Beta');
  assert(!checked('group_G') && !checked('category_C'), 'Text filtering must clear both group and category selections');
  click('ont_select_all_filtered');
  assert(selected() === 'B', 'Selection must still work after clearing and refiltering');
}

async function searchOptions(win) {
  const $ = win.jQuery;
  const options = ['exact_match', 'include_properties', 'require_definition', 'include_views'];
  win.document.body.innerHTML = `<input id="search_keywords">
    <select id="ontology_ontologyId" multiple></select><select id="search_categories" multiple></select>
    ${options.map((option) => `<input type="checkbox" id="search_${option}">`).join('')}`;
  win.currentPathArray = () => [];
  let params = {};
  const searches = [];
  win.BP_queryString = () => params;
  win.recordSearch = () => searches.push(win.currentSearchParams());
  // Test autoSearch directly; other page-ready handlers concern unrelated UI plugins.
  // Export the functions from strict eval and replace only the backend search operation.
  const code = await source('/app/assets/javascripts/bp_search.js.erb');
  evaluateBeforeReady(
    win,
    code.replace(/<%=\s*asset_path\("([^"]+)"\)\s*%>/g, '/assets/$1') +
      '\nwindow.autoSearch = autoSearch; window.currentSearchParams = currentSearchParams; performSearch = window.recordSearch;',
    false,
  );
  const checkboxes = options.map((option) => win.document.getElementById('search_' + option));
  function restore(flags, expected) {
    params = { q: 'melanoma', ...flags };
    const before = searches.length;
    win.autoSearch();
    assert(searches.length === before + 1, 'Restoring search options must perform one search');
    assert(
      checkboxes.every((checkbox) => checkbox.checked === expected),
      'Restored flags must update the current checkbox state',
    );
    assert(
      options.every((option) => searches[before][option] === expected),
      'Search parameters must match restored checkboxes',
    );
    assert($('#search_keywords').val() === 'melanoma', 'The query must also be restored');
  }
  // Native clicks make the current state differ from the original HTML attributes.
  checkboxes.forEach((checkbox) => checkbox.click());
  restore({}, false);
  restore(Object.fromEntries(options.map((option) => [option, 'true'])), true);
  restore(Object.fromEntries(options.map((option) => [option, 'false'])), false);
  restore({ exactmatch: 'true', searchproperties: 'true', require_definition: 'true', include_views: 'true' }, true);
  restore({}, false);
  checkboxes.forEach((checkbox) => checkbox.click());
  assert(
    options.every((option) => win.currentSearchParams()[option]),
    'Manual changes must still reach search parameters',
  );
}

async function adminConfirmation(win) {
  const template = await source('/app/views/users/edit.html.haml');
  const script = template.match(/^:javascript\n((?: {2}[^\n]*\n|\n)+)/);
  assert(script, 'User edit script must exist');
  const code = script[1].replace(/^  /gm, '');

  // Both directions need confirmation; cancellation must leave the form unsubmitted.
  for (const wasAdmin of [false, true]) {
    win.document.body.innerHTML = `<form id="user_info">
      <input type="checkbox" id="user_admin" ${wasAdmin ? 'checked class="admin"' : ''}>
      <input type="submit" disabled>
    </form>`;
    const form = win.document.getElementById('user_info');
    const checkbox = win.document.getElementById('user_admin');
    const button = form.querySelector('input[type=submit]');
    let submitted = 0;
    const confirmations = [];
    form.submit = () => submitted++;
    win.alertify = { confirm: (message, callback) => confirmations.push({ message, callback }) };
    evaluateBeforeReady(win, code);
    const submit = () => form.dispatchEvent(new win.Event('submit', { bubbles: true, cancelable: true }));

    checkbox.click();
    assert(!submit(), 'The handler must intercept submission');
    assert(
      confirmations.length === 1 && submitted === 0,
      'A changed admin checkbox must request confirmation before submitting',
    );
    assert(
      confirmations[0].message.includes(wasAdmin ? 'revoke' : 'make this user an admin'),
      'Confirmation must describe the requested change',
    );
    confirmations[0].callback(false);
    assert(submitted === 0 && !button.disabled, 'Cancellation must enable retry without submitting');

    button.disabled = true;
    submit();
    assert(confirmations.length === 2 && submitted === 0, 'Retry must request confirmation again');
    confirmations[1].callback(true);
    assert(submitted === 1, 'Confirmation must submit exactly once');

    checkbox.click();
    submit();
    assert(
      confirmations.length === 2 && submitted === 2,
      'Returning to the original role must submit without a confirmation',
    );
  }

  win.document.body.innerHTML = '<form id="user_info"><input type="submit"></form>';
  let submitted = 0;
  const form = win.document.getElementById('user_info');
  form.submit = () => submitted++;
  win.alertify = {
    confirm: () => {
      throw new Error('No admin checkbox should mean no role confirmation');
    },
  };
  evaluateBeforeReady(win, code);
  form.dispatchEvent(new win.Event('submit', { bubbles: true, cancelable: true }));
  assert(submitted === 1, 'Editing a profile without an admin checkbox must still submit');
}

async function run() {
  const results = [];
  window.checkboxStateTestResults = { done: false, results };
  for (const migrate of [true, false]) {
    for (const test of [ontologyPicker, searchOptions, adminConfirmation]) {
      const label = `${test.name}, jQuery 2.2.4 ${migrate ? 'with' : 'without'} Migrate`;
      const item = document.createElement('li');
      item.textContent = label + ': running';
      document.querySelector('#results').appendChild(item);
      const frame = document.createElement('iframe');
      frame.title = label;
      const loaded = new Promise((resolve) => {
        frame.onload = resolve;
      });
      frame.src = './checkbox_state.html?fixture=1';
      document.body.appendChild(frame);
      await loaded;
      const win = frame.contentWindow;
      win.document.body.innerHTML = '';
      const errors = [];
      const capture = (event) => errors.push(event.message || String(event.reason));
      win.addEventListener('error', capture);
      win.addEventListener('unhandledrejection', capture);
      try {
        await loadScript(win.document, 'https://code.jquery.com/jquery-2.2.4.js');
        if (migrate) await loadScript(win.document, 'https://code.jquery.com/jquery-migrate-1.3.0.min.js');
        assert(win.jQuery.fn.jquery === '2.2.4', 'Unexpected jQuery version');
        assert(Boolean(win.jQuery.migrateVersion) === migrate, 'Unexpected Migrate presence');
        await test(win);
        assert(errors.length === 0, errors.join('; '));
        results.push({ label, passed: true });
        item.textContent = label + ': PASS';
      } catch (error) {
        results.push({ label, passed: false, error: error.message, errors });
        item.textContent = label + ': FAIL — ' + error.message;
      } finally {
        frame.remove();
      }
    }
  }
  const passed = results.filter((result) => result.passed).length;
  document.querySelector('#status').textContent = `${passed}/${results.length} cases passed`;
  window.checkboxStateTestResults.done = true;
}

if (!new URLSearchParams(location.search).has('fixture')) run();
