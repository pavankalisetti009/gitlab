# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowsFinder, feature_category: :duo_agent_platform do
  let_it_be(:ai_settings) { create(:namespace_ai_settings, duo_workflow_mcp_enabled: true) }
  let_it_be(:group) { create(:group, ai_settings: ai_settings) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  before do
    allow(user).to receive(:can?).with(:duo_workflow, project).and_return(true)
  end

  describe '#default_options' do
    subject(:default_options) { described_class.new(current_user: user).default_options }

    it 'returns the default options' do
      expect(default_options).to eq({ sort: 'created_desc' })
    end
  end

  describe '#resolve_sort' do
    subject(:results) { described_class.new(options).results }

    let(:options) { { current_user: user, source: user, sort: sort } }

    context 'when sorting is created' do
      let_it_be(:first_workflow) do
        create(:duo_workflows_workflow, project: project, user: user, created_at: 2.days.ago)
      end

      let_it_be(:second_workflow) do
        create(:duo_workflows_workflow, project: project, user: user, created_at: 1.day.ago)
      end

      context 'and direction is asc' do
        let(:sort) { 'created_asc' }

        it 'orders results by created_at ascending' do
          expect(results).to eq([first_workflow, second_workflow])
        end
      end

      context 'and direction is desc' do
        let(:sort) { 'created_desc' }

        it 'orders results by created_at descending' do
          expect(results.records).to eq([second_workflow, first_workflow])
        end
      end

      context 'and direction is invalid' do
        let(:sort) { 'created' }

        it 'falls back to ascending direction' do
          expect(results).to eq([first_workflow, second_workflow])
        end
      end
    end

    context 'when sorting is status' do
      let_it_be(:created_workflow) do
        create(:duo_workflows_workflow, :created, project: project, user: user, created_at: 2.days.ago)
      end

      let_it_be(:running_workflow) do
        create(:duo_workflows_workflow, :running, project: project, user: user, created_at: 1.day.ago)
      end

      context 'and direction is asc' do
        let(:sort) { 'status_asc' }

        it 'orders results by their status ascending' do
          expect(results).to eq([created_workflow, running_workflow])
        end
      end

      context 'and direction is desc' do
        let(:sort) { 'status_desc' }

        it 'orders results by their status descending' do
          expect(results.records).to eq([running_workflow, created_workflow])
        end
      end
    end
  end

  describe '#resolve_search' do
    using RSpec::Parameterized::TableSyntax

    subject(:query) { described_class.new(options).results.to_sql }

    let(:options) do
      { current_user: user, source: user, search: term }
    end

    where(:term, :filter_by_words, :filter_by_ids) do
      '123'                     | []                  | [123]
      '#456'                    | []                  | [456]
      'soft devel'              | %w[soft devel]      | []
      'soft devel v1'           | %w[soft devel v1]   | []
      'soft devel 123'          | %w[soft devel]      | [123]
      'soft devel #123'         | %w[soft devel]      | [123]
      '#123 soft devel'         | %w[soft devel]      | [123]
      'soft devel v1 #123'      | %w[soft devel v1]   | [123]
      'soft devel v1 123 456'   | %w[soft devel v1]   | [123, 456]
      'soft devel v1 #123 #456' | %w[soft devel v1]   | [123, 456]
      'soft devel v13 #123 456' | %w[soft devel v13]  | [123, 456]
    end

    with_them do
      it 'fuzzy searches all words' do
        if filter_by_words.empty?
          expect(query).not_to include('ILIKE')
        else
          expected_query = [:workflow_definition, :goal].map do |column|
            filter_by_words.map do |word|
              Ai::DuoWorkflows::Workflow.arel_table[column].matches("%#{word}%")
            end.reduce(:and)
          end.reduce(:or).to_sql

          expect(query).to include(expected_query)
        end
      end

      it 'filters by IDs' do
        if filter_by_ids.empty?
          expect(query).not_to include('"duo_workflows_workflows"."id"')
        elsif filter_by_ids.many?
          expect(query).to include(Ai::DuoWorkflows::Workflow.arel_table[:id].in(filter_by_ids).to_sql)
        else
          expect(query).to include(Ai::DuoWorkflows::Workflow.arel_table[:id].eq(filter_by_ids.first).to_sql)
        end
      end
    end
  end
end
