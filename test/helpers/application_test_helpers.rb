require 'rails/test_help'
module ApplicationTestHelpers

  def self.transform_models_to_ids(object)
    object.each_pair do |key, value|
      if value.is_a?(Array) && value.first.is_a?(LinkedData::Client::Base)
        object[key] = value.map(&:id)
      elsif value.is_a?(LinkedData::Client::Base)
        object[key] = value.id
      end
    end
    object
  end

  module Users
    def sign_in_as(username)
      user = fixtures(:users)[username]
      logged_in_user = LinkedData::Client::Models::User.authenticate(user.username, user.password)
      if logged_in_user && !logged_in_user.errors
        logged_in_user = create_user(user)
      end
      logged_in_user
    end

    def create_user(user, admin: false)
      admin_user = LinkedData::Client::Models::User.authenticate('admin', 'password') if admin
      existent_user = LinkedData::Client::Models::User.find_by_username(user.username).first

      existent_user.delete if existent_user

      values = user.to_h
      values[:role] = ["ADMINISTRATOR"] if admin
      existent_user = LinkedData::Client::Models::User.new(values: values)

      if admin
        # Overwrite the normal ".save" to accept creating admin user
        conn = Faraday.new(url: LinkedData::Client.settings.rest_url) do |faraday|
          faraday.request :url_encoded
          faraday.response :logger
          faraday.adapter Faraday.default_adapter
          faraday.headers = {
            "Accept" => "application/json",
            "Authorization" => "apikey token=#{admin_user.apikey}",
            "User-Agent" => "NCBO API Ruby Client v0.1.0"
          }

        end
        conn.post(existent_user.class.collection_path, existent_user.to_hash.to_json, 'Content-Type' => 'application/json')
      else
        existent_user.save
      end

      existent_user.password = user.password
      existent_user
    end

    def delete_users(users = LinkedData::Client::Models::User.all)
      Array(users).each do |o|
        LinkedData::Client::Models::Ontology.find_by_acronym(o.acronym).first&.delete
      end
    end

    def delete_user(user)
      LinkedData::Client::Models::User.find_by_username(user.username).first&.delete
    end
  end

  module Ontologies
    def create_ontology(ontology, submission)
      ontology = LinkedData::Client::Models::Ontology.new(values: ApplicationTestHelpers.transform_models_to_ids(ontology).to_h).save
      if ontology.errors
        puts "Ontology creation error: #{ontology.errors}"
        delete_ontologies([ontology])
        ontology = LinkedData::Client::Models::Ontology.new(values: ApplicationTestHelpers.transform_models_to_ids(ontology).to_h).save
      end
      submission[:ontology] = ontology.id
      submission.curatedOn = nil # TODO fix the curatedOn not saving
      submission.naturalLanguage = Array(submission.naturalLanguage).map{|x| x.gsub('iso639-1','iso639-3')}
      submission = LinkedData::Client::Models::OntologySubmission.new(values: ApplicationTestHelpers.transform_models_to_ids(submission).to_h).save
      [ontology, submission]
    end

    def delete_ontologies(ontologies = @ontologies)
      Array(ontologies).each do |o|
        next unless o.acronym
        LinkedData::Client::Models::Ontology.find_by_acronym(o.acronym).first&.delete
      end
    end
  end

  module Categories
    def create_category(category)
      created = LinkedData::Client::Models::Category.new(values: category.to_h).save
      return LinkedData::Client::Models::Category.find_by_acronym(category.acronym).first if created.errors
      created
    end

    def create_categories(categories_data = fixtures(:categories))
      @categories = []
      categories_data.to_a.each do |name, category|
        @categories << create_category(category)
      end
      @categories
    end

    def delete_categories(categories = LinkedData::Client::Models::Category.all)
      Array(categories).each { |g| g.delete }
    end
  end

  module Groups
    def create_group(group)
      created = LinkedData::Client::Models::Group.new(values: group.to_h).save
      return  LinkedData::Client::Models::Group.find_by_acronym(group.acronym).first if created.errors
      created
    end

    def create_groups(groups_data = fixtures(:groups))
      @groups = []
      groups_data.to_a.each do |name, group|
        @groups << create_group(group)
      end
      @groups
    end

    def delete_groups(groups = LinkedData::Client::Models::Group.all)
      Array(groups).each { |g| g.delete }
    end
  end

  module Agents
    def delete_agents(agents = LinkedData::Client::Models::Agent.all)
      Array(agents).each { |g| g.delete }
    end
  end
end