# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Create::MainComponentUpdater, feature_category: :workspaces do
  include_context 'with remote development shared fixtures'

  let(:input_processed_devfile_name) { 'example.tools-injector-inserted-devfile.yaml' }
  let(:input_processed_devfile) { YAML.safe_load(read_devfile(input_processed_devfile_name)).to_h }
  let(:expected_processed_devfile_name) { 'example.main-container-updated-devfile.yaml' }
  let(:expected_processed_devfile) { YAML.safe_load(read_devfile(expected_processed_devfile_name)).to_h }

  let(:vscode_extensions_gallery_metadata_enabled) { false }

  let(:context) do
    {
      processed_devfile: input_processed_devfile,
      volume_mounts: {
        data_volume: {
          path: "/projects"
        }
      },
      vscode_extensions_gallery_metadata: { enabled: vscode_extensions_gallery_metadata_enabled }
    }
  end

  subject(:returned_value) do
    described_class.update(context) # rubocop:disable Rails/SaveBang -- Silly rubocop, this isn't an ActiveRecord object
  end

  it 'updates the main component' do
    expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
  end

  context "when vscode_extensions_gallery_metadata Web IDE setting is disabled" do
    let(:expected_processed_devfile_name) { 'example.main-container-updated-marketplace-disabled-devfile.yaml' }
    let(:vscode_extensions_gallery_metadata_enabled) { false }

    it 'injects the tools injector component' do
      expect(returned_value[:processed_devfile]).to eq(expected_processed_devfile)
    end
  end
end
