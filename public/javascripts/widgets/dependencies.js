// Shared by the standalone Jump To and Form Autocomplete entry points.
(function (window, document) {
  if (window.BioPortalWidgetDependencies) return;

  var scripts = {};
  var jqueryLoading;

  function loadScript(url) {
    if (!scripts[url]) {
      scripts[url] = new Promise(function (resolve, reject) {
        var script = document.createElement('script');
        script.src = url;
        script.async = true;
        script.onload = function () {
          resolve();
        };
        script.onerror = function () {
          delete scripts[url];
          script.remove();
          reject(new Error('Unable to load BioPortal widget dependency: ' + url));
        };
        document.head.appendChild(script);
      });
    }
    return scripts[url];
  }

  function jquery() {
    if (window.jQuery) return Promise.resolve(window.jQuery);
    if (!jqueryLoading) {
      var hostDollar = window.$;
      jqueryLoading = loadScript('https://code.jquery.com/jquery-1.11.2.min.js')
        .then(function () {
          // Preserve a host library that already owns $, as with jQuery.noConflict().
          if (hostDollar !== undefined) window.jQuery.noConflict();
          return window.jQuery;
        })
        .catch(function (error) {
          jqueryLoading = null;
          throw error;
        });
    }
    return jqueryLoading;
  }

  function ready(jq) {
    return new Promise(function (resolve) {
      jq(function () {
        resolve(jq);
      });
    });
  }

  function stylesheet(url) {
    var links = document.querySelectorAll('link[rel="stylesheet"]');
    for (var i = 0; i < links.length; i++) {
      if (links[i].href === url) return;
    }
    var link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = url;
    document.head.appendChild(link);
  }

  window.BioPortalWidgetDependencies = {
    load: function (server) {
      // Normalize relative and protocol-relative server URLs for cache keys.
      var base = new URL(server.replace(/\/$/, '') + '/javascripts/JqueryPlugins/autocomplete/', document.baseURI).href;
      return jquery()
        .then(ready)
        .then(function (jq) {
          stylesheet(base + 'jquery.autocomplete.css');
          if (typeof jq.fn.bioportal_autocomplete === 'function') return jq;
          return loadScript(base + 'crossdomain_autocomplete.js')
            .then(function () {
              // The plugin registers inside DOM ready, which is asynchronous in jQuery 3.
              return ready(jq);
            })
            .then(function () {
              if (typeof jq.fn.bioportal_autocomplete !== 'function') {
                delete scripts[base + 'crossdomain_autocomplete.js'];
                throw new Error('BioPortal autocomplete did not initialize');
              }
              return jq;
            });
        });
    },
  };
})(window, document);
