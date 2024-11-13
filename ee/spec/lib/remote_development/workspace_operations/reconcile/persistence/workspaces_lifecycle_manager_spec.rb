# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe RemoteDevelopment::WorkspaceOperations::Reconcile::Persistence::WorkspacesLifecycleManager, feature_category: :workspaces do
  let!(:now) do
    # NOTE: There's a few necessary things going on here in this `let!(:now) declaration:
    #       1. We can't use :freeze_time RSpec annotation, because that happens in an "around" block
    #          after the `let` block for `now` is evaluated
    #       2. Furthermore, we can't freeze time in ANY before/after/around block, because these all happen
    #          after the various `let` blocks have already been evaluted. This is because many of the
    #          `let` blocks, including this one for `now`, are triggered by the processing of the
    #          `where` block scenario declarations for RSpec::Parameterized
    #       3. Thus, to ensure that `now` is frozen early enough - before ANY other references to it
    #          or Time.zone.now, we we need to freeze time _WITHIN_ this `let!` block, then manually
    #          travel back to the original time in an `after` block.
    #       4. This has to be a `let!` block, not a `let` block, because we need to ensure that
    #          it is eagerly evaluated, not lazily when it is first referenced.
    #       5. We also use a hardcoded time to freeze to, instead of Time.zone.now, so that we can
    #          do a fixture sanity check inside the actual test block context, to ensure that
    #          `now` has been properly frozen.
    #       6. Finally, note this will _NOT_ always cause problems when used via `fast_spec_helper`,
    #          it will only cause problems if this spec file happens to be run in when
    #          the regular `spec_helper` has already been initialized and is in effect.
    time = Time.utc(2021, 1, 1)
    travel_to(time)
    time
  end

  let(:max_hours_before_termination) do
    RemoteDevelopment::WorkspaceOperations::MaxHoursBeforeTermination::MAX_HOURS_BEFORE_TERMINATION
  end

  let(:max_active_hours_before_stop) { RemoteDevelopment::Settings.get_single_setting(:max_active_hours_before_stop) }
  let(:max_stopped_hours_before_termination) do
    RemoteDevelopment::Settings.get_single_setting(:max_stopped_hours_before_termination)
  end

  let(:max_allowable_workspace_age) { now - max_hours_before_termination.hours }

  let(:running) { RemoteDevelopment::WorkspaceOperations::States::RUNNING }
  let(:stopped) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }
  let(:terminated) { RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

  let(:workspaces_from_agent_infos) { [workspace] }

  let(:context) do
    {
      workspaces_from_agent_infos: workspaces_from_agent_infos
    }
  end

  subject(:returned_value) do
    described_class.manage(context)
  end

  after do
    travel_back
  end

  context 'with various workspace states and conditions' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- We don't want to wrap RSpec::Parameterized::TableSyntax, it hurts readability
    where(:scenario, :created_at, :desired_state_updated_at, :initial_desired_state, :expected_desired_state) do
      "No limits exceeded, workspace just created, expect no state change" | now | now | running | running
      "No limits exceeded, workspace is at max allowable active hours, no state change" | (now - max_active_hours_before_stop.hours + 1) | (now - max_active_hours_before_stop.hours + 1) | running | running
      "No limits exceeded, workspace is at max allowable age, desired_state just updated, expect no state change" | max_allowable_workspace_age | now | running | running
      "max_hours_before_termination limit exceeded, not already terminated, expect state to change to terminated" | (max_allowable_workspace_age - 1) | now | running | terminated
      "max_hours_before_termination limit exceeded, already terminated, expect no state change" | (max_allowable_workspace_age - 1) | now | terminated | terminated
      "max_active_hours_before_stop limit exceeded, not already stopped, expect state to change to stopped" | max_allowable_workspace_age | (now - max_active_hours_before_stop.hours - 1) | running | stopped
      "max_active_hours_before_stop limit exceeded, already stopped, expect no state change" | max_allowable_workspace_age | (now - max_active_hours_before_stop.hours - 1) | stopped | stopped
      "max_active_hours_before_stop limit exceeded, already terminated, expect no state change" | max_allowable_workspace_age | (now - max_active_hours_before_stop.hours - 1) | terminated | terminated
      "max_stopped_hours_before_termination limit exceeded, not already terminated, expect state to change to terminated" | max_allowable_workspace_age | (now - max_stopped_hours_before_termination.hours - 1) | stopped | terminated
      "max_stopped_hours_before_termination limit exceeded, already terminated, expect no state change" | max_allowable_workspace_age | (now - max_stopped_hours_before_termination.hours - 1) | terminated | terminated
    end
    # rubocop:enable Layout/LineLength -- We don't want to wrap RSpec::Parameterized::TableSyntax, it hurts readability

    with_them do
      let(:workspaces_agent_config) do
        instance_double(
          "RemoteDevelopment::WorkspacesAgentConfig", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
          max_active_hours_before_stop: max_active_hours_before_stop,
          max_stopped_hours_before_termination: max_stopped_hours_before_termination
        )
      end

      let(:workspace) do
        instance_double(
          "RemoteDevelopment::Workspace", # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
          created_at: created_at,
          desired_state_updated_at: desired_state_updated_at,
          desired_state: initial_desired_state,
          workspaces_agent_config: workspaces_agent_config
        )
      end

      it "correctly updates (or not) desired_state" do
        # "now" time fixture sanity check - ensure that time is properly frozen
        expect(Time.zone.now.to_i).to eq(Time.utc(2021, 1, 1).to_i)

        if expected_desired_state == initial_desired_state
          expect(workspace).not_to receive(:update!)
        else
          expect(workspace).to receive(:update!).with(desired_state: expected_desired_state).once
        end

        expect(returned_value).to eq(context)
      end
    end
  end
end
