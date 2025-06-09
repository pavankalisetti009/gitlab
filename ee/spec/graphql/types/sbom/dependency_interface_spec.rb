# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Sbom::DependencyInterface, feature_category: :dependency_management do
  let(:fields) do
    %i[id name version componentVersion packager location licenses reachability vulnerability_count vulnerabilities]
  end

  let(:dependency) { instance_double(::Sbom::Occurrence) }
  let(:interface) do
    Class.new do
      include Types::Sbom::DependencyInterface
      attr_reader :object

      def initialize(object)
        @object = object
      end
    end.new(dependency)
  end

  it { expect(described_class).to have_graphql_fields(fields) }

  describe '#packager' do
    context 'when packager is in the predefined list' do
      valid_packagers = %w[bundler npm yarn maven pip]

      valid_packagers.each do |valid_packager|
        it "returns the packager value for '#{valid_packager}'" do
          allow(dependency).to receive(:packager).and_return(valid_packager)

          expect(interface.packager).to eq(valid_packager)
        end
      end
    end

    context 'when packager is not in the predefined list' do
      it 'returns nil' do
        allow(dependency).to receive(:packager).and_return('unknown_packager')

        expect(interface.packager).to be_nil
      end
    end

    context 'when packager is nil' do
      it 'returns nil' do
        allow(dependency).to receive(:packager).and_return(nil)

        expect(interface.packager).to be_nil
      end
    end
  end

  describe '#vulnerability_count' do
    context 'when vulnerabilities exist' do
      let(:vulnerabilities) { instance_double(Array, size: 3) }

      it 'returns the count of vulnerabilities' do
        allow(dependency).to receive(:vulnerabilities).and_return(vulnerabilities)

        expect(interface.vulnerability_count).to eq(3)
      end
    end

    context 'when vulnerabilities do not exist' do
      it 'returns 0' do
        allow(dependency).to receive(:vulnerabilities).and_return(nil)

        expect(interface.vulnerability_count).to eq(0)
      end
    end
  end
end
