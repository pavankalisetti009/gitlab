# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::BaseBatchBulkUpdateService, feature_category: :geo_replication do
  let(:service) { described_class.new('upload', {}) }

  shared_examples 'a non implemented method' do |method|
    it 'raises `NotImplementedError`' do
      expect { service.send(method) }.to raise_error(NotImplementedError)
    end
  end

  describe '#attributes_to_update' do
    it_behaves_like 'a non implemented method', :attributes_to_update
  end

  describe '#apply_update_scope' do
    it_behaves_like 'a non implemented method', :records_to_update
  end

  describe '#worker' do
    it_behaves_like 'a non implemented method', :worker
  end

  context 'when model_to_update raises' do
    describe '#model_to_update' do
      it_behaves_like 'a non implemented method', :model_to_update
    end
  end

  describe '#records_to_update' do
    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive_messages(model_class: model_to_update, update_scope: model_to_update.all)
      end
    end

    context 'with a model which has a composite PK' do
      let_it_be(:model_to_update) do
        Class.new(VirtualRegistries::Packages::Maven::Cache::Entry) do
          include Geo::VerificationStateDefinition
        end
      end

      it 'returns a keyset iterator' do
        expect(described_class.new('entry', {}).send(:records_to_update))
          .to be_an_instance_of(Gitlab::Pagination::Keyset::Iterator)
      end
    end

    context 'with a model which has an integer PK' do
      let_it_be(:model_to_update) { Geo::UploadState }

      it 'returns the model' do
        expect(described_class.new('upload', {}).send(:records_to_update))
          .to be_a_kind_of(ActiveRecord::Relation)
      end
    end
  end
end
