# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Packages::CreateAuditEventService, feature_category: :package_registry do
  let_it_be(:project) { build_stubbed(:project, group: build_stubbed(:group)) }
  let_it_be(:user) { build_stubbed(:user) }
  let_it_be(:package) { build_stubbed(:generic_package, project: project, creator: user) }
  let_it_be(:deploy_token) { build_stubbed(:deploy_token) }

  let(:service) { described_class.new(package) }

  describe '#execute' do
    subject(:execute) { service.execute }

    include_examples 'audit event logging' do
      let(:operation) { execute }
      let(:event_type) { 'package_registry_package_published' }
      let(:fail_condition!) { stub_feature_flags(package_registry_audit_events: false) }
      let(:attributes) do
        {
          author_id: user.id,
          entity_id: project.group.id,
          entity_type: 'Group',
          details: {
            author_name: user.name,
            event_name: 'package_registry_package_published',
            target_id: package.id,
            target_type: package.class.name,
            target_details: "#{project.full_path}/#{package.name}-#{package.version}",
            author_class: user.class.name,
            custom_message: "#{package.package_type.humanize} package published",
            auth_token_type: 'PersonalAccessToken or CiJobToken'
          }
        }
      end
    end

    context 'when project does not belong to a group' do
      before do
        project.group = nil
      end

      it 'uses project as scope' do
        expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
          hash_including(scope: project)
        )

        execute
      end
    end

    context 'for auth token type detection' do
      context 'when Current.token_info is present' do
        before do
          allow(::Current).to receive(:token_info).and_return({ token_type: 'SomeToken' })
        end

        it 'uses token type from Current' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: { auth_token_type: 'SomeToken' })
          )

          execute
        end
      end

      context 'when package has no creator' do
        before do
          allow(package).to receive(:creator).and_return(nil)
        end

        it 'uses DeployTokenAuthor as author' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(
              author: kind_of(::Gitlab::Audit::DeployTokenAuthor),
              additional_details: { auth_token_type: 'DeployToken' }
            )
          )

          execute
        end
      end

      context 'when package has a creator' do
        it 'sets auth_token_type as PersonalAccessToken or CiJobToken' do
          expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
            hash_including(additional_details: { auth_token_type: 'PersonalAccessToken or CiJobToken' })
          )

          execute
        end

        context 'when user is from ci job token' do
          before do
            allow(user).to receive(:from_ci_job_token?).and_return(true)
          end

          it 'sets auth_token_type as CiJobToken' do
            expect(::Gitlab::Audit::Auditor).to receive(:audit).with(
              hash_including(additional_details: { auth_token_type: 'CiJobToken' })
            )

            execute
          end
        end
      end
    end
  end
end
