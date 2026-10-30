# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class ClassTreePathsTest < ActiveSupport::TestCase
  setup do
    @controller = ApplicationController.new
    @root = concept('http://purl.obolibrary.org/obo/CL_0000000')
    @child = concept('http://example.org/child')
  end

  test 'a selected display root needs no ancestor API requests' do
    unexpected_request = ->(*) { flunk 'A display root already has a complete path' }

    LinkedData::Client::HTTP.stub(:get, unexpected_request) do
      tree = @controller.paths_to_root_tree(@root, 'en', [@root])

      assert_equal [@root.id], tree.map(&:id)
      assert_empty tree.first.children
      refute tree.first.hasChildren
      assert @root.hasChildren, 'Building the paths tree must not mutate the source class'
    end
  end

  test 'an API server error falls back to parent links' do
    with_server_error do
      @child.stub(:explore, Struct.new(:parents).new([@root])) do
        paths = @controller.concept_paths_to_root(@child, 'en', [@root])

        assert_equal [[@root, @child]], paths
      end
    end
  end

  test 'ordinary request errors still fall back to parent links' do
    LinkedData::Client::HTTP.stub(:get, ->(*) { raise StandardError, 'Request failed' }) do
      @child.stub(:explore, Struct.new(:parents).new([@root])) do
        assert_equal [[@root, @child]], @controller.concept_paths_to_root(@child, 'en', [@root])
      end
    end
  end

  test 'a server error on the parents endpoint does not crash the tree' do
    with_server_error do
      assert_equal [[@child]], @controller.build_paths_via_parents(@child, [@root.id])
    end
  end

  test 'successful endpoint paths are preserved' do
    paths = [[@root, @child]]
    LinkedData::Client::HTTP.stub(:get, paths) do
      assert_equal paths, @controller.concept_paths_to_root(@child, 'en', [@root])
    end
  end

  test 'paths requests do not swallow process interruption or exit' do
    [Interrupt, SystemExit].each do |error_class|
      LinkedData::Client::HTTP.stub(:get, ->(*) { raise error_class }) do
        assert_raises(error_class) { @controller.concept_paths_to_root(@child, 'en', [@root]) }
      end
    end
  end

  test 'parents requests do not swallow process interruption or exit' do
    [Interrupt, SystemExit].each do |error_class|
      LinkedData::Client::HTTP.stub(:get, ->(*) { raise error_class }) do
        assert_raises(error_class) { @controller.build_paths_via_parents(@child, [@root.id]) }
      end
    end
  end

  private

  def concept(id)
    LinkedData::Client::Models::Class.new(values: {
      id: id, prefLabel: id, hasChildren: true,
      links: { 'self' => id, 'parents' => "#{id}/parents" }
    })
  end

  # Exercise the pinned client's real HTTP.get, which raises Exception (not
  # StandardError) for a server response with status >= 500. No network is used.
  def with_server_error
    response = Struct.new(:status, :body).new(500, '<h1>Internal Server Error</h1>')
    transport = Object.new
    transport.define_singleton_method(:get) { |&block| response }

    LinkedData::Client::HTTP.stub(:conn, transport) { yield }
  end
end
