'use strict';

// Declare app level module which depends on views, and components
angular.module('FacetedBrowsing', [
  'ngRoute',
  'FacetedBrowsing.OntologyList'
]).
config( ['$locationProvider', function ($locationProvider) {
  $locationProvider.html5Mode(true);
}])
;

var app = angular.module('FacetedBrowsing.OntologyList', ['checklist-model', 'ngAnimate', 'pasvaz.bindonce'])

.controller('OntologyList', ['$scope', '$timeout', '$filter', function($scope, $timeout, $filter) {
  // Default values
  $scope.visible_ont_count = 0;

  // Persist the chosen sort order across page views/sessions via localStorage.
  // -search_rank is transient (only while a search is active) so it is never
  // persisted; a stored value is only honoured if it's one of the real options.
  var SORT_STORAGE_KEY = 'bp.ontologies.sort_order';
  var VALID_SORT_ORDERS = [
    '-popularity', 'name', '-class_count', '-individual_count',
    '-project_count', '-note_count', '-creationDate'
  ];
  var storedSort = null;
  try { storedSort = window.localStorage.getItem(SORT_STORAGE_KEY); } catch (e) { /* storage unavailable */ }
  var initialSort = (VALID_SORT_ORDERS.indexOf(storedSort) !== -1) ? storedSort : "-popularity";

  $scope.ontology_sort_order = initialSort;
  $scope.previous_sort_order = initialSort;

  // Data transfer from Rails
  $scope.debug = jQuery(document).data().bp.development;
  $scope.admin = jQuery(document).data().bp.admin;
  $scope.ontologies = jQuery(document).data().bp.ontologies;
  $scope.formats = jQuery(document).data().bp.formats.sort();
  $scope.categories = jQuery(document).data().bp.categories.sort(function(a, b){
    if (a.name < b.name) return -1;
    if (a.name > b.name) return 1;
    return 0;
  });
  $scope.categories_hash = jQuery(document).data().bp.categories_hash;
  $scope.groups = jQuery(document).data().bp.groups.sort(function(a, b){
    if (a.acronym < b.acronym) return -1;
    if (a.acronym > b.acronym) return 1;
    return 0;
  });
  $scope.groups_hash = jQuery(document).data().bp.groups_hash;

  // Rendering window. The template only builds DOM for the first `render_limit`
  // matching ontologies and grows the window as the user scrolls (or clicks
  // "Show more"). This keeps each digest cheap regardless of catalog size —
  // rendering the full ~1,500-item list was the cause of the typing stutter.
  var RENDER_LIMIT_INITIAL = 40;
  var RENDER_LIMIT_STEP = 40;
  $scope.render_limit = RENDER_LIMIT_INITIAL;

  // The concrete list ng-repeat renders (already filtered to matches and sorted).
  // Built once per filter/sort change in rebuildFilteredList() rather than via
  // filters in the ng-repeat expression, so the expensive filter+sort runs once
  // per change instead of on every digest, and so ng-repeat has a stable array
  // reference (no infinite digest).
  $scope.filteredOntologies = [];

  var rebuildFilteredList = function() {
    var shown = $scope.ontologies.filter(function(o) { return o.show; });
    var reverse = $scope.ontology_sort_order.charAt(0) === '-';
    $scope.filteredOntologies =
      $filter('orderBy')(shown, $scope.ontologySortValue, reverse);
  };

  // Reveal more matching rows (scroll handler and the "Show more" button).
  $scope.growRenderLimit = function() {
    $scope.render_limit += RENDER_LIMIT_STEP;
  };

  // Search setup
  $scope.searchText = null;
  $scope.ontIndex = lunr(function() {
    this.field('acronym', 100);
    this.field('name', 50);
    this.field('description');
    this.ref('id');
  });
  $scope.ontIndex.pipeline.reset();

  // Default setup for facets
  $scope.facets = {
    types: {
      active: ["ontology"],
      ont_property: "type",
      filter: function(ontology) {
        if ($scope.facets.types.active.length == 0)
          return true;
        if ($scope.facets.types.active.indexOf(ontology.type) === -1)
          return false;
        return true;
      },
    },
    formats: {
      active: [],
      ont_property: "format",
      filter: function(ontology) {
        if ($scope.facets.formats.active.length == 0)
          return true;
        if ($scope.facets.formats.active.indexOf(ontology.format) === -1)
          return false;
        return true;
      },
    },
    groups: {
      active: [],
      ont_property: "groups",
      filter: function(ontology) {
        if ($scope.facets.groups.active.length == 0)
          return true;
        if (intersection($scope.facets.groups.active, ontology.groups).length === 0)
          return false;
        return true;
      },
    },
    categories: {
      active: [],
      ont_property: "categories",
      filter: function(ontology) {
        if ($scope.facets.categories.active.length == 0)
          return true;
        if (intersection($scope.facets.categories.active, ontology.categories).length === 0)
          return false;
        return true;
      },
    },
    artifacts: {
      active: [],
      ont_property: "artifacts",
      filter: function(ontology) {
        if ($scope.facets.artifacts.active.length == 0)
          return true;
        if (intersection($scope.facets.artifacts.active, ontology.artifacts).length === 0)
          return false;
        return true;
      },
    },
    missing_status: {
      active: "",
      ont_property: "submissionStatus",
      values: ["None", "RDF", "OBSOLETE", "METRICS", "RDF_LABELS", "UPLOADED", "INDEXED", "ANNOTATOR", "DIFF"],
      filter: function(ontology) {
        if ($scope.facets.missing_status.active == "")
          return true;
        if (ontology.submissionStatus.indexOf($scope.facets.missing_status.active) !== -1)
          return false;
        return true;
      }
    },
    upload_date: {
      active: "",
      ont_property: "creationDate",
      values: {day: 1, week: 7, month: 30, three_months: 90, six_months: 180, year: 365, all: "all"},
      day_text: ["day", "week", "month", "three_months", "six_months", "year", "all"],
      filter: function(ontology) {
        var active = $scope.facets.upload_date.active;
        if (active == "")
          return true;
        if (!ontology.submission)
          return false;
        var ontDate = new Date(ontology.creationDate);
        var compareDate = new Date();
        compareDate.setDate(compareDate.getDate() - active);
        if (ontDate >= compareDate)
          return true;
        return false;
      }
    }
  }

  // Instantiate object counts
  // This doesn't happen on the facet itself because
  // there is a $watch directive and updating counts
  // on the facets causes an infinite loop.
  $scope.facet_counts = {};
  Object.keys($scope.facets).forEach(function(facet) {$scope.facet_counts[facet] = {}});

  // Default values for facets that aren't definied on the ontologies
  $scope.types = {
    ontology: {sort: 1, id: "ontology"},
    ontology_view: {sort: 2, id: "ontology_view"}
  };
  $scope.artifacts = ["notes", "projects", "summary_only"];

  $scope.groupAcronyms = function(groups) {
    var groupNames = [];
    angular.forEach(groups, function(group) {
      groupNames.push($scope.groups_hash[group].acronym);
    });
    return groupNames;
  };

  $scope.categoryNames = function(categories) {
    var catNames = [];
    angular.forEach(categories, function(category) {
      catNames.push($scope.categories_hash[category].name)
    })
    return catNames;
  }

  $scope.adminUsernames = function(admins) {
    return admins.map(function(a){return a.split('/').slice(-1)[0]});
  }

  $scope.ontologySortOrder = function(newOrder) {
    $scope.ontology_sort_order = newOrder;
  }

  // Sort key for the ontology list. orderBy is given this function so we can
  // normalise the "Name" sort: names can have stray leading whitespace and mixed
  // case, which a plain field sort would order by raw char code (whitespace and
  // capitals sorting before lowercase letters) — putting e.g. " Obesity..." and
  // capitalised names out of place. For name we trim + lowercase; every other
  // sort (popularity, counts, dates — all "[-]field") falls through to the raw
  // field value so numeric/descending sorts are unchanged.
  $scope.ontologySortValue = function(ontology) {
    var order = $scope.ontology_sort_order || '';
    var descending = order.charAt(0) === '-';
    var field = descending ? order.substring(1) : order;

    if (field === 'name') {
      return (ontology.name || '').trim().toLowerCase();
    }
    return ontology[field];
  }

  // Whether an ontology's description is long enough that the collapsed card
  // view truncates it — i.e. whether the "More" toggle should be shown. Kept in
  // sync with descriptionSnippet's SNIPPET_LEN. The stripped length is cached on
  // the ontology so this is cheap to call from the template each digest.
  var DESC_SNIPPET_LEN = 260;
  $scope.descriptionHasMore = function(ontology) {
    if (!ontology) return false;
    if (ontology._descTextLen == null) {
      ontology._descTextLen = String(ontology.description || '')
        .replace(/<[^>]+>/gm, ' ').replace(/\s+/g, ' ').trim().length;
    }
    return ontology._descTextLen > DESC_SNIPPET_LEN;
  };

  // --- Active-filter chips + clear-all -------------------------------------
  // A removable chip is shown above the list for each active facet selection
  // (and the search term), so users can see and undo what's applied without
  // hunting the sidebar. "Ontology" under Entry Type is the default baseline and
  // is intentionally not shown as a removable chip.

  // Human-readable label for a facet value (categories/groups have names).
  var facetValueLabel = function(facetKey, value) {
    if (facetKey === 'categories') {
      var cat = ($scope.categories || []).filter(function(c){ return c.id === value; })[0];
      return cat ? cat.name : value;
    }
    if (facetKey === 'upload_date') {
      var labels = { 1:'past day', 7:'past week', 30:'past month', 90:'past 3 months',
                     180:'past 6 months', 365:'past year', 'all':'any time' };
      return 'Uploaded: ' + (labels[value] || value);
    }
    if (facetKey === 'types') return value === 'ontology_view' ? 'Ontology View' : 'Ontology';
    return value;
  };

  // Rebuild the chip list only when filters change (not on every digest) — a
  // function returning a fresh array in an ng-repeat causes an infinite digest.
  $scope.activeFilterChips = [];

  var rebuildActiveFilterChips = function() {
    var chips = [];
    Object.keys($scope.facets).forEach(function(key) {
      var active = $scope.facets[key].active;
      if (angular.isArray(active)) {
        active.forEach(function(v) {
          // the default Entry Type = Ontology is the baseline, not a chip
          if (key === 'types' && v === 'ontology') return;
          chips.push({ facet: key, value: v, label: facetValueLabel(key, v) });
        });
      } else if (active !== '' && active != null) {
        chips.push({ facet: key, value: active, label: facetValueLabel(key, active) });
      }
    });
    $scope.activeFilterChips = chips;
  };

  $scope.removeFilter = function(chip) {
    var active = $scope.facets[chip.facet].active;
    if (angular.isArray(active)) {
      var i = active.indexOf(chip.value);
      if (i !== -1) active.splice(i, 1);
    } else {
      $scope.facets[chip.facet].active = '';
    }
  };

  $scope.clearSearch = function() {
    $scope.searchText = '';
  };

  // True when anything is applied beyond the defaults (so we can show a "Clear
  // all" control and, in the empty state, nudge the user to reset). Returns a
  // boolean (stable across digests, unlike an array).
  $scope.hasActiveFilters = function() {
    return $scope.activeFilterChips.length > 0 ||
           !($scope.searchText === null || $scope.searchText === '');
  };

  $scope.clearAllFilters = function() {
    Object.keys($scope.facets).forEach(function(key) {
      var facet = $scope.facets[key];
      if (angular.isArray(facet.active)) {
        facet.active = (key === 'types') ? ['ontology'] : [];
      } else {
        facet.active = '';
      }
    });
    $scope.searchText = '';
  };

  // This watches the facets and updates the list depending on which facets are selected
  // All facets are basically ANDed together and return true if no options under the facet are selected.
  $scope.$watch('facets', function() {
    filterOntologies();
  }, true);

  $scope.$watch('searchText', function() {
    filterOntologies();
  });

  // Remember the chosen sort order for next time. Only persist the real options
  // (never the transient -search_rank the search flow switches to).
  $scope.$watch('ontology_sort_order', function(newOrder, oldOrder) {
    // Re-sort the rendered list when the order changes (the list is now a
    // materialised array rather than an inline orderBy in the template).
    if (newOrder !== oldOrder) {
      $scope.render_limit = RENDER_LIMIT_INITIAL;
      rebuildFilteredList();
    }
    if (VALID_SORT_ORDERS.indexOf(newOrder) === -1) return;
    try { window.localStorage.setItem(SORT_STORAGE_KEY, newOrder); } catch (e) { /* storage unavailable */ }
  });

  var filterOntologies = function() {
    var key, i, ontology, facet, facet_count, show, other_facets;
    // A changed search/facet set is a fresh result list — scroll the render
    // window back to the top so the user sees the best matches first.
    $scope.render_limit = RENDER_LIMIT_INITIAL;

    // Reset facet counts
    Object.keys($scope.facet_counts).forEach(function(key) {
      $scope.facet_counts[key] = {};
    });

    // First, filter by search. Do this first because the facets
    // will apply on top of the search results (EX: for hiding views)
    filterSearch();

    // Filter ontologies based on facet + count for facets
    for (i = 0; i < $scope.ontologies.length; i++) {
      ontology = $scope.ontologies[i];

      if (searchActive() && ontology.show === false) continue;

      // Filter out ontologies based on their facet filter functions
      ontology.show = Object.keys($scope.facets).map(function(key) {
        return $scope.facets[key].filter(ontology);
      }).every(Boolean);

      // Check each facet entry to calculate counts
      // Counts are calculated by looking at whether or not ontologies match OTHER facets
      // IE, counts show what will be available for a given facet entry if that entry
      // were to be selected relative to what is already selected in other facets.
      Object.keys($scope.facets).forEach(function(key) {
        facet = $scope.facets[key];
        other_facets = Object.keys($scope.facets).filter(function(f){return key != f});
        show = other_facets.map(function(other_facet){return $scope.facets[other_facet].filter(ontology)}).every(Boolean);
        if (show) {
          facet_count = $scope.facet_counts[key];
          if (angular.isArray(ontology[facet.ont_property])) {
            ontology[facet.ont_property].forEach(function(val) {
              facet_count[val] = (facet_count[val] || 0) + 1;
            });
          } else {
            facet_count[ontology[facet.ont_property]] = (facet_count[ontology[facet.ont_property]] || 0) + 1;
          }
        }
      });
    }

    $scope.visible_ont_count = $scope.ontologies.filter(function(ont) {return ont.show}).length;

    // Rebuild the concrete (filtered + sorted) list ng-repeat renders.
    rebuildFilteredList();

    // Refresh the active-filter chips whenever the filters/search change.
    rebuildActiveFilterChips();
  }

  var filterSearch = function() {
    var i, results, ontology, found = {};
    if (!searchActive()) {
      $scope.ontologySortOrder($scope.previous_sort_order);
      return;
    }
    if ($scope.ontology_sort_order !== "-search_rank") {
      $scope.previous_sort_order = $scope.ontology_sort_order;
    }
    $scope.ontologySortOrder("-search_rank");
    results = $scope.ontIndex.search($scope.searchText);

    // An exact acronym match (case-insensitive) should always rank first — e.g.
    // typing "GO" puts the GO ontology at the top, even if lunr's TF/IDF scoring
    // would otherwise rank a name/description match higher. We add a large fixed
    // boost so it beats any ordinary lunr score, and make sure the exact match
    // is shown even if lunr didn't surface it.
    var query = ($scope.searchText || "").trim().toLowerCase();
    var EXACT_ACRONYM_BOOST = 1000;

    angular.forEach(results, function(r){found[r.ref] = r});
    for (i = 0; i < $scope.ontologies.length; i++) {
      ontology = $scope.ontologies[i];
      ontology.show = false;
      ontology.search_rank = 0;
      var exactAcronym = (ontology.acronym || "").toLowerCase() === query;
      if (found[ontology.id] || exactAcronym) {
        ontology.show = true;
        ontology.search_rank = (found[ontology.id] ? found[ontology.id].score : 0);
        if (exactAcronym) {
          ontology.search_rank += EXACT_ACRONYM_BOOST;
        }
      }
    }
  }

  var searchActive = function() {
    return !($scope.searchText === null || $scope.searchText === "");
  }

  var countAllInFacet = function(facet) {
    var active_facets = Object.keys($scope.facets).filter(function(facet) {return $scope.facets[facet].active.length > 0});
    if (active_facets.length == 0 || (active_facets.length == 1 && active_facets[0] == facet)) {
      return true;
    }
    return false;
  }

  var intersection = function(x, y) {
    if (typeof x === 'undefined' || typeof y === 'undefined') {return [];}
    var ret = [];
    for (var i = 0; i < x.length; i++) {
      for (var z = 0; z < y.length; z++) {
        if (x[i] == y[z]) {
          ret.push(i);
          break;
        }
      }
    }
    return ret;
  }


  $scope.init = function() {
    $scope.ontologies = jQuery(document).data().bp.fullOntologies;
    if (BP_queryString().filter) {
      angular.forEach($scope.groups, function(group) {
        if (group.acronym == BP_queryString().filter)
          $scope.facets.groups.active.push(group.id);
      });
    }
    filterOntologies();
    angular.forEach($scope.ontologies, function(ont) {
      $scope.ontIndex.add({
        id: ont.id,
        acronym: ont.acronym,
        name: ont.name,
        description: ont.description
      })
    });

    // Infinite scroll: grow the render window as the user nears the bottom of
    // the (independently scrolling) results list, so long result sets fill in
    // without ever rendering the whole catalog at once.
    $timeout(function() {
      var list = document.querySelector('.ontology-list');
      if (!list) return;
      var ticking = false;
      list.addEventListener('scroll', function() {
        if (ticking) return;
        ticking = true;
        window.requestAnimationFrame(function() {
          ticking = false;
          var nearBottom = list.scrollTop + list.clientHeight >= list.scrollHeight - 400;
          if (nearBottom && $scope.render_limit < $scope.filteredOntologies.length) {
            $scope.$apply($scope.growRenderLimit);
          }
        });
      });
    });
  }
  $timeout($scope.init);

}])

