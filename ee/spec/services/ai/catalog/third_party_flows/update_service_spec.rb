# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ThirdPartyFlows::UpdateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:item) { create(:ai_catalog_item, :third_party_flow, public: false, project: project) }
  let_it_be_with_reload(:latest_released_version) do
    create(:ai_catalog_item_version, :for_third_party_flow, :released, version: '1.0.0', item: item)
  end

  let_it_be_with_reload(:latest_version) do
    create(:ai_catalog_item_version, :for_third_party_flow, version: '1.1.0', item: item)
  end

  let(:params) do
    {
      item: item,
      name: "New name",
      description: "New description",
      public: true,
      release: true,
      definition: <<-YAML
      injectGatewayToken: false
      image: example/new_image:latest
      commands:
        - /bin/newcmd
      variables:
        - NEWVAR1
      YAML
    }
  end

  let(:service) { described_class.new(project: project, current_user: user, params: params) }

  before do
    enable_ai_catalog
  end

  it_behaves_like Ai::Catalog::Items::BaseUpdateService do
    let(:item_schema_version) { Ai::Catalog::ItemVersion::AGENT_SCHEMA_VERSION }
    let(:expected_updated_definition) do
      {
        'injectGatewayToken' => false,
        'image' => 'example/new_image:latest',
        'commands' => ['/bin/newcmd'],
        'variables' => ['NEWVAR1'],
        'yaml_definition' => params[:definition]
      }
    end

    context 'when user has permissions' do
      before_all do
        project.add_maintainer(user)
      end

      context 'when item is not an third_party_flow' do
        before do
          allow(item).to receive(:third_party_flow?).and_return(false)
        end

        it_behaves_like 'an error response', 'ThirdPartyFlow not found'
      end

      context 'when ai_catalog_third_party_flows feature flag is disabled' do
        before do
          stub_feature_flags(ai_catalog_third_party_flows: false)
        end

        it_behaves_like 'an error response', 'You have insufficient permissions'
      end

      context 'when YAML is not valid' do
        let(:params) { super().merge(definition: "this: is\n - not\n yaml: true") }

        it 'handles invalid yaml' do
          response = service.execute

          expect(response).to be_error

          expect(response.message)
            .to contain_exactly("ThirdPartyFlow definition does not have a valid YAML syntax")
        end
      end
    end
  end
end
