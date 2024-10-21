require 'test_helper'
require_relative '../helpers/application_test_helpers'

class SubmissionFlowsTest < ActionDispatch::IntegrationTest
  include ApplicationTestHelpers::Users
  include ApplicationTestHelpers::Groups
  include ApplicationTestHelpers::Categories
  include ApplicationTestHelpers::Ontologies

  setup do
    @logged_user = fixtures(:users)[:john]
    @user_bob = fixtures(:users)[:bob]
    @new_ontology = fixtures(:ontologies)[:ontology1]
    @new_submission = fixtures(:submissions)[:submission1]
    @groups = create_groups
    @categories = create_categories
    @user_bob = create_user(@user_bob)
    @logged_user = create_user(@logged_user)
    @new_ontology[:administeredBy] = [@logged_user.username, @user_bob.username]
    @new_ontology[:hasDomain] = @categories[0..3]
    @new_ontology[:group] = @groups[0..3]
    @new_submission[:isRemote] = '1'
  end

  teardown do
    delete_user(@user_bob)
    delete_user(@logged_user)
    delete_groups
    delete_categories
    delete_ontologies([@new_ontology])
  end
end


