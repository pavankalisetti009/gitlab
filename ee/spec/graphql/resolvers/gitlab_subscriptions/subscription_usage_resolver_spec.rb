# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::GitlabSubscriptions::SubscriptionUsageResolver, feature_category: :consumables_cost_management do
  include GraphqlHelpers

  let_it_be(:admin) { create(:admin) }
  let_it_be(:user) { create(:user) }
  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:project_namespace) { create(:project_namespace) }
  let(:current_user) { user }
  let(:args) { { namespace_path: nil } }

  subject(:result) { resolve(described_class, args: args, ctx: { current_user: current_user }) }

  describe '#resolve' do
    before do
      stub_feature_flags(usage_billing_dev: true)
    end

    context 'when in Self-Managed', :enable_admin_mode do
      context 'with admin user' do
        let(:current_user) { admin }

        context 'when feature flag is enabled' do
          it 'returns subscription usage for instance' do
            expect(result).to be_a(GitlabSubscriptions::SubscriptionUsage)
            expect(result.subscription_target).to eq(:instance)
            expect(result.namespace).to be_nil
          end
        end

        context 'when feature flag is disabled' do
          before do
            stub_feature_flags(usage_billing_dev: false)
          end

          it 'raises resource not available error' do
            expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end

      context 'with non-admin user' do
        it 'raises resource not available error' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when in GitLab.com' do
      let(:current_user) { user }

      context 'with root group' do
        let(:args) { { namespace_path: root_group.full_path } }

        context 'when user is group owner' do
          before_all do
            root_group.add_owner(user)
          end

          context 'when feature flag is enabled' do
            it 'returns subscription usage for namespace' do
              expect(result).to be_a(GitlabSubscriptions::SubscriptionUsage)
              expect(result.subscription_target).to eq(:namespace)
              expect(result.namespace).to eq(root_group)
            end
          end

          context 'when feature flag is disabled' do
            before do
              stub_feature_flags(usage_billing_dev: false)
            end

            it 'raises resource not available error' do
              expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
            end
          end
        end

        context 'when user is not group owner' do
          before_all do
            root_group.add_maintainer(user)
          end

          it 'raises resource not available error' do
            expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
          end
        end
      end

      context 'with subgroup' do
        let(:args) { { namespace_path: subgroup.full_path } }

        before_all do
          subgroup.add_owner(user)
        end

        it 'raises resource not available error with specific message' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
          expect(result.message).to be("Subscription usage can only be queried on a root namespace")
        end
      end

      context 'with project namespace' do
        let(:args) { { namespace_path: project_namespace.full_path } }

        before_all do
          project_namespace.project.add_owner(user)
        end

        it 'raises resource not available error' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'with non-existent namespace' do
        let(:args) { { namespace_path: 'non-existent-namespace' } }

        it 'raises resource not available error' do
          expect(result).to be_a(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end
  end
end