.filter('idToTitle', function() {
  return function(input) {
    if (input) {
      var splitInput = input.replace(/_/g, " ").split(" ");
      var newInput = [];
      var word;
      for (word in splitInput) {
        word = splitInput[word];
        if (word[0].toUpperCase() == word[0]) {
          newInput.push(word);
        } else {
          newInput.push(word[0].toUpperCase() + word.slice(1));
        }

      }
      return newInput.join(" ");
    }
  };
})

.filter('humanShortNum', function() {
  return function(input) {
    if (input) {
      var num = parseInt(input);
      if (num < 10000) {return num;}
      if (num > 10000 && num < 1000000) {
        return String(+(Math.round(num / 1000 + "e+1")  + "e-1")) + "k"
      }
      if (num > 1000000) {
        return String(+(Math.round(num / 100000 + "e+1")  + "e-1")) + "M"
      }
      return newInput.join(" ");
    }
  };
})

.filter("toArray", function() {
  return function(obj) {
    var result = [];
    angular.forEach(obj, function(val, key) {
      result.push(val);
    });
    return result;
  };
})

.filter('htmlToText', function() {
  return function(text) {
    return String(text).replace(/<[^>]+>/gm, '');
  }
})

.filter('descriptionToText', function() {
  return function(text) {
    text = String(text).replace(/<[^>]+>/gm, '');
    return text.split(/\.\W/)[0];
  }
})

