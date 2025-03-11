# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::BuildDependencyGraphWorker, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }

  describe '#perform' do
    subject(:run_worker) { described_class.new.perform(project.id) }

    before do
      allow(Sbom::BuildDependencyGraph).to receive(:execute)
    end

    context 'when there is no pipeline with the given ID' do
      subject(:perform) { described_class.new.perform(non_existing_record_id) }

      it 'does not raise an error' do
        expect { perform }.not_to raise_error
      end
    end

    it 'calls `Sbom::BuildDependencyGraph`' do
      run_worker

      expect(Sbom::BuildDependencyGraph).to have_received(:execute).with(project)
    end
  end
end
