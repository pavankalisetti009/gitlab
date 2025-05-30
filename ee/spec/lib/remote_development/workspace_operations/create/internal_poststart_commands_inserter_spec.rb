# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::InternalPoststartCommandsInserter, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile) do
    read_devfile("example.main-container-updated-devfile.yaml.erb")
  end

  let(:expected_processed_devfile_name) { "example.internal-poststart-commands-inserted-devfile.yaml.erb" }
  let(:expected_processed_devfile) { read_devfile(expected_processed_devfile_name) }

  let(:project_path) { "test-project" }
  let(:project) do
    http_url_to_repo = "#{root_url}test-group/#{project_path}.git"
    instance_double("Project", path: project_path, http_url_to_repo: http_url_to_repo) # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
  end

  let(:context) do
    {
      params: {
        project: project,
        project_ref: "master"
      },
      processed_devfile: input_processed_devfile,
      tools_dir: "#{workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH}/" \
        "#{create_constants_module::TOOLS_DIR_NAME}",
      volume_mounts: {
        data_volume: {
          path: workspace_operations_constants_module::WORKSPACE_DATA_VOLUME_PATH
        }
      }
    }
  end

  subject(:returned_value) do
    described_class.insert(context)
  end

  it 'updates the devfile' do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end
end
