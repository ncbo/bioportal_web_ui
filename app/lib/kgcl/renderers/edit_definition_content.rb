# frozen_string_literal: true

module KGCL
  module Renderers
    # Generate GitHub issue content for a text definition replacement change request.
    #
    # The change request is described using the Knowledge Graph Change Language grammar, e.g.:
    #
    #   change definition of GO:0008150 from 'lorem ipsum' to 'lorem ipsum dolor sit amet'
    #
    # @see https://incatools.github.io/kgcl/TextDefinitionReplacement
    #
    class EditDefinitionContent < IssueContent
      def comment
        @params[:edit_definition][:comment]
      end

      def get_binding
        binding
      end

      def new_definition
        @params[:edit_definition][:definition]
      end

      def old_definition
        @params[:old_definition]
      end

      def title_template
        'edit_definition_title.erb'
      end

      def body_template
        'edit_definition_body.erb'
      end
    end
  end
end
