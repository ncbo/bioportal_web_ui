const root = '/app/';
const pause = () => new Promise((resolve) => setTimeout(resolve, 20));

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function until(condition, message) {
  const deadline = Date.now() + 3000;
  while (!condition()) {
    assert(Date.now() < deadline, message);
    await pause();
  }
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

function click(win, element) {
  assert(element, 'Click target must exist');
  return element.dispatchEvent(new win.MouseEvent('click', { bubbles: true, cancelable: true }));
}

async function applicationHandlers(win) {
  const $ = win.jQuery;
  const ready = [];
  const originalReady = $.fn.ready;
  $.fn.ready = function (callback) {
    ready.push(callback);
    return this;
  };
  const loads = [];
  const requests = [];
  const popups = [];
  let draws = 0;
  $.fn.load = function (url) {
    loads.push({ element: this[0], url });
    return this;
  };
  $.ajax = (options) => {
    requests.push(options);
  };
  $.fn.chosen = $.fn.button = function () {
    return this;
  };
  $.facebox = (options) => popups.push(options);
  $.facebox.settings = {};
  win.BP_CONFIG = {};
  win.DataTable = function () {
    this.draw = () => draws++;
  };
  win.DataTable.ext = { search: [] };

  // Execute actual application sources; only Rails asset URLs need substitution.
  for (const file of ['bioportal.js.erb', 'bp_search.js.erb', 'bp_admin.js']) {
    const text = await source(root + 'assets/javascripts/' + file);
    win.eval(text.replace(/<%=\s*asset_path\("([^"]+)"\)\s*%>/g, '/assets/$1'));
  }
  const haml = await source(root + 'views/users/show.html.haml');
  const script = haml.match(/^  :javascript\n((?: {4}[^\n]*\n|\n)+)/m);
  assert(script, 'User subscriptions JavaScript block must exist');
  win.eval(script[1].replace(/^    /gm, ''));

  // Avoid unrelated initial page requests, keeping the event callbacks themselves intact.
  win.displayOntologies = win.displayUsers = win.UpdateCheck.act = () => {};
  win.autoSearch = () => {};
  $.fn.ready = originalReady;
  ready.forEach((callback) => callback.call(win.document));

  // Every target below is inserted AFTER registration, as with AJAX/Turbo content.
  $(win.document.body).append('<input type="text" class="help_text help_text_font" title="Search" value="Search">');
  const input = $('input.help_text')[0];
  input.focus();
  assert(input.value === '' && !$(input).hasClass('help_text_font'), 'Delegated focus must clear helper text');
  input.blur();
  assert(input.value === 'Search' && $(input).hasClass('help_text_font'), 'Delegated blur must restore helper text');
  input.focus();
  input.value = 'actual query';
  input.blur();
  assert(input.value === 'actual query', 'Blur must preserve user input');

  $(win.document.body).append(
    '<span class="more_less_container"><a class="truncated_more"><span>More</span></a><a class="truncated_less" style="display:none"><span>Less</span></a></span>',
  );
  click(win, $('.truncated_more span')[0]);
  assert(
    $('.truncated_less').is(':visible') && !$('.truncated_more').is(':visible'),
    'More must use the matching anchor when a child is clicked',
  );
  click(win, $('.truncated_less span')[0]);
  assert(
    $('.truncated_more').is(':visible') && !$('.truncated_less').is(':visible'),
    'Less must restore truncated content',
  );

  $(win.document.body).append(
    '<div class="paginate_ajax"><div class="pagination"><a href="/fixture/page/2"><span>2</span></a></div></div><div id="fallback"><div class="pagination"><a href="/fixture/page/3">3</a></div></div>',
  );
  assert(!click(win, $('.paginate_ajax a span')[0]), 'AJAX pagination must prevent browser navigation');
  assert(
    loads.length === 1 && loads[0].element === $('.paginate_ajax')[0] && loads[0].url === '/fixture/page/2',
    'Pagination must load the intended container',
  );
  $('.paginate_ajax .pagination').html('<a href="/fixture/page/4">4</a>');
  click(win, $('.paginate_ajax a')[0]);
  click(win, $('#fallback a')[0]);
  assert(
    loads.length === 3 && loads[1].url === '/fixture/page/4' && loads[2].element.id === 'fallback',
    'Replacement links and the fallback pagination container must work',
  );

  $(win.document.body).append(
    '<div id="search_results"></div><span id="ontologies_count_total"></span><div id="biomixer"></div>',
  );
  for (const kind of ['ont', 'cls']) {
    $('#search_results').html(
      `<a class="additional_${kind}_results_link" data-bp_ont="TEST" href="#"><span>Expand</span><span class="hide_link not_visible">Hide</span></a><div id="additional_${kind}_results_TEST" class="not_visible"></div>`,
    );
    assert(!click(win, $('#search_results a span')[0]), 'Search expansion must prevent navigation');
    assert(
      !$(`#additional_${kind}_results_TEST`).hasClass('not_visible'),
      'Search expansion must find the selected ontology',
    );
    click(win, $('#search_results a span')[0]);
    assert($(`#additional_${kind}_results_TEST`).hasClass('not_visible'), 'Search expansion must toggle closed');
  }
  $('#search_results').html('<div class="search_result"></div><div class="search_result"></div>');
  $(win.document).trigger('search_results_updated');
  assert($('#ontologies_count_total').text() === '2', 'Document event must update the search count');
  $('#search_results').append(
    '<a class="class_visualize" data-bp_ontologyid="TEST" data-bp_conceptid="urn:example/a"><span>Visualize</span></a>',
  );
  click(win, $('.class_visualize span')[0]);
  assert(popups.length === 1 && popups[0].div === '#biomixer', 'Visualization must open the popup');
  assert(
    $('#biomixer iframe').attr('src').includes('conceptid=urn%3Aexample%2Fa'),
    'Visualization must use the clicked concept',
  );

  $(win.document.body).append('<span class="toggle-row-display"><a><span>All</span></a></span>');
  click(win, $('.toggle-row-display a span')[0]);
  assert(win.problemOnly === false && draws === 1, 'Admin filter must toggle and redraw once');
  click(win, $('.toggle-row-display a')[0]);
  assert(win.problemOnly === true && draws === 2, 'Admin filter must work after replacing its own link');

  $(win.document.body).append(
    '<a class="subscribe_to_ontology" data-bp_ontology_id="TEST" data-bp_is_subbed="false" data-bp_user_id="test user"><span class="ui-button-text">Subscribe</span></a>',
  );
  click(win, $('.subscribe_to_ontology span')[0]);
  assert(
    requests.length === 1 && requests[0].url === '/subscriptions?user_id=test%20user&ontology_id=TEST&subbed=false',
    'Subscription must use the matching anchor and make one request',
  );
  requests[0].success({});
  click(win, $('.subscribe_to_ontology span')[0]);
  assert(requests.length === 2 && requests[1].url.endsWith('subbed=true'), 'Subscription must use the updated state');
}

async function treeHandlers(win) {
  const $ = win.jQuery;
  const requests = [];
  $.ajax = (options) => {
    requests.push(options);
  };
  const text = await source(root + 'javascript/controllers/simple_tree_controller.js');
  // Resolve the existing npm import for a static-server test, using the real controller and Stimulus.
  const stimulusURL = location.origin + '/node_modules/@hotwired/stimulus/dist/stimulus.js';
  const controllerURL = win.URL.createObjectURL(
    new win.Blob([text.replace("'@hotwired/stimulus'", JSON.stringify(stimulusURL))], { type: 'text/javascript' }),
  );
  const module = win.document.createElement('script');
  module.type = 'module';
  module.textContent = `import { Application } from ${JSON.stringify(stimulusURL)};
    import Tree from ${JSON.stringify(controllerURL)};
    window.treeApp = Application.start();
    window.treeApp.register('simple-tree', Tree);`;
  win.document.head.appendChild(module);
  await until(() => win.treeApp, 'Stimulus did not start');

  function addTree(id) {
    $(win.document.body).append(
      `<ul id="${id}" data-controller="simple-tree"><li><ul class="children"></ul></li></ul>`,
    );
    return win.document.getElementById(id);
  }
  function link(tree) {
    $(tree)
      .find('.children')
      .html('<li><a class="too_many_children_override" href="/fixture/children"><span>More children</span></a></li>');
    return $(tree).find('a span')[0];
  }
  const controller = (tree) => win.treeApp.getControllerForElementAndIdentifier(tree, 'simple-tree');
  const first = addTree('first-tree');
  const second = addTree('second-tree');
  await until(() => controller(first) && controller(second), 'Tree controllers did not connect');
  await pause(); // Allow the controller's delayed tree initialization to finish.
  assert(!click(win, link(first)), 'Tree loading must prevent navigation');
  assert(
    requests.length === 1 && requests[0].url === '/fixture/children',
    'Nested link content must trigger exactly one request across two trees',
  );
  requests[0].error.call(requests[0].context);
  click(win, $(first).find('.too_many_children_override')[0]);
  assert(
    requests.length === 2 && requests[1].url === '/fixture/children',
    'Dynamically inserted retry must retain the original URL',
  );

  // Detach natively so jQuery does not clean handlers on behalf of the controller.
  first.remove();
  await until(() => !controller(first), 'Tree did not disconnect');
  link(first);
  // jQuery.trigger bubbles within detached DOM, unlike a document-level listener.
  $(first).find('a').trigger('click');
  assert(requests.length === 2, 'Detached tree must not retain a handler');
  win.document.body.appendChild(first);
  await until(() => controller(first), 'Tree did not reconnect');
  await pause();
  click(win, link(first));
  click(win, link(second));
  assert(requests.length === 4, 'Reconnection must not duplicate handlers or affect another tree');

  const transient = addTree('transient-tree');
  // Wait only for Stimulus's connect microtask, then detach before the initialization timer.
  await Promise.resolve();
  assert(controller(transient), 'Transient tree must connect');
  transient.remove();
  await pause();
  transient.removeAttribute('data-controller');
  win.document.body.appendChild(transient);
  link(transient);
  $(transient).find('a').trigger('click');
  assert(requests.length === 4, 'A tree disconnected before initialization must not acquire a handler later');
  win.treeApp.stop();
  win.URL.revokeObjectURL(controllerURL);
}

async function run() {
  const results = [];
  window.delegatedEventTestResults = { done: false, results };
  for (const migrate of [true, false]) {
    for (const test of [applicationHandlers, treeHandlers]) {
      const label = `${test.name}, jQuery 2.2.4 ${migrate ? 'with' : 'without'} Migrate`;
      const item = document.createElement('li');
      item.textContent = label + ': running';
      document.querySelector('#results').appendChild(item);
      const frame = document.createElement('iframe');
      frame.title = label;
      const loaded = new Promise((resolve) => {
        frame.onload = resolve;
      });
      frame.src = './delegated_events.html?fixture=1&p=classes';
      document.body.appendChild(frame);
      await loaded;
      const win = frame.contentWindow;
      win.document.body.innerHTML = '';
      const errors = [];
      const capture = (event) => errors.push(event.message || String(event.reason));
      win.addEventListener('error', capture);
      win.addEventListener('unhandledrejection', capture);
      window.addEventListener('error', capture);
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
        window.removeEventListener('error', capture);
        frame.remove();
      }
    }
  }
  const failures = results.filter((result) => !result.passed).length;
  document.querySelector('#status').textContent = `${results.length - failures}/${results.length} cases passed`;
  window.delegatedEventTestResults.done = true;
}

if (!new URLSearchParams(location.search).has('fixture')) run();
