# frozen_string_literal: true

RSpec.shared_examples 'work item mutation with status widget with error' do
  it 'does not update work item and raises error' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect(graphql_errors).not_to be_empty
    expect_graphql_errors_to_include(expected_error_message)
  end
end

RSpec.shared_examples 'successful work item mutation with status widget' do
  it 'has current status with system defined status' do
    post_graphql_mutation(mutation, current_user: current_user)

    expect(response).to have_gitlab_http_status(:success)
    expect_graphql_errors_to_be_empty

    work_item_id = GlobalID.parse(mutation_response['workItem']['id']).model_id.to_i

    expect(::WorkItems::Statuses::CurrentStatus.last).to have_attributes(
      work_item_id: work_item_id,
      system_defined_status_id: status_id,
      custom_status_id: nil
    )
  end
end

RSpec.shared_examples 'work item status widget mutation rejects invalid inputs' do
  context 'when status gid references non-existing system-defined status' do
    let(:status_gid) { 'gid://gitlab/WorkItems::Statuses::SystemDefined::Status/99' }
    let(:expected_error_message) { "System-defined status doesn't exist." }

    it_behaves_like 'work item mutation with status widget with error'
  end

  context 'when work_item_status_feature_flag feature flag is disabled' do
    before do
      stub_feature_flags(work_item_status_feature_flag: false)
    end

    it_behaves_like 'work item mutation with status widget with error'
  end
end
