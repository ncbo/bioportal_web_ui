require 'test_helper'

class OntologiesHelperTest < ActionView::TestCase
  tests OntologiesHelper

  # current_concept_view / selected_concept_view? drive which concept view (Details /
  # Visualization / Notes / Mappings) is active from the `view` URL param, so the
  # selection survives a class change instead of always resetting to Details (#533).

  test 'current_concept_view defaults to details when the view param is absent' do
    assert_equal 'details', current_concept_view
  end

  test 'current_concept_view returns a recognised view param' do
    params[:view] = 'visualization'
    assert_equal 'visualization', current_concept_view
  end

  test 'current_concept_view falls back to details for an unknown view param' do
    params[:view] = 'bogus'
    assert_equal 'details', current_concept_view,
                 'an unrecognised ?view=... must fall back to details, not leave every tab deselected'
  end

  test 'current_concept_view falls back to details for a blank view param' do
    params[:view] = ''
    assert_equal 'details', current_concept_view
  end

  test 'selected_concept_view? matches only the active view' do
    params[:view] = 'concept-notes'
    assert selected_concept_view?('concept-notes')
    refute selected_concept_view?('details')
    refute selected_concept_view?('visualization')
  end

  # Guards the coupling flagged in code review: CONCEPT_VIEWS must list exactly the
  # tab ids rendered by _show.html.haml (in order). If a tab is added/renamed there
  # without updating the constant, its ?view=... value wouldn't be whitelisted and
  # the tab could never be the active view via URL — this fails loudly instead.
  test 'CONCEPT_VIEWS stays in sync with the tab ids in concepts/_show.html.haml' do
    show = Rails.root.join('app', 'views', 'concepts', '_show.html.haml').read
    rendered_ids = show.scan(/tab_item_component\([^)]*\bid:\s*'([^']+)'/).flatten
    assert_equal OntologiesHelper::CONCEPT_VIEWS, rendered_ids,
                 'OntologiesHelper::CONCEPT_VIEWS must match (and be ordered like) the ' \
                 'tab_item_component id: values in concepts/_show.html.haml'
  end
end
