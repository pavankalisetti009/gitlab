# frozen_string_literal: true

RSpec.shared_examples 'a local virtual registry object' do
  subject { described_class.new }

  it { is_expected.to include_module(::VirtualRegistries::Local) }

  describe '#local?' do
    it { is_expected.to be_local }
  end

  describe '#remote?' do
    it { is_expected.not_to be_remote }
  end
end
