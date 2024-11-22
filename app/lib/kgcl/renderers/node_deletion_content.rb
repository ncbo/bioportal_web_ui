# frozen_string_literal: true

module KGCL
  module Renderers
    # Generate GitHub issue content for a node deletion change request. The change request is described using the
    # Knowledge Graph Change Language grammar, e.g.:
    #
    #   delete GO:0008150
    #
    # @see https://incatools.github.io/kgcl/NodeDeletion/ NodeDeletion documentation
    #
    class NodeDeletionContent < IssueContent
      def comment
        @params[:node_deletion][:comment]
      end

      def get_binding
        binding
      end

      def title_template
        'node_deletion_title.erb'
      end

      def body_template
        'node_deletion_body.erb'
      end
    end
  end
end
