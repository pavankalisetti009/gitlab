# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::EnablementCheckService, type: :service, feature_category: :duo_agent_platform do
  let_it_be_with_reload(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  describe '#execute' do
    subject(:result) { described_class.new(project: project, current_user: user).execute }

    it { is_expected.to be_nil }

    context "when user has developer access" do
      before_all do
        project.add_developer(user)
      end

      it { is_expected.not_to be_nil }

      it 'includes remote_flows_enabled in the response' do
        expect(result).to have_key(:remote_flows_enabled)
      end

      context 'when duo_workflow licensed feature is available' do
        before do
          allow(::Gitlab::Llm::StageCheck).to receive(:available?).and_return(true)
          # rubocop:disable RSpec/AnyInstanceOf -- not the next instance
          allow_any_instance_of(User).to receive(:allowed_to_use?).and_return(true)
          # rubocop:enable RSpec/AnyInstanceOf
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be_truthy
          expect(success_checks(result[:checks]))
            .to match_array([:developer_access, :duo_features_enabled, :feature_flag, :feature_available])
          expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
        end
      end

      context 'when duo_workflow feature flag is disabled' do
        before do
          stub_feature_flags(duo_workflow: false)
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be_falsey
          expect(success_checks(result[:checks])).to match_array([:developer_access, :duo_features_enabled])
          expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
        end
      end

      context 'when project has duo features disabled' do
        before do
          project.project_setting.update!(duo_features_enabled: false)
        end

        it "returns status and checks" do
          expect(result[:enabled]).to be_falsey
          expect(success_checks(result[:checks])).to match_array([:developer_access, :feature_flag])
          expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
        end
      end

      context 'when project has duo remote flows enabled' do
        before do
          allow(project).to receive(:duo_remote_flows_enabled).and_return(true)
        end

        it "returns remote_flows_enabled as true" do
          expect(result[:remote_flows_enabled]).to be_truthy
        end
      end

      context 'when project has duo remote flows disabled' do
        before do
          allow(project).to receive(:duo_remote_flows_enabled).and_return(false)
        end

        it "returns remote_flows_enabled as false" do
          expect(result[:remote_flows_enabled]).to be_falsey
        end
      end
    end

    context 'when user has guest access' do
      before_all do
        project.add_guest(user)
      end

      it "returns status and checks" do
        expect(result[:enabled]).to be_falsey
        expect(success_checks(result[:checks])).to match_array([:duo_features_enabled, :feature_flag])
        expect(result[:remote_flows_enabled]).to eq(project.duo_remote_flows_enabled)
      end
    end

    def success_checks(checks)
      checks.filter { |check| check[:value] }.pluck(:name)
    end
  end
end
