# frozen_string_literal: true

RSpec.shared_examples 'disabled virtual_registry feature flag' do |registry_type, status: :unauthorized|
  before do
    feature_flag = registry_type == :container ? :container_virtual_registries : :"#{registry_type}_virtual_registry"
    stub_feature_flags(feature_flag => false)
  end

  it_behaves_like 'returning response status', status
end

RSpec.shared_examples 'virtual registry disabled dependency proxy' do
  before do
    stub_config(dependency_proxy: { enabled: false })
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'virtual registry not authenticated user' do
  let(:headers) { {} }

  it_behaves_like 'returning response status', :unauthorized
end

RSpec.shared_examples 'maven virtual registry feature not licensed' do
  before do
    stub_licensed_features(packages_virtual_registry: false)
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'virtual registries setting enabled is false' do
  before do
    allow(VirtualRegistries::Setting).to receive(:find_for_group).with(group).and_return(build_stubbed(
      :virtual_registries_setting, :disabled, group: group))
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'an authenticated virtual registry REST API' do |with_successful_status: :ok|
  using RSpec::Parameterized::TableSyntax

  where(:token, :sent_as, :status) do
    :personal_access_token | :header        | with_successful_status
    :personal_access_token | :bearer_header | with_successful_status
    :personal_access_token | :query_param   | with_successful_status

    :job_token             | :header        | with_successful_status
    :job_token             | :query_param   | with_successful_status

    :oauth_token           | :bearer_header | with_successful_status
    :oauth_token           | :query_param   | with_successful_status

    :deploy_token          | :header        | :unauthorized
  end

  with_them do
    let(:headers) { token_header(token, sent_as: sent_as) }
    let(:url) do
      base_url = super()
      base_url += "?#{token_query_param(token).to_query}" if sent_as == :query_param
      base_url
    end

    it_behaves_like 'returning response status', params[:status]
  end
end

RSpec.shared_examples 'container virtual registry feature not licensed' do
  before do
    stub_licensed_features(container_virtual_registry: false)
  end

  it_behaves_like 'returning response status', :not_found
end

RSpec.shared_examples 'virtual registry not available' do |registry_type|
  it_behaves_like 'virtual registry disabled dependency proxy'
  it_behaves_like 'virtual registry not authenticated user'
  it_behaves_like 'virtual registries setting enabled is false'
  it_behaves_like "#{registry_type} virtual registry feature not licensed"
  it_behaves_like 'disabled virtual_registry feature flag', registry_type
end
