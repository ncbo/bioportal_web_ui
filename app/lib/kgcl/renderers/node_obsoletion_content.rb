# frozen_string_literal: true

module KGCL
  module Renderers
    # Generate GitHub issue content for a node obsoletion change request. The change request is described using the
    # Knowledge Graph Change Language grammar, e.g.:
    #
    #   obsolete GO:0008150
    #
    # @see https://github.com/INCATools/kgcl KGCL documentation
    #
    class NodeObsoletionContent < IssueContent
      def comment
        @params[:node_obsoletion][:comment]
      end

      def get_binding
        binding
      end

      def title_template
        'node_obsoletion_title.erb'
      end

      def body_template
        'node_obsoletion_body.erb'
      end
    end
  end
end
