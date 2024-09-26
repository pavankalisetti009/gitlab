# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Utils::UserAuthorizer, feature_category: :ai_abstraction_layer do
  describe '#allowed?' do
    subject { described_class.new(user, project, feature_name).allowed? }

    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user) }
    let(:feature_name) { :resolve_vulnerability }
    let(:cloud_connector_free_access) { true }
    let(:cloud_connector_user_access) { false }
    let(:feature_authorizer) { instance_double(::Gitlab::Llm::FeatureAuthorizer) }

    before_all do
      project.add_developer(user)
    end

    context 'when user is present' do
      before do
        stub_licensed_features(ai_features: true)
        allow(::CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
          :free_access?).and_return(cloud_connector_free_access)
        allow(::CloudConnector::AvailableServices).to receive_message_chain(:find_by_name,
          :allowed_for?).and_return(cloud_connector_user_access)
        allow(::Gitlab::Llm::FeatureAuthorizer).to receive(:new).and_return(feature_authorizer)
      end

      context 'when feature is authorized' do
        before do
          allow(feature_authorizer).to receive(:allowed?).and_return(true)
        end

        it { is_expected.to be true }

        context 'when feature is not licensed' do
          before do
            stub_licensed_features(ai_features: false)
          end

          it { is_expected.to be false }
        end

        describe 'cloud connector' do
          using RSpec::Parameterized::TableSyntax
          where(:free_access, :user_access, :allowed) do
            true  | true  | true
            true  | false | true
            false | true  | true
            false | false | false
          end

          with_them do
            let(:cloud_connector_free_access) { free_access }
            let(:cloud_connector_user_access) { user_access }

            it { is_expected.to be allowed }
          end
        end

        context 'when on .org or .com', :saas do
          using RSpec::Parameterized::TableSyntax
          where(:group_with_ai_membership, :free_access, :user_access, :allowed) do
            true  | true   | true  | true
            true  | false  | true  | true
            false | false  | true  | true
            false | false  | false | false
            true  | true   | false | true
            false | true   | false | false
          end

          with_them do
            before do
              allow(user).to receive(:any_group_with_ga_ai_available?).and_return(group_with_ai_membership)
            end

            let(:cloud_connector_free_access) { free_access }
            let(:cloud_connector_user_access) { user_access }

            it { is_expected.to be allowed }
          end
        end
      end

      context 'when feature is not authorized' do
        before do
          allow(feature_authorizer).to receive(:allowed?).and_return(false)
        end

        it { is_expected.to be false }
      end
    end

    context 'when user is not present' do
      let_it_be(:user) { nil }

      it { is_expected.to be false }
    end
  end
end
