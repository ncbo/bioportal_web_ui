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

.controller('OntologyList', ['$scope', '$animate', '$timeout', function($scope, $animate, $timeout) {
  // Default values
  $scope.visible_ont_count = 0;
  $scope.ontology_sort_order = "-popularity";
  $scope.previous_sort_order = "-popularity";
  $scope.show_highlight = false;

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

  // This watches the facets and updates the list depending on which facets are selected
  // All facets are basically ANDed together and return true if no options under the facet are selected.
  $scope.$watch('facets', function() {
    filterOntologies();
  }, true);

  $scope.$watch('searchText', function() {
    filterOntologies();
  });

  var filterOntologies = function() {
    var key, i, ontology, facet, facet_count, show, other_facets, count = 0;
    $scope.show_highlight = false;
    $scope.show_highlight = true;

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

    // Highlight the count
    count = $("#visible_ont_count");
    if (count.hasClass("trigger_highlight")) {
      $animate.removeClass(count, "trigger_highlight");
    } else {
      $animate.addClass(count, "trigger_highlight");
    }
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

    angular.forEach(results, function(r){found[r.ref] = r});
    for (i = 0; i < $scope.ontologies.length; i++) {
      ontology = $scope.ontologies[i];
      ontology.show = false;
      ontology.search_rank = 0;
      if (found[ontology.id]) {
        ontology.show = true;
        ontology.search_rank = found[ontology.id].score;
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
;