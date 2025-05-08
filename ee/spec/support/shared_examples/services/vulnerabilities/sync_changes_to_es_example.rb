# frozen_string_literal: true

RSpec.shared_examples 'sync vulnerabilities changes to ES' do
  let(:received_vulnerabilities) { [] }

  before do
    allow(::Search::Elastic::VulnerabilityIndexingHelper).to receive(:vulnerability_indexing_allowed?).and_return(true)

    allow(Elastic::ProcessBookkeepingService).to receive(:track!) do |*vulnerabilities|
      received_vulnerabilities.concat(vulnerabilities)
    end
  end

  context 'when vulnerability_es_ingestion FF disabled' do
    before do
      allow_next_found_instance_of(Vulnerability) do |instance|
        allow(instance).to receive(:maintaining_elasticsearch?).and_return(false)
      end

      allow_next_found_instance_of(Vulnerabilities::Read) do |instance|
        allow(instance).to receive(:maintaining_elasticsearch?).and_return(false)
      end
    end

    it 'calls the ProcessBookkeepingService with vulnerabilities' do
      subject

      expect(Elastic::ProcessBookkeepingService).to have_received(:track!)
      expect(received_vulnerabilities).to be_empty
    end
  end

  context 'when vulnerability_es_ingestion FF enabled' do
    before do
      allow_next_found_instance_of(Vulnerability) do |instance|
        allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
      end

      allow_next_found_instance_of(Vulnerabilities::Read) do |instance|
        allow(instance).to receive(:maintaining_elasticsearch?).and_return(true)
      end
    end

    it 'calls the ProcessBookkeepingService with vulnerabilities' do
      subject

      expect(Elastic::ProcessBookkeepingService).to have_received(:track!)
      expect(received_vulnerabilities).to match_array(expected_vulnerabilities)
    end
  end
end
