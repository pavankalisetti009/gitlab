# frozen_string_literal: true

require "spec_helper"

# rubocop:disable RSpec/ MultipleMemoizedHelpers -- this is a complex model, it requires many helpers for thorough testing
# noinspection RubyArgCount -- Rubymine detecting wrong types, it thinks some #create are from Minitest, not FactoryBot
# noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
RSpec.describe RemoteDevelopment::Workspace, :freeze_time, feature_category: :workspaces do
  let(:workspaces_agent_config_enabled) { true }
  let(:workspaces_per_user_quota) { 10 }
  let(:workspaces_quota) { 10 }
  let(:dns_zone) { "workspace.me" }
  let(:desired_state) { ::RemoteDevelopment::WorkspaceOperations::States::STOPPED }
  let(:actual_state) { ::RemoteDevelopment::WorkspaceOperations::States::STOPPED }

  let_it_be(:agent, reload: true) { create(:ee_cluster_agent) }
  let_it_be(:agent_config, reload: true) { create(:workspaces_agent_config, agent: agent) }
  let_it_be(:user) { create(:user) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }
  let_it_be(:project) { create(:project, :in_group) }

  subject(:workspace) do
    build(
      :workspace, user: user, agent: agent, project: project,
      personal_access_token: personal_access_token, desired_state: desired_state,
      actual_state: actual_state
    )
  end

  before do
    # Assign let variables to let_it_be fixtures, this must be done here in a before(:each), not in a
    # before(:context). let_it_be is implemented as a before(:context), so you can't use the let
    # declarations directly from within them.
    agent_config.update!(
      workspaces_per_user_quota: workspaces_per_user_quota,
      workspaces_quota: workspaces_quota,
      dns_zone: dns_zone,
      enabled: workspaces_agent_config_enabled
    )
  end

  describe "default values" do
    it "has correct default values" do
      expect(workspace.desired_config_generator_version).to eq(
        RemoteDevelopment::WorkspaceOperations::DesiredConfigGeneratorVersion::LATEST_VERSION
      )
    end
  end

  describe "associations" do
    context "for has_many" do
      it { is_expected.to have_many(:workspace_variables) }
    end

    context "for belongs_to" do
      it { is_expected.to belong_to(:user) }
      it { is_expected.to belong_to(:personal_access_token) }

      it do
        is_expected
          .to belong_to(:agent)
                .class_name("Clusters::Agent")
                .with_foreign_key(:cluster_agent_id)
                .inverse_of(:workspaces)
      end
    end

    context "when from factory" do
      before do
        # we need to save to save to allow some associations verified below to register the new workspace
        workspace.save!
      end

      it "has correct associations from factory" do
        expect(workspace.user).to eq(user)
        expect(workspace.project).to eq(project)
        expect(workspace.agent).to eq(agent)
        expect(workspace.personal_access_token).to eq(personal_access_token)
        expect(agent.unversioned_latest_workspaces_agent_config.workspaces.first).to eq(workspace)
        expect(workspace.url_prefix).to eq("60001-#{workspace.name}")
        expect(workspace.url_query_string).to eq("folder=dir%2Ffile")
      end

      it "has correct workspaces_agent_config associations from factory" do
        expect(workspace.workspaces_agent_config_version).to eq(agent_config.versions.size)
        expect(workspace.workspaces_agent_config).to eq(agent_config)
      end
    end
  end

  describe "callbacks" do
    describe "before_save" do
      describe "when creating new record" do
        it "sets desired_state_updated_at" do
          workspace.save!
          expect(workspace.desired_state_updated_at).to eq(Time.current)
        end

        it "sets actual_state_updated_at" do
          workspace.save!
          expect(workspace.actual_state_updated_at).to eq(Time.current)
        end
      end

      describe "when updating desired_state" do
        it "sets desired_state_updated_at" do
          # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
          expect { workspace.update!(desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING) }.to change {
            # rubocop:enable Layout/LineLength
            workspace.desired_state_updated_at
          }
        end
      end

      describe "when updating actual_state" do
        it "sets desired_state_updated_at" do
          # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
          expect { workspace.update!(actual_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING) }.to change {
            # rubocop:enable Layout/LineLength
            workspace.actual_state_updated_at
          }
        end
      end

      describe "when updating a field other than desired_state" do
        it "does not set desired_state_updated_at" do
          workspace.save!
          # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
          expect { workspace.update!(actual_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING) }.not_to change {
            # rubocop:enable Layout/LineLength
            workspace.desired_state_updated_at
          }
        end

        it "does not set actual_state_updated_at" do
          workspace.save!
          # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
          expect { workspace.update!(actual_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING) }.not_to change {
            # rubocop:enable Layout/LineLength
            workspace.actual_state_updated_at
          }
        end
      end
    end

    describe "before_validation" do
      context "on create" do
        context "when agent_config has more than 1 version" do
          before do
            agent_config.touch
          end

          it "sets workspaces_agent_config_version to number of versions" do
            # We are calling #valid? to exercise the `before_validation` callback.
            # This value is 3 because that's the number of versions that exist at this point based on previous updates
            # to the fixtures. See
            # https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/remote_development/README.md#workspaces_agent_configs-versioning
            # for more details on how versioning works and why this value is 3.
            workspace.valid?
            expect(workspace.workspaces_agent_config_version).to eq(3)
          end
        end
      end
    end
  end

  describe "validations" do
    context "on agent.unversioned_latest_workspaces_agent_config" do
      context "when no config is present" do
        before do
          agent.unversioned_latest_workspaces_agent_config.destroy!
          agent.reload
        end

        it "validates presence of agent.unversioned_latest_workspaces_agent_config" do
          # sanity check of fixture
          expect(workspace.agent.unversioned_latest_workspaces_agent_config).not_to be_present

          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include("Agent must have an associated workspaces agent config")
        end
      end

      context "on agent_config enabled" do
        context "when agent is enabled" do
          it "validates presence of agent.workspaces_agent_config" do
            expect(workspace).to be_valid
          end
        end

        context "when agent is disabled" do
          let(:workspaces_agent_config_enabled) { false }

          it "validates agent.unversioned_latest_workspaces_agent_config is enabled" do
            expect(workspace).not_to be_valid
            expect(workspace.errors[:agent])
              .to include("must have the 'enabled' flag set to true")
          end

          it "is only validated on create" do
            workspace.workspaces_agent_config_version = 1
            workspace.save(validate: false) # rubocop:disable Rails/SaveBang -- intentional to test validation
            workspace.valid?
            expect(workspace.errors[:agent]).to be_blank
          end
        end
      end
    end

    context "on workspaces_agent_config_version" do
      context "when version is nil" do
        before do
          workspace.save!
          # noinspection RubyMismatchedArgumentType - intentional to test validation
          workspace.workspaces_agent_config_version = nil
        end

        it "raises error message as expected" do
          expect do
            workspace.valid?
          end.to raise_error(RuntimeError,
            "#workspaces_agent_config cannot be called until #workspaces_agent_config_version is set. " \
              "Call set_workspaces_agent_config_version first to automatically set it.")
        end
      end

      context "when version is greater than version range" do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = agent_config.versions.size + 1
        end

        it "raises error message as expected" do
          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include(
            "Workspaces agent config version must be no greater than the number of agent config versions"
          )
        end
      end

      context "when version is less than 0" do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = -1
        end

        it "raises error message as expected" do
          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include(
            "Workspaces agent config version must be greater than or equal to 0"
          )
        end
      end
    end

    context "on desired_state" do
      context "when desired_state is Terminated" do
        let(:desired_state) { ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

        it "prevents changes to desired_state" do
          workspace.save!
          updated = workspace.update(desired_state: ::RemoteDevelopment::WorkspaceOperations::States::STOPPED)
          expect(updated).to eq(false)
          expect(workspace).not_to be_valid
          expect(workspace.errors[:desired_state])
            .to include("is 'Terminated', and cannot be updated. Create a new workspace instead.")
        end
      end
    end

    describe "on workspaces_per_user_quota" do
      before do
        allow(workspace)
          .to receive(:workspaces_count_for_current_user_and_agent)
                .and_return(workspaces_count_for_current_user_and_agent)
      end

      describe "when quotas are not exceeded" do
        shared_context "does not exceed per user quota" do
          let(:workspaces_per_user_quota) { 2 }
          let(:workspaces_count_for_current_user_and_agent) { 1 }

          it "does not add base errors when quotas are not exceeded" do
            workspace.validate
            expect(workspace.errors[:base]).to be_empty
          end
        end

        context "when workspaces_per_user_quota is -1" do
          let(:workspaces_per_user_quota) { -1 }
          let(:workspaces_count_for_current_user_and_agent) { 99 }

          it_behaves_like "does not exceed per user quota"
        end
      end

      context "when quotas are exceeded" do
        shared_context "exceeds per user quota" do
          it "adds per user quota exceeded error to base error" do
            workspace.validate

            message = "You cannot create a workspace because you already have " \
              "'#{workspaces_count_for_current_user_and_agent}' existing workspaces for the given agent " \
              "which has a per user quota of '#{workspaces_per_user_quota}' workspaces"
            expect(workspace.errors[:base]).to include(message)
          end
        end

        context "when workspaces_per_user_quota is 0" do
          let(:workspaces_per_user_quota) { 0 }
          let(:workspaces_count_for_current_user_and_agent) { 0 }

          it_behaves_like "exceeds per user quota"
        end

        context "when workspaces count for current user and agent is equal to the quota" do
          let(:workspaces_per_user_quota) { 1 }
          let(:workspaces_count_for_current_user_and_agent) { 1 }

          it_behaves_like "exceeds per user quota"
        end

        context "when workspaces count for current user and agent is greater than the quota" do
          let(:workspaces_per_user_quota) { 1 }
          let(:workspaces_count_for_current_user_and_agent) { 2 }

          it_behaves_like "exceeds per user quota"
        end
      end
    end

    describe "on enforce_workspaces_quota" do
      before do
        allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(workspaces_count_for_current_agent)
      end

      describe "when quotas are not exceeded" do
        shared_examples "does not exceed quota" do
          let(:workspaces_quota) { 2 }
          let(:workspaces_count_for_current_agent) { 1 }

          it "does not add base errors when quotas are not exceeded" do
            workspace.validate
            expect(workspace.errors[:base]).to be_empty
          end
        end

        context "when workspaces_quota is -1" do
          let(:workspaces_quota) { -1 }
          let(:workspaces_count_for_current_agent) { 99 }

          it_behaves_like "does not exceed quota"
        end
      end

      context "when quotas are exceeded" do
        shared_examples "exceeds quota" do
          before do
            workspace.send(:set_workspaces_agent_config_version)
          end

          it "adds quota exceeded error to base error" do
            workspace.validate

            message = "You cannot create a workspace because there are already " \
              "'#{workspaces_count_for_current_agent}' existing workspaces for the given agent " \
              "which has a quota of '#{workspaces_quota}' workspaces"
            expect(workspace.errors[:base]).to include(message)
          end
        end

        context "when workspaces_quota is 0" do
          let(:workspaces_quota) { 0 }
          let(:workspaces_count_for_current_agent) { 0 }

          it_behaves_like "exceeds quota"
        end

        context "when workspaces count for agent is equal to the quota" do
          let(:workspaces_quota) { 1 }
          let(:workspaces_count_for_current_agent) { 1 }

          it_behaves_like "exceeds quota"
        end

        context "when workspaces count for agent is greater than the quota" do
          let(:workspaces_quota) { 1 }
          let(:workspaces_count_for_current_agent) { 2 }

          it_behaves_like "exceeds quota"
        end
      end
    end
  end

  describe "scopes" do
    describe "with_desired_state_updated_more_recently_than_last_response_to_agent" do
      context "when responded_to_agent_at is nil" do
        before do
          workspace.save!
          workspace.update!(
            desired_state_updated_at: DateTime.now.advance(minutes: 20),
            responded_to_agent_at: nil
          )
        end

        it "includes workspace" do
          # fixture sanity check
          expect(workspace.responded_to_agent_at).to be_nil

          expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
            .to include(workspace)

          # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
          expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to eq(true)
        end
      end

      context "when responded_to_agent_at is not nil" do
        context "when desired_state_updated_at is greater than responded_to_agent_at" do
          before do
            workspace.save!
            workspace.update!(
              desired_state_updated_at: DateTime.now.advance(minutes: 20),
              responded_to_agent_at: DateTime.now.advance(minutes: 10)
            )
          end

          it "includes workspace" do
            # fixture sanity check
            expect(workspace.desired_state_updated_at).to be > workspace.responded_to_agent_at

            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .to include(workspace)

            # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
            expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to eq(true)
          end
        end

        context "when desired_state_updated_at is equal to responded_to_agent_at" do
          before do
            workspace.save!
            workspace.update!(
              desired_state_updated_at: DateTime.now.advance(minutes: 10),
              responded_to_agent_at: DateTime.now.advance(minutes: 10)
            )
          end

          it "does not include workspace" do
            # fixture sanity check
            expect(workspace.desired_state_updated_at).to eq(workspace.responded_to_agent_at)

            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .not_to include(workspace)

            # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
            expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to eq(false)
          end
        end

        context "when desired_state_updated_at is less than responded_to_agent_at" do
          before do
            workspace.save!
            workspace.update!(
              desired_state_updated_at: DateTime.now.advance(minutes: 10),
              responded_to_agent_at: DateTime.now.advance(minutes: 20)
            )
          end

          it "does not include workpace" do
            # fixture sanity check
            expect(workspace.desired_state_updated_at).to be < workspace.responded_to_agent_at

            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .not_to include(workspace)

            # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
            expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to eq(false)
          end
        end
      end
    end

    describe "with_actual_state_updated_more_recently_than_last_response_to_agent" do
      context "when workspace responded_to_agent_at is nil" do
        before do
          workspace.save!
          workspace.update!(
            actual_state_updated_at: DateTime.now.advance(minutes: 20),
            responded_to_agent_at: nil
          )
        end

        it "returns workspace" do
          expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
            .to include(workspace)
        end
      end

      context "when actual_state_updated_at is greater than responded_to_agent_at" do
        context "when responded_to_agent_at is nil" do
          before do
            workspace.save!
            workspace.update!(
              actual_state_updated_at: DateTime.now.advance(minutes: 20),
              responded_to_agent_at: nil
            )
          end

          it "returns true" do
            # fixture sanity check
            expect(workspace.responded_to_agent_at).to be_nil

            expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to eq(true)
          end
        end

        context "when responded_to_agent_at is not nil" do
          context "when actual_state_updated_at is greater than responded_to_agent_at" do
            before do
              workspace.save!
              workspace.update!(
                actual_state_updated_at: DateTime.now.advance(minutes: 20),
                responded_to_agent_at: DateTime.now.advance(minutes: 10)
              )
            end

            it "includes workspace" do
              # fixture sanity check
              expect(workspace.actual_state_updated_at).to be > workspace.responded_to_agent_at

              expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
                .to include(workspace)

              # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
              expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to eq(true)
            end
          end

          context "when actual_state_updated_at is equal to responded_to_agent_at" do
            before do
              workspace.save!
              workspace.update!(
                actual_state_updated_at: DateTime.now.advance(minutes: 10),
                responded_to_agent_at: DateTime.now.advance(minutes: 10)
              )
            end

            it "does not include workpace" do
              # fixture sanity check
              expect(workspace.actual_state_updated_at).to eq(workspace.responded_to_agent_at)

              expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
                .not_to include(workspace)

              # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
              expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to eq(false)
            end
          end

          context "when actual_state_updated_at is less than responded_to_agent_at" do
            before do
              workspace.save!
              workspace.update!(
                actual_state_updated_at: DateTime.now.advance(minutes: 10),
                responded_to_agent_at: DateTime.now.advance(minutes: 20)
              )
            end

            it "does not include workpace" do
              # fixture sanity check
              expect(workspace.actual_state_updated_at).to be < workspace.responded_to_agent_at

              expect(described_class.with_actual_state_updated_more_recently_than_last_response_to_agent)
                .not_to include(workspace)

              # NOTE: We will also test the corresponding method here, since its logic is the same as the scope
              expect(workspace.actual_state_updated_more_recently_than_last_response_to_agent?).to eq(false)
            end
          end
        end
      end
    end

    describe "desired_state_not_terminated" do
      context "when workspace desired_state is not terminated" do
        let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }

        it "returns workspace" do
          workspace.save!
          expect(described_class.desired_state_not_terminated).to include(workspace)
        end
      end

      context "when workspace desired_state is terminated" do
        let(:desired_state) { RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

        it "returns workspace" do
          workspace.save!
          expect(described_class.desired_state_not_terminated).not_to include(workspace)
        end
      end
    end

    describe "actual_state_not_terminated" do
      context "when workspace actual_state is not terminated" do
        let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }

        it "returns workspace" do
          workspace.save!
          expect(described_class.actual_state_not_terminated).to include(workspace)
        end
      end

      context "when workspace actual_state is terminated" do
        let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

        it "when workspace actual_state is terminated" do
          workspace.save!
          expect(described_class.actual_state_not_terminated).not_to include(workspace)
        end
      end
    end
  end

  describe "methods" do
    describe "#url" do
      before do
        workspace.send(:set_workspaces_agent_config_version)
      end

      it "returns calculated url" do
        expect(workspace.url).to eq("https://60001-#{workspace.name}.#{dns_zone}/?folder=dir%2Ffile")
      end
    end

    describe "#devfile_web_url" do
      it "returns web url to devfile" do
        # noinspection HttpUrlsUsage - suppress RubyMine warning for insecure http link.
        expect(workspace.devfile_web_url).to eq("http://#{Gitlab.config.gitlab.host}/#{workspace.project.path_with_namespace}/-/blob/main/.devfile.yaml")
      end

      context "when devfile_path is nil" do
        before do
          # noinspection RubyMismatchedArgumentType - RubyMine thinks devfile_path can't be nilable, but it can
          workspace.devfile_path = nil
        end

        it "returns nil as devfile_web_url" do
          expect(workspace.devfile_web_url).to eq(nil)
        end
      end
    end

    describe "#workspaces_count_for_current_user_and_agent" do
      let_it_be(:user1) { create(:user) }
      let_it_be(:user2) { create(:user) }
      let_it_be(:user3) { create(:user) }
      let_it_be(:agent1, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:agent2, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:workspace1) do
        create(
          :workspace, user: user1, agent: agent1,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      let_it_be(:workspace2) do
        create(
          :workspace, user: user2, agent: agent1,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(
          :workspace, user: user1, agent: agent1,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      end

      let_it_be(:workspace4) do
        create(
          :workspace, user: user2, agent: agent2,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(
          :workspace, user: user3, agent: agent2,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      it "returns the correct count for the current user and agent" do
        expect(workspace1.send(:workspaces_count_for_current_user_and_agent)).to eq(2)
        expect(workspace2.send(:workspaces_count_for_current_user_and_agent)).to eq(0)
        expect(workspace3.send(:workspaces_count_for_current_user_and_agent)).to eq(2)
        expect(workspace4.send(:workspaces_count_for_current_user_and_agent)).to eq(0)
        expect(workspace5.send(:workspaces_count_for_current_user_and_agent)).to eq(1)
      end
    end

    describe "#workspaces_count_for_current_agent" do
      let_it_be(:agent1, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:agent2, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:workspace1) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      let_it_be(:workspace2) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      end

      let_it_be(:workspace4) do
        create(:workspace, agent: agent2, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(:workspace, agent: agent2, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      it "returns the correct count for the current agent" do
        expect(workspace1.send(:workspaces_count_for_current_agent)).to eq(2)
        expect(workspace4.send(:workspaces_count_for_current_agent)).to eq(1)
        expect(workspace5.send(:workspaces_count_for_current_agent)).to eq(1)
      end
    end
  end
end
# rubocop:enable RSpec/ MultipleMemoizedHelpers
