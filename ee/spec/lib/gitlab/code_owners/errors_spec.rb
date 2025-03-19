# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::Errors, feature_category: :source_code_management do
  subject(:errors) { described_class.new }

  describe '::new' do
    it { is_expected.to be_kind_of(Enumerable) }
    it { is_expected.to be_empty }
    it { is_expected.to respond_to(:each) }
    it { is_expected.to respond_to(:size) }
  end

  describe '#add(message, line_number)' do
    let(:error_class) { Gitlab::CodeOwners::Error }
    let(:error) { instance_double(error_class) }
    let(:message) { 'message' }
    let(:line_number) { 'line_number' }

    before do
      allow(error_class).to receive(:new).and_return(error)
      errors.add(message, line_number)
    end

    it { is_expected.not_to be_empty }
    it { expect(errors.first).to eq(error) }
    it { expect(error_class).to have_received(:new).with(message, line_number) }
  end
end
