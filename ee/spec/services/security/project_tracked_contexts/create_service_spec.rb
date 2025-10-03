# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContexts::CreateService, feature_category: :vulnerability_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:context_name) { 'main' }
  let(:context_type) { 'branch' }
  let(:is_default) { false }
  let(:track) { false }

  let(:params) do
    {
      context_name: context_name,
      context_type: context_type,
      is_default: is_default,
      track: track
    }
  end

  subject(:service) { described_class.new(project, user, params) }

  shared_examples 'creates a tracked context successfully' do
    let(:expected_state) { track ? :tracked : :untracked }

    it "creates a tracked context with correct attributes" do
      result = service.execute

      expect(result).to be_success
      expect(result.payload[:tracked_context]).to be_persisted
      expect(result.payload[:tracked_context].context_name).to eq(expected_context_name)
      expect(result.payload[:tracked_context].context_type).to eq(expected_context_type.to_s)
      expect(result.payload[:tracked_context].is_default).to eq(expected_is_default)
      expect(result.payload[:tracked_context]).to send(:"be_#{expected_state}")
    end
  end

  shared_examples 'returns validation error' do
    it 'returns an error with the expected message' do
      result = service.execute

      expect(result).to be_error
      expect(result.message).to include(expected_error)
      expect(result.payload[:tracked_context]).not_to be_persisted
    end
  end

  describe '#execute' do
    context 'when creating valid tracked contexts' do
      where(:context_name_param, :context_type_param, :is_default_param, :track_param, :description) do
        'main'   | 'branch' | false | false | 'untracked branch context'
        'main'   | 'branch' | false | true  | 'tracked branch context'
        'main'   | 'branch' | true  | true  | 'tracked default branch context'
        'v1.0.0' | 'tag'    | false | false | 'untracked tag context'
        'v1.0.0' | 'tag'    | false | true  | 'tracked tag context'
      end

      with_them do
        let(:context_name) { context_name_param }
        let(:context_type) { context_type_param }
        let(:is_default) { is_default_param }
        let(:track) { track_param }
        let(:expected_context_name) { context_name_param }
        let(:expected_context_type) { context_type_param }
        let(:expected_is_default) { is_default_param }

        it_behaves_like 'creates a tracked context successfully'
      end
    end

    context 'when creating invalid tracked contexts' do
      where(:context_name_param, :context_type_param, :is_default_param, :track_param, :expected_error, :description) do
        nil          | 'branch' | false | false | "Context name can't be blank"     | 'missing context name'
        ('a' * 1025) | 'branch' | false | false | 'Context name is too long'        | 'context name too long'
        'main'       | 'branch' | true  | false | 'default ref must be tracked'     | 'untracked default ref'
      end

      with_them do
        let(:context_name) { context_name_param }
        let(:context_type) { context_type_param }
        let(:is_default) { is_default_param }
        let(:track) { track_param }

        it_behaves_like 'returns validation error'
      end
    end

    context 'when tracked refs limit is exceeded' do
      let(:max_refs) { Security::ProjectTrackedContext::MAX_TRACKED_REFS_PER_PROJECT }
      let(:expected_error) { "cannot exceed #{max_refs} tracked refs per project" }
      let(:track) { true }

      before do
        create_list(:security_project_tracked_context,
          max_refs,
          :tracked,
          project: project)
      end

      it_behaves_like 'returns validation error'
    end

    context 'when context_name already exists for the project and context_type' do
      let(:expected_error) { 'Context name has already been taken' }

      before do
        create(:security_project_tracked_context,
          project: project,
          context_name: context_name,
          context_type: context_type)
      end

      it_behaves_like 'returns validation error'
    end

    context 'when multiple validation errors occur' do
      let(:context_name) { nil }
      let(:is_default) { true }
      let(:track) { false }

      it 'returns all error messages' do
        result = service.execute

        expect(result).to be_error
        expect(result.message).to include("Context name can't be blank")
        expect(result.message).to include('default ref must be tracked')
      end
    end

    context 'when params are not provided' do
      let(:params) { {} }

      it 'returns a failed result gracefully' do
        result = service.execute

        expect(result).to be_error
        tracked_context = result.payload[:tracked_context]
        expect(tracked_context.is_default).to be false
        expect(tracked_context).to be_untracked
        expect(tracked_context).not_to be_persisted
      end
    end
  end

  describe 'parameter handling' do
    it 'handles missing optional parameters' do
      service = described_class.new(project, user, {
        context_name: 'main',
        context_type: :branch
      })

      expect(service.send(:is_default)).to be false
      expect(service.send(:track)).to be false
    end
  end
end
