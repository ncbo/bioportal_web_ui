# frozen_string_literal: true

module KGCL
  module IssueContentGenerator
    RENDERERS = {
      KGCL::Operations::NEW_SYNONYM => KGCL::Renderers::NewSynonymContent,
      KGCL::Operations::NODE_OBSOLETION => KGCL::Renderers::NodeObsoletionContent,
      KGCL::Operations::NODE_RENAME => KGCL::Renderers::NodeRenameContent,
      KGCL::Operations::REMOVE_SYNONYM => KGCL::Renderers::RemoveSynonymContent,
      KGCL::Operations::TEXT_DEFINITION_REPLACEMENT => KGCL::Renderers::EditDefinitionContent
    }.freeze

    def self.call(params)
      operation = params[:operation]
      raise ArgumentError, "Invalid KGCL operation: #{operation}" unless RENDERERS.key?(operation)

      renderer = RENDERERS.fetch(operation)
      renderer.new(params).render
    end
  end
end
