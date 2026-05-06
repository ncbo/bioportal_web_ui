# frozen_string_literal: true

require 'test_helper'

# Contract tests assert what we *assume* about the upstream BioPortal API
# wire shape. Unlike controller tests, they exercise no app code beyond the
# API client — their job is to fail loudly the moment the API changes shape
# under us, before that drift propagates into silent bugs in every controller
# that handles the affected response.
#
# Background: ncbo/bioportal_web_ui#509 shipped a users#search action whose
# unit tests stubbed LinkedData::Client::HTTP.get with a hand-rolled flat-
# array fake. PR ncbo/bioportal_web_ui#510 had already changed /users to
# return a paged response (an object with .collection, .nextPage, .pageCount).
# The stub-based tests stayed green because the fake never matched reality;
# the bug only surfaced when a user typed in the autocomplete. A contract
# test catches that class of drift in CI, not in production.
class UsersSearchContractTest < ActionDispatch::IntegrationTest
  test 'GET /users?search= returns a paged-collection shape' do
    response = begin
      LinkedData::Client::HTTP.get(
        "#{LinkedData::Client.settings.rest_url}/users",
        search: 'admin', include: 'username', pagesize: 5, page: 1
      )
    rescue StandardError => e
      skip "Upstream /users unreachable (#{e.class}: #{e.message}). " \
           'Check BIOPORTAL_API_URL / BIOPORTAL_API_KEY or staging health.'
    end

    # Page-level shape: every caller that paginates this endpoint
    # (admin#_users walks nextPage; users#search takes the first page) relies
    # on these accessors. If any disappear, both controllers break silently.
    %i[collection nextPage pageCount].each do |attr|
      assert response.respond_to?(attr),
             "paged response missing :#{attr} — upstream shape changed?"
    end
    assert_kind_of Array, response.collection,
                   ':collection should be an Array of user records'

    # Per-item shape: only assert when results came back. A zero-result
    # environment isn't a contract violation; missing :id/:username on the
    # user model is.
    user = response.collection.first
    skip 'no users matched "admin"; cannot assert per-item shape' if user.nil?

    assert user.respond_to?(:id),
           'user item missing :id — User model shape changed?'
    assert user.respond_to?(:username),
           'user item missing :username — include=username may not be honored'
    assert_kind_of String, user.id
    assert_kind_of String, user.username
  end
end
