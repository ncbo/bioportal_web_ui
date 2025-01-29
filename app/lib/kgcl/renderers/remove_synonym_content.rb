# frozen_string_literal: true

module KGCL
  module Renderers
    # Generate GitHub issue content for a remove synonym change request
    #
    # The change request is formally described using the Knowledge Graph Change Language grammar, e.g.:
    #
    #   remove synonym 'terminal specialization' for GO:0044292
    #   remove synonym 'terminal specialization' @en for GO:0044292
    #
    # @see https://github.com/INCATools/kgcl KGCL documentation
    #
    class RemoveSynonymContent < IssueContent
      def comment
        @params[:remove_synonym][:comment]
      end

      def get_binding
        binding
      end

      def synonym_label
        @params[:remove_synonym][:synonym]
      end

      def title_template
        'remove_synonym_title.erb'
      end

      def body_template
        'remove_synonym_body.erb'
      end
    end
  end
end
