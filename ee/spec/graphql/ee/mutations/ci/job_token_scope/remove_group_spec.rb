# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::Ci::JobTokenScope::RemoveGroup, feature_category: :continuous_integration do
  include GraphqlHelpers

  describe '#resolve' do
    let(:project) do
      create(:project, ci_outbound_job_token_scope_enabled: true)
    end

    let(:target_group) { create(:group) }

    let!(:link) do
      create(:ci_job_token_group_scope_link,
        source_project: project,
        target_group: target_group)
    end

    let(:links_relation) { Ci::JobToken::GroupScopeLink.with_source(project).with_target(target_group) }

    let(:target_group_path) { target_group.full_path }
    let(:project_path) { project.full_path }
    let(:input) { { project_path: project.full_path, target_group_path: target_group_path } }
    let(:current_user) { create(:user) }

    let(:expected_audit_context) do
      {
        name: event_name,
        author: current_user,
        scope: project,
        target: target_group,
        message: expected_audit_message
      }
    end

    let(:call_remove_group) do
      ctx = { current_user: current_user }
      mutation = graphql_mutation(described_class, input)
      GitlabSchema.execute(mutation.query, context: ctx, variables: mutation.variables).to_h
    end

    context 'when removing group validate it triggers audits' do
      before do
        project.add_maintainer(current_user)
        target_group.add_guest(current_user)
      end

      context 'when user removes target group to the job token scope' do
        let(:expected_audit_message) do
          "Group #{target_group_path} was removed from list of allowed groups for #{project_path}"
        end

        let(:event_name) { 'secure_ci_job_token_group_removed' }

        let(:service) do
          instance_double('Ci::JobTokenScope::RemoveGroupService')
        end

        it 'logs an audit event' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(expected_audit_context))

          call_remove_group
        end

        context 'and service returns an error' do
          let(:mutation_args) do
            { project_path: project.full_path, target_group_path: target_group_path }
          end

          it 'does not log an audit event' do
            expect_next_instance_of(::Ci::JobTokenScope::RemoveGroupService) do |service|
              expect(service)
                .to receive(:validate_group_remove!)
              .and_raise(::Ci::JobTokenScope::EditScopeValidations::ValidationError)
            end

            expect(::Gitlab::Audit::Auditor).not_to receive(:audit)

            call_remove_group
          end
        end
      end
    end
  end
end