// Produce the description text shown on a result card. Strips HTML, then:
//   - expanded === true  -> the full description (used by the "More" toggle).
//   - a search query that appears AFTER the leading excerpt -> a snippet
//     centred on the first match (Google-style, with leading/trailing "…") so
//     the description explains why the result matched.
//   - otherwise -> a leading excerpt (SNIPPET_LEN chars, cut on a word
//     boundary) with a trailing "…" when the text was truncated.
// The result is plain text; it is highlighted separately by the `highlight`
// filter downstream in the template.
.filter('descriptionSnippet', function() {
  var SNIPPET_LEN = 260;   // leading excerpt length
  var CONTEXT_BEFORE = 60; // chars of context kept before a mid-text match

  var stripAndCollapse = function(text) {
    return String(text == null ? '' : text)
      .replace(/<[^>]+>/gm, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  };

  // Truncate at or before `len`, preferring the last word boundary, and append
  // an ellipsis. `prefix` is prepended (used for the leading "…" of a snippet).
  var clip = function(text, len, prefix) {
    prefix = prefix || '';
    if (text.length <= len) return prefix + text;
    var cut = text.slice(0, len);
    var lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > len * 0.6) cut = cut.slice(0, lastSpace);
    return prefix + cut.replace(/[\s.,;:]+$/, '') + '…';
  };

  return function(description, query, expanded) {
    var text = stripAndCollapse(description);
    if (expanded) return text;

    var q = (query == null ? '' : String(query)).trim().toLowerCase();
    var matchAt = q ? text.toLowerCase().indexOf(q) : -1;

    // No query, no match, or the match already falls inside the leading
    // excerpt: just show the leading excerpt.
    if (matchAt === -1 || matchAt < SNIPPET_LEN - 20) {
      return clip(text, SNIPPET_LEN, '');
    }

    // Match is past the leading excerpt: window around it.
    var start = Math.max(0, matchAt - CONTEXT_BEFORE);
    // Back up to a word boundary so we don't start mid-word.
    if (start > 0) {
      var sp = text.indexOf(' ', start);
      if (sp !== -1 && sp < matchAt) start = sp + 1;
    }
    var windowText = text.slice(start);
    return clip(windowText, SNIPPET_LEN, start > 0 ? '…' : '');
  };
})

