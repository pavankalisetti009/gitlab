# frozen_string_literal: true

module RemoteDevelopment
  # NOTE: These methods must be in a module, instead of directly in an RSpec shared context, because we
  #       need to call them from within FactoryBot factories
  module FixtureFileHelpers
    extend self # This makes the instance methods available as class methods, for use in FactoryBot factories

    # @param [String] filename
    # @param [String] project_name
    # @param [String] namespace_path
    # @return [String]
    def read_devfile_yaml(filename, project_name: "test-project", namespace_path: "test-group")
      erb_devfile_contents = File.read(Rails.root.join('ee/spec/fixtures/remote_development', filename).to_s)
      fixture_file_binding = FixtureFileErbBinding.new.get_fixture_file_binding
      devfile_contents = ERB.new(erb_devfile_contents).result(fixture_file_binding)
      devfile_contents.gsub!('http://localhost/', root_url)
      devfile_contents.gsub!('test-project', project_name)
      devfile_contents.gsub!('test-group', namespace_path)

      format_project_cloner_script!(devfile_contents, project_name: project_name, namespace_path: namespace_path)

      devfile_contents
    end

    # @return [String]
    def root_url
      # NOTE: Default to http://example.com/ if GitLab::Application is not defined. This allows this helper to be used
      #       from ee/spec/remote_development/fast_spec_helper.rb
      defined?(Gitlab::Application) ? Gitlab::Routing.url_helpers.root_url : "https://example.com/"
    end

    # @param [String] content
    # @param [String] project_name
    # @param [String] namespace_path
    # @return [void]
    def format_project_cloner_script!(
      content,
      project_name: "test-project",
      namespace_path: "test-group"
    )
      # NOTE: These replacements correspond to the `format` command in `project_cloner_component_inserter.rb`
      content.gsub!("%<project_cloning_successful_file>s", "/projects/.gl_project_cloning_successful")
      content.gsub!("%<project_ref>s", "master")
      content.gsub!("%<project_url>s", "#{root_url}#{namespace_path}/#{project_name}.git")
      content.gsub!("%<clone_dir>s", "/projects/#{project_name}")

      nil
    end
  end
end
