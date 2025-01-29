# frozen_string_literal: true

module KGCL
  module Renderers
    # Generate GitHub issue content for a create synonym change request
    #
    # The change request is described using the Knowledge Graph Change Language grammar, e.g.:
    #
    #   create synonym 'single organism process' for 'GO:0008150'
    #   create synonym 'single organism process' @en for 'GO:0008150'
    #   create exact synonym 'single organism process' for 'GO:0008150'
    #
    # @see https://github.com/INCATools/kgcl KGCL documentation
    #
    class NewSynonymContent < IssueContent
      def comment
        @params[:create_synonym][:comment]
      end

      def get_binding
        binding
      end

      def qualifier
        @params[:create_synonym][:qualifier]
      end

      def synonym_label
        @params[:create_synonym][:preferred_label]
      end

      def title_template
        'new_synonym_title.erb'
      end

      def body_template
        'new_synonym_body.erb'
      end
    end
  end
end
