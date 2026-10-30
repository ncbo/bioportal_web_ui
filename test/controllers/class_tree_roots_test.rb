# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ClassTreeRootsTest < ActiveSupport::TestCase
  setup do
    @controller = ApplicationController.new
    @declared = %w[anatomical_entity life_cycle life_cycle_stage temporal_boundary].map { |id| concept(id) }
    @selected = concept('selected_child')
    @expanded = concept('anatomical_entity', [@selected])
    @structural = [concept('structural_root', [@expanded, concept('temporal_boundary')])]
  end

  test 'switching back from full hierarchy restores every preferred root' do
    show_selected_class(tree_roots: 'full')
    assert_equal ['structural_root'], tree.map(&:id)

    show_selected_class
    assert_equal @declared.map(&:id).sort, tree.map(&:id).sort
    assert_same @expanded, tree.find { |root| root.id == @expanded.id }
    assert_equal [@selected], tree.find { |root| root.id == @expanded.id }.children

    %w[life_cycle life_cycle_stage].each do |id|
      root = tree.find { |node| node.id == id }
      assert_empty root.children
      assert root.hasChildren, 'Missing preferred roots must remain expandable'
    end
  end

  test 'a direct visit to a selected class retains every preferred root' do
    show_selected_class

    assert_equal @declared.map(&:id).sort, tree.map(&:id).sort
  end

  test 'parent paths mode does not add unrelated preferred roots' do
    @controller.stub(:paths_to_root_tree, [@expanded]) do
      show_selected_class(tree_mode: 'paths')
    end

    assert_equal [@expanded], tree
  end

  test 'a path above all declared roots is kept unchanged' do
    @structural = [concept('upper_class')]
    show_selected_class

    assert_equal @structural, tree
  end

  test 'ontologies without declared roots keep their structural tree' do
    @declared = []
    show_selected_class

    assert_equal @structural, tree
  end

  test 'adding missing roots does not alter resolved root objects' do
    original_children = @declared.map(&:children)
    show_selected_class

    assert_equal original_children, @declared.map(&:children)
    assert @declared.all?(&:hasChildren)
  end

  private

  def concept(id, children = [])
    LinkedData::Client::Models::Class.new(values: {
      id: id, prefLabel: id, children: children, hasChildren: true
    })
  end

  def tree
    @controller.instance_variable_get(:@root).children
  end

  # Exercise get_class's mode selection with API responses supplied in memory.
  def show_selected_class(**params)
    ontology_explorer = Object.new
    selected = @selected
    ontology_explorer.define_singleton_method(:single_class) { |*| selected }
    ontology = Struct.new(:explore).new(ontology_explorer)
    ontology.define_singleton_method(:flat?) { false }
    helpers = Object.new
    helpers.define_singleton_method(:request_lang) { |_| 'en' }
    selected_explorer = Object.new
    structural = @structural
    selected_explorer.define_singleton_method(:tree) { |*| structural }
    @controller.instance_variable_set(:@ontology, ontology)

    @controller.stub(:helpers, helpers) do
      @controller.stub(:declared_root_classes, @declared) do
        @selected.stub(:explore, selected_explorer) do
          @controller.get_class({ conceptid: @selected.id }.merge(params), nil)
        end
      end
    end
  end
end
