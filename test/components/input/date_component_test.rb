# frozen_string_literal: true

require 'test_helper'

class Input::DateComponentTest < ActiveSupport::TestCase
  include ViewComponent::TestHelpers

  test 'renders a native date input with its identity and maximum date' do
    render_inline Input::DateComponent.new(name: 'submission[released]', id: 'released',
                                          value: Date.new(2025, 4, 22), max_date: Date.new(2025, 4, 30))

    assert_selector 'input[type="date"][name="submission[released]"][id="released"]' \
                    '[value="2025-04-22"][max="2025-04-30"]'
    refute_selector '[data-controller~="flatpickr"], [data-flatpickr-date-format], [data-flatpickr-max-date]'
  end

  test 'normalizes date and timestamp values without shifting their calendar date' do
    [
      '2025-04-22',
      '2025-04-22T23:30:00-07:00',
      Date.new(2025, 4, 22),
      DateTime.new(2025, 4, 22, 23, 30, 0, '-07:00'),
      Time.new(2025, 4, 22, 23, 30, 0, '-07:00')
    ].each do |value|
      render_inline Input::DateComponent.new(name: 'submission[released]', value: value)

      assert_selector 'input[type="date"][value="2025-04-22"]'
    end
  end

  test 'normalizes bounds supplied as timestamps' do
    render_inline Input::DateComponent.new(name: 'date', max_date: '2025-04-30T23:30:00-07:00')

    assert_selector 'input[max="2025-04-30"]'
  end

  test 'keeps empty values empty and leaves an unspecified maximum unset' do
    [nil, ''].each do |value|
      render_inline Input::DateComponent.new(name: 'date', value: value)

      assert_selector 'input[type="date"]'
      refute_selector 'input[value]:not([value=""]), input[max]:not([max=""])'
    end
  end

  test 'invalid existing values do not prevent the form and validation error from rendering' do
    render_inline Input::DateComponent.new(name: 'date', value: 'invalid', error_message: 'Enter a valid date')

    assert_selector 'input[type="date"]'
    assert_text 'Enter a valid date'
  end
end
