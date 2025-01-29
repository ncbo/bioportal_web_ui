# frozen_string_literal: true

module KGCL
  module Renderers
    # Base class for generating GitHub issue content for ontology change requests
    class IssueContent
      attr_reader :params

      def initialize(params)
        @params = params
      end

      def render
        tr = KGCL::TemplateRenderer.new(
          title_template: title_template,
          body_template: body_template,
          bind_klass: self
        )
        tr.render
      end

      def concept_id
        @params[:concept_id]
      end

      def concept_label
        @params[:concept_label]
      end

      def curie
        @params[:curie]
      end

      def github_id
        @params[:github_id]
      end

      def orcid_id
        @params[:orcid_id]
      end

      def username
        @params[:username]
      end

      # These methods should be defined in subclasses to provide unique templates
      def title_template
        raise NotImplementedError, 'Subclasses must define a title_template'
      end

      def body_template
        raise NotImplementedError, 'Subclasses must define a body_template'
      end
    end
  end
end