// Highlight occurrences of the current search query within a piece of text by
// wrapping the matched substrings in <mark>. The input text is fully HTML-escaped
// first and only our own <mark> tags are inserted, so the result is safe to bind
// via ng-bind-html (trusted through $sce) without pulling in ngSanitize. When
// there is no query the text is returned escaped and unmarked (a plain no-op).
.filter('highlight', ['$sce', function($sce) {
  var escapeHtml = function(s) {
    return String(s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  };
  var escapeRegExp = function(s) {
    return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  };
  return function(text, query) {
    var safe = escapeHtml(text == null ? '' : text);
    var q = (query == null ? '' : String(query)).trim();
    if (!q) return $sce.trustAsHtml(safe);
    // Match the query case-insensitively; escape it so regex metacharacters in
    // the search box are treated literally.
    var re = new RegExp('(' + escapeRegExp(escapeHtml(q)) + ')', 'gi');
    return $sce.trustAsHtml(safe.replace(re, '<mark class="search-hl">$1</mark>'));
  };
}])

// Format a date using the visitor's browser locale (via Intl.DateTimeFormat)
// rather than AngularJS's built-in `date` filter, which is frozen to en-US
// unless an angular-i18n locale bundle is loaded (we load none). This shows a
// day/short-month/year date localised to the user — e.g. "21 Mar 2026" (en),
// "21 mars 2026" (fr), "2026年3月21日" (ja). Falls back to the raw value if the
// input can't be parsed or Intl is unavailable.
.filter('localeDate', function() {
  var formatter = null;
  if (typeof Intl !== 'undefined' && Intl.DateTimeFormat) {
    // `undefined` locale => use the browser's default locale.
    formatter = new Intl.DateTimeFormat(undefined, {
      day: 'numeric', month: 'short', year: 'numeric'
    });
  }
  return function(value) {
    if (!value) return value;
    var date = (value instanceof Date) ? value : new Date(value);
    if (isNaN(date.getTime())) return value;
    return formatter ? formatter.format(date) : date.toDateString();
  };
})
;