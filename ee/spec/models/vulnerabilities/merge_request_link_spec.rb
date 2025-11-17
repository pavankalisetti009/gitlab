# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::MergeRequestLink, feature_category: :vulnerability_management do
  describe 'associations and fields' do
    it { is_expected.to belong_to(:vulnerability) }
    it { is_expected.to belong_to(:merge_request) }
    it { is_expected.to have_one(:author).through(:merge_request).class_name("User") }
  end

  describe 'validations' do
    let_it_be(:vulnerability) { create(:vulnerability) }
    let_it_be(:merge_request) { create(:merge_request) }

    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:merge_request) }

    describe 'readiness_score validations' do
      subject(:build_link) do
        build(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      context 'when readiness_score is nil' do
        it 'is valid' do
          build_link.readiness_score = nil

          expect(build_link).to be_valid
        end
      end

      context 'when readiness_score is within valid range' do
        it 'is valid for 0.0' do
          build_link.readiness_score = 0.0

          expect(build_link).to be_valid
        end

        it 'is valid for 1.0' do
          build_link.readiness_score = 1.0

          expect(build_link).to be_valid
        end

        it 'is valid for 0.5' do
          build_link.readiness_score = 0.5

          expect(build_link).to be_valid
        end
      end

      context 'when readiness_score is outside valid range' do
        it 'is invalid for negative values' do
          build_link.readiness_score = -0.1

          expect(build_link).not_to be_valid
          expect(build_link.errors[:readiness_score]).to include('is not included in the list')
        end

        it 'is invalid for values greater than 1.0' do
          build_link.readiness_score = 1.1

          expect(build_link).not_to be_valid
          expect(build_link.errors[:readiness_score]).to include('is not included in the list')
        end
      end

      context 'when readiness_score is not a number' do
        it 'is invalid for string values' do
          build_link.readiness_score = 'invalid'

          expect(build_link).not_to be_valid
          expect(build_link.errors[:readiness_score]).to include('is not a number')
        end
      end
    end
  end

  describe 'class methods' do
    let_it_be(:vulnerability) { create(:vulnerability) }
    let_it_be(:other_vulnerability) { create(:vulnerability) }

    describe '.count_for_vulnerability' do
      before do
        create_list(:vulnerabilities_merge_request_link, 3, vulnerability: vulnerability)
        create_list(:vulnerabilities_merge_request_link, 2, vulnerability: other_vulnerability)
      end

      it 'returns the correct count for the specified vulnerability' do
        expect(described_class.count_for_vulnerability(vulnerability)).to eq(3)
        expect(described_class.count_for_vulnerability(other_vulnerability)).to eq(2)
      end

      it 'returns 0 for a vulnerability with no links' do
        new_vulnerability = create(:vulnerability)
        expect(described_class.count_for_vulnerability(new_vulnerability)).to eq(0)
      end
    end

    describe '.limit_exceeded_for_vulnerability?' do
      context 'when under the limit' do
        before do
          allow(described_class).to receive(:count_for_vulnerability)
            .with(vulnerability)
            .and_return(50)
        end

        it 'returns false' do
          expect(described_class.limit_exceeded_for_vulnerability?(vulnerability)).to be false
        end
      end

      context 'when at the limit' do
        before do
          stub_const('Vulnerabilities::MergeRequestLink::MAX_MERGE_REQUEST_LINKS_PER_VULNERABILITY', 1)
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
        end

        it 'returns true' do
          expect(described_class.limit_exceeded_for_vulnerability?(vulnerability)).to be true
        end
      end

      it 'returns false for a vulnerability with no links' do
        new_vulnerability = create(:vulnerability)
        expect(described_class.limit_exceeded_for_vulnerability?(new_vulnerability)).to be false
      end
    end

    describe '.find_by_vulnerability_and_merge_request' do
      let_it_be(:merge_request) { create(:merge_request) }
      let_it_be(:other_merge_request) { create(:merge_request) }
      let_it_be(:merge_request_link) do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns the link when both vulnerability and merge request match' do
        result = described_class.find_by_vulnerability_and_merge_request(vulnerability, merge_request)

        expect(result).to eq(merge_request_link)
        expect(result.vulnerability).to eq(vulnerability)
        expect(result.merge_request).to eq(merge_request)
      end

      it 'returns nil when vulnerability does not match' do
        result = described_class.find_by_vulnerability_and_merge_request(other_vulnerability, merge_request)

        expect(result).to be_nil
      end

      it 'returns nil when merge request does not match' do
        result = described_class.find_by_vulnerability_and_merge_request(vulnerability, other_merge_request)

        expect(result).to be_nil
      end

      it 'returns nil when both vulnerability and merge request do not match' do
        result = described_class.find_by_vulnerability_and_merge_request(other_vulnerability, other_merge_request)

        expect(result).to be_nil
      end

      it 'returns nil when no links exist' do
        new_vulnerability = create(:vulnerability)
        new_merge_request = create(:merge_request)

        result = described_class.find_by_vulnerability_and_merge_request(new_vulnerability, new_merge_request)

        expect(result).to be_nil
      end
    end
  end

  context 'with loose foreign key on vulnerability_merge_request_links.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_merge_request_link, project_id: parent.id) }
    end
  end

  context 'with loose foreign key on vulnerability_merge_request_links.merge_request_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:merge_request) }
      let_it_be(:model) { create(:vulnerabilities_merge_request_link, merge_request: parent) }
    end
  end
end
