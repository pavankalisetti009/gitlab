# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.project(fullPath).dependencies', feature_category: :dependency_management do
  include ApiHelpers
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user, developer_of: project) }
  let_it_be(:variables) { { full_path: project.full_path } }
  let_it_be(:fields) do
    <<~FIELDS
      id
      name
      version
      componentVersion {
        id
        version
      }
      packager
      location {
        blobPath
        path
      }
      licenses {
        name
        spdxIdentifier
        url
      }
    FIELDS
  end

  let(:query) { pagination_query }

  let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project) }
  let(:nodes_path) { %i[project dependencies nodes] }

  def pagination_query(params = {})
    nodes = query_nodes(:dependencies, fields, include_pagination_info: true, args: params)
    graphql_query_for(:project, variables, nodes)
  end

  def package_manager_enum(value)
    Types::Sbom::PackageManagerEnum.values.find { |_, custom_value| custom_value.value == value }.first
  end

  before do
    stub_licensed_features(dependency_scanning: true)
  end

  subject { post_graphql(query, current_user: current_user, variables: variables) }

  context 'with quarantine', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/545088' do
    it_behaves_like 'sbom dependency node'
  end

  it 'returns the expected dependency data with all fields' do
    subject

    actual = graphql_data_at(:project, :dependencies, :nodes)
    expected = occurrences.map do |occurrence|
      {
        'id' => occurrence.to_gid.to_s,
        'name' => occurrence.name,
        'version' => occurrence.version,
        'componentVersion' => {
          'id' => occurrence.component_version.to_gid.to_s,
          'version' => occurrence.component_version.version
        },
        'packager' => package_manager_enum(occurrence.packager),
        'location' => {
          'blobPath' => "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.source.input_file_path}",
          'path' => occurrence.source.input_file_path
        },
        'licenses' => occurrence.licenses.map do |license|
          {
            'name' => license['name'],
            'spdxIdentifier' => license['spdx_identifier'],
            'url' => license['url']
          }
        end
      }
    end

    expect(actual).to match_array(expected)
  end

  it_behaves_like 'when dependencies graphql query sorted paginated'
  it_behaves_like 'when dependencies graphql query sorted by license'

  context 'when dependencies have no source data' do
    let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project, source: nil) }

    it 'returns nil for data which originates from a source' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      expected = occurrences.map do |occurrence|
        {
          'id' => occurrence.to_gid.to_s,
          'name' => occurrence.name,
          'version' => occurrence.version,
          'componentVersion' => {
            'id' => occurrence.component_version.to_gid.to_s,
            'version' => occurrence.component_version.version
          },
          'packager' => nil,
          'location' => {
            'blobPath' => nil,
            'path' => nil
          },
          'licenses' => occurrence.licenses.map do |license|
            {
              'name' => license['name'],
              'spdxIdentifier' => license['spdx_identifier'],
              'url' => license['url']
            }
          end
        }
      end

      expect(actual).to match_array(expected)
    end
  end

  context 'when dependencies have no version data' do
    let!(:occurrences) { create_list(:sbom_occurrence, 5, project: project, component_version: nil) }

    it 'returns a nil version' do
      subject

      actual = graphql_data_at(:project, :dependencies, :nodes)
      expected = occurrences.map do |occurrence|
        {
          'id' => occurrence.to_gid.to_s,
          'name' => occurrence.name,
          'version' => nil,
          'componentVersion' => nil,
          'packager' => package_manager_enum(occurrence.packager),
          'location' => {
            'blobPath' => "/#{project.full_path}/-/blob/#{occurrence.commit_sha}/#{occurrence.source.input_file_path}",
            'path' => occurrence.source.input_file_path
          },
          'licenses' => occurrence.licenses.map do |license|
            {
              'name' => license['name'],
              'spdxIdentifier' => license['spdx_identifier'],
              'url' => license['url']
            }
          end
        }
      end

      expect(actual).to match_array(expected)
    end
  end

  describe "hasDependencyPaths field" do
    let_it_be(:fields) do
      <<~FIELDS
        hasDependencyPaths
      FIELDS
    end

    it 'avoids N+1 database queries', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/567758' do
      parent = occurrences.first

      # create 1 occurrence and 1 graph path
      occ = create(:sbom_occurrence, project: project)
      create(:sbom_graph_path, descendant: occ, ancestor: parent, project: project)

      # capture control query count the current set of occurrences
      post_graphql(query, current_user: current_user, variables: variables)
      control_count = ActiveRecord::QueryRecorder.new do
        post_graphql(query, current_user: current_user, variables: variables)
      end.count

      # create multiple occurrences
      occurrence_list = create_list(:sbom_occurrence, 5, project: project)
      occurrence_list.each do |occ|
        create(:sbom_graph_path, descendant: occ, ancestor: parent, project: project)
      end

      expect do
        post_graphql(query, current_user: current_user, variables: variables)
      end.not_to exceed_query_limit(control_count)
    end
  end

  it_behaves_like 'when dependencies graphql query filtered by component name'
  it_behaves_like 'when dependencies graphql query filtered by source type'
  it_behaves_like 'when dependencies graphql query sorted by severity'
  it_behaves_like 'when dependencies graphql query filtered by component versions'
  it_behaves_like 'when dependencies graphql query filtered by not component versions'
end
