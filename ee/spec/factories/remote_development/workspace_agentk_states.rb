# frozen_string_literal: true

FactoryBot.define do
  factory :workspace_agentk_state, class: 'RemoteDevelopment::WorkspaceAgentkState' do
    # noinspection RailsParamDefResolve -- RubyMine flags this as requiring a hash, but a symbol is a valid option
    association :project, :in_group

    workspace

    desired_config do
      RemoteDevelopment::FixtureFileHelpers.read_fixture_file('example.desired_config.json')
    end
  end
end
