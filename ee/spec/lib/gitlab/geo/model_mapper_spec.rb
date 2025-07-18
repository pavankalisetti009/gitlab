# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Geo::ModelMapper, feature_category: :geo_replication do
  describe '.convert_to_name' do
    let(:model) { class_double(Model, name:) }

    context 'with single word model names' do
      let(:name) { 'User' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('user')
      end
    end

    context 'with multiple word model names' do
      let(:name) { 'ProjectRepository' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('project_repository')
      end
    end

    context 'with namespaced model names' do
      let(:name) { 'Analytics::DevopsAdoption::Segment' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('analytics_devops_adoption_segment')
      end
    end

    context 'with single character name' do
      let(:name) { 'A' }

      it 'converts to snake_case' do
        expect(described_class.convert_to_name(model)).to eq('a')
      end
    end

    context 'with consecutive capitals' do
      let(:name) { 'XMLParser' }

      it 'handles names with consecutive capitals' do
        expect(described_class.convert_to_name(model)).to eq('xml_parser')
      end
    end
  end

  describe '.find_from_name' do
    before do
      # We remove the `Dummy` replicator from the list as it is not a valid Replicator we want to test
      # It was causing flaky order-dependent test failures:
      # https://gitlab.com/gitlab-org/gitlab/-/merge_requests/198143
      allow(described_class).to receive(:list_of_available_models).and_return(
        Gitlab::Geo::Replicator.subclasses
          .reject { |r| r.name.include?('Dummy') }
          .map(&:model)
      )
    end

    context 'when model name is valid' do
      where(:replicator) { Gitlab::Geo::Replicator.subclasses }
      with_them do
        let(:model) { replicator.model }
        let(:name) { replicator.model_name }

        it 'returns the correct model for simple names' do
          expect(described_class.find_from_name(name)).to eq(model)
        end
      end
    end

    context 'when model name does not exist' do
      it 'returns nil for non-existent model names' do
        expect(described_class.find_from_name('non_existent_model')).to be_nil
      end

      it 'returns nil for empty string' do
        expect(described_class.find_from_name('')).to be_nil
      end

      it 'returns nil for nil input' do
        expect(described_class.find_from_name(nil)).to be_nil
      end
    end

    context 'when no replicators are available' do
      before do
        allow(Gitlab::Geo::Replicator).to receive(:subclasses).and_return([])
      end

      it 'returns nil when no models are available' do
        expect(described_class.find_from_name('user')).to be_nil
      end
    end
  end
end
