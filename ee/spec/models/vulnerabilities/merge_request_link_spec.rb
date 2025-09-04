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
