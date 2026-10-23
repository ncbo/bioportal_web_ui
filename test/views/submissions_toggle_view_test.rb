# frozen_string_literal: true

require 'test_helper'

class SubmissionsToggleViewTest < ActionView::TestCase
  helper_method :status_link, :download_link, :xmldatetime_to_date

  setup do
    explorer = Object.new
    explorer.define_singleton_method(:latest_submission) { |_options| nil }
    @ontology = OpenStruct.new(explore: explorer, metadata_only?: false)
    @acronym = 'TEST'
    @ont_restricted = false
  end

  # Isolate row rendering from API-backed link helpers.
  def status_link(submission, *_args)
    link_to("Submission #{submission.submissionId}", '#submission')
  end

  def download_link(*_args)
    link_to('Download', '#download')
  end

  def xmldatetime_to_date(value)
    value
  end

  test 'admin rows and toggle render correctly around the ten-row limit' do
    assert_submission_table('layouts/ontology_report_submissions', 10)
  end

  test 'ontology rows and toggle render correctly around the five-row limit' do
    assert_submission_table('ontologies/submissions', 5)
  end

  test 'restricted ontology submissions retain three columns' do
    @ont_restricted = true
    assert_submission_table('ontologies/submissions', 5, columns: 3)
  end

  test 'missing admin ontology renders its message without a toggle' do
    @ontology = nil
    html = render(partial: 'layouts/ontology_report_submissions').to_s
    assert_includes html, 'does not appear to exist'
    assert_empty Nokogiri::HTML5.fragment(html).css('[data-controller="submissions-toggle"]')
  end

  test 'metadata-only ontology renders no submissions table' do
    @ontology = OpenStruct.new(metadata_only?: true)
    html = render(partial: 'ontologies/submissions').to_s
    assert_empty Nokogiri::HTML5.fragment(html).css('table')
  end

  private

  def assert_submission_table(partial, limit, columns: 4)
    [0, limit - 1, limit, limit + 2].each do |count|
      @submissions = Array.new(count) do |index|
        OpenStruct.new(submissionId: index + 1, released: '2026-10-23', creationDate: '2026-10-23')
      end
      reset_cycle
      html = render(partial: partial).to_s
      document = Nokogiri::HTML5.fragment(html)
      table = document.at_css('[data-controller="submissions-toggle"]')
      assert table, "Missing controller in #{partial} with #{count} submissions"
      rows = table.css('tr').select do |row|
        row.at_css('td') && !row.at_css('[data-submissions-toggle-target="toggle"]')
      end
      assert_equal count, rows.length, 'Each submission must have one correctly nested row'
      rows.each_with_index do |row, index|
        assert_equal columns, row.element_children.count { |child| child.name == 'td' }
        assert_equal index >= limit, row.classes.include?('hidden_ont')
        if index >= limit
          assert_equal 'row', row['data-submissions-toggle-target']
        else
          assert_nil row['data-submissions-toggle-target']
        end
        if partial.start_with?('layouts/')
          assert_equal index.odd?, row.classes.include?('alt'), 'Keep admin row striping'
          assert_equal "DeleteSubmission.act('TEST', #{index + 1});", row.at_css('a[onclick]')['onclick']
        end
      end
      toggle = table.at_css('[data-submissions-toggle-target="toggle"]')
      if count > limit
        assert toggle
        assert_equal 'more...', toggle.text.strip
        assert_equal 'false', toggle['aria-expanded']
        assert_equal 'click->submissions-toggle#toggle', toggle['data-action']
        assert_equal columns.to_s, toggle.parent['colspan']
      else
        assert_nil toggle, 'Do not offer expansion when all submissions already fit'
      end
      assert_empty document.css('script'), 'Toggle behavior belongs in the Stimulus controller'
    end
  end
end
