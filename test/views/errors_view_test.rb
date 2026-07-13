require 'test_helper'

# Renders the error templates in isolation (no layout, no API calls) so the
# assertions are deterministic and fast.
class ErrorsViewTest < ActionView::TestCase
  test 'internal server error page drops the stale "we have been notified" copy (ncbo#144)' do
    html = render(template: 'errors/internal_server_error').to_s

    refute_includes html, 'We have been notified',
                     'airbrake-era "we have been notified" claim should be removed'
    assert_match(/something went wrong/i, html,
                 'page should still apologize for the error')
  end
end
