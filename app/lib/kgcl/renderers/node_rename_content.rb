# frozen_string_literal: true

module KGCL
  module Renderers
    # Generate GitHub issue content for a node rename change request. The change request is described using the
    # Knowledge Graph Change Language grammar, e.g.:
    #
    #   rename MONDO:0000087 from 'polymicrogyria' to 'polymicrogyria ABCD'
    #
    # @see https://github.com/INCATools/kgcl KGCL documentation
    #
    class NodeRenameContent < IssueContent
      def comment
        @params[:node_rename][:comment]
      end

      def get_binding
        binding
      end

      def new_concept_label
        @params[:node_rename][:new_preferred_name]
      end

      def title_template
        'node_rename_title.erb'
      end

      def body_template
        'node_rename_body.erb'
      end
    end
  end
end
