# frozen_string_literal: true
require "spec_helper"

RSpec.describe Gitlab::SPDX::Catalogue, feature_category: :software_composition_analysis do
  include StubRequests
  subject { described_class.new(catalogue_hash) }

  let(:spdx_json) { File.read(Rails.root.join("spec", "fixtures", "spdx.json")) }
  let(:catalogue_hash) { Gitlab::Json.parse(spdx_json, symbolize_names: true) }

  describe "#version" do
    let(:version) { SecureRandom.uuid }

    it { expect(described_class.new(licenseListVersion: version).version).to eql(version) }
  end

  describe "#each" do
    it { expect(subject.count).to eql(catalogue_hash[:licenses].count) }
    it { expect(subject.map(&:id)).to match_array(catalogue_hash[:licenses].map { |x| x[:licenseId] }) }
    it { expect(subject.map(&:name)).to match_array(catalogue_hash[:licenses].map { |x| x[:name] }) }

    specify do
      deprecrated_gpl = subject.find { |license| license.id == 'GPL-1.0' }
      expect(deprecrated_gpl.deprecated).to be_truthy
    end

    specify do
      gpl = subject.find { |license| license.id == 'GPL-1.0-only' }
      expect(gpl.deprecated).to be_falsey
    end

    context "when some of the licenses are missing an identifier" do
      let(:catalogue_hash) do
        {
          licenseListVersion: "3.6",
          licenses: [
            { licenseId: nil, name: "nil" },
            { licenseId: "", name: "blank" },
            { licenseId: "valid", name: "valid" }
          ]
        }
      end

      it { expect(subject.count).to be(1) }
      it { expect(subject.map(&:id)).to contain_exactly("valid") }
    end

    context "when the schema of each license changes" do
      let(:catalogue_hash) do
        {
          licenseListVersion: "3.6",
          licenses: [
            {
              "license-ID": 'MIT',
              name: "MIT License"
            }
          ]
        }
      end

      it { expect(subject.count).to be_zero }
    end

    context "when the schema of the catalogue changes" do
      let(:catalogue_hash) { { SecureRandom.uuid.to_sym => [{ id: 'MIT', name: "MIT License" }] } }

      it { expect(subject.count).to be_zero }
    end
  end

  describe "#licenses" do
    it 'returns all licenses converted to POROs' do
      expected = catalogue_hash[:licenses].map do |license|
        an_object_having_attributes(
          id: license[:licenseId],
          name: license[:name],
          deprecated: license[:isDeprecatedLicenseId]
        )
      end

      expect(subject.licenses).to match_array(expected)
    end
  end

  describe ".latest" do
    subject { described_class.latest }

    context "when the licenses.json endpoint is healthy" do
      let(:gateway) { instance_double(Gitlab::SPDX::CatalogueGateway, fetch: catalogue) }
      let(:catalogue) { instance_double(described_class) }

      before do
        allow(Gitlab::SPDX::CatalogueGateway).to receive(:new).and_return(gateway)
      end

      it { expect(subject).to be(catalogue) }
    end
  end

  describe ".latest_active_licenses" do
    subject(:latest_active_licenses) { described_class.latest_active_licenses }

    it 'rejects deprecated licenses' do
      expect(latest_active_licenses.find(&:deprecated)).to be_nil
    end

    it 'returns only active licenses' do
      expect(latest_active_licenses.all?(&:deprecated)).to be_falsey
    end

    it 'returns the expected active licenses' do
      expect(latest_active_licenses.find { |l| l.id == 'MIT' }).to be_present
    end
  end
end
