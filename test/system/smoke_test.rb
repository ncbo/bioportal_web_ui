require "application_system_test_case"

class SmokeTest < ApplicationSystemTestCase
  test "login page loads and shows form" do
    visit login_index_url
    assert_selector "h4", text: /Log in to/
    assert_selector "input[name='user[username]']"
    assert_selector "input[name='user[password]']"
  end

  test "home page loads" do
    visit root_url
    assert_selector ".card-header", text: "Search for a class"
    assert_selector ".card-header", text: "Find an ontology"
    assert_selector ".card-header", text: /Statistics/
  end
end
