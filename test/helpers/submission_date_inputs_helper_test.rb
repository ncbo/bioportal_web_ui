# frozen_string_literal: true

require 'test_helper'

class SubmissionDateInputsHelperTest < ActionView::TestCase
  include SubmissionInputsHelper
  include InputsHelper

  test 'renders a populated single date with a native maximum' do
    attr = OpenStruct.new(name: 'submission[released]', label: '', values: '2025-04-22T23:30:00-07:00')

    html = Nokogiri::HTML.fragment(generate_date_input(attr, max_date: Date.new(2025, 4, 30)))
    input = html.at_css('input[type="date"]')

    assert_equal 'submission[released]', input['name']
    assert_equal '2025-04-22', input['value']
    assert_equal '2025-04-30', input['max']
  end

  test 'normalizes repeated date values and applies the bound to existing and new rows' do
    @ontology = OpenStruct.new(acronym: 'TEST')
    attr = OpenStruct.new(name: 'submission[dates]', attr: 'dates', label: '',
                          values: ['2025-04-22T00:00:00Z', '2025-04-23T23:30:00-07:00'])

    html = Nokogiri::HTML.fragment(generate_list_date_input(attr, max_date: Date.new(2025, 4, 30)))
    inputs = html.css('input[type="date"]')

    assert_equal ['submission[dates][NEW_RECORD]', 'submission[dates][0]', 'submission[dates][1]'],
                 inputs.map { |input| input['name'] }
    assert_equal ['', '2025-04-22', '2025-04-23'], inputs.map { |input| input['value'] }
    assert_equal ['2025-04-30'] * 3, inputs.map { |input| input['max'] }
  end
end
