# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::CodeOwners::RolesLoader, feature_category: :source_code_management do
  let(:text) do
    <<~TXT
    This is a long text that mentions some roles.
    @@developer and @@maintainer take a walk in the park.
    There they meet @@norole and @user another @@developer
    TXT
  end

  let(:extractor) { Gitlab::CodeOwners::ReferenceExtractor.new(text) }
  let_it_be(:project) { create(:project, :public) }
  let(:entry) { instance_double(Gitlab::CodeOwners::Entry) }

  describe '#load_to' do
    subject(:load_roles) do
      described_class.new(project, extractor).load_to([entry])
    end

    before do
      allow(entry).to receive(:add_matching_roles_from)
    end

    context 'with input that has no matching default roles' do
      let(:text) { 'My test' }

      it 'returns an empty list of roles' do
        load_roles

        expect(entry).to have_received(:add_matching_roles_from).with([])
      end
    end

    context 'with nil input' do
      let(:text) { nil }

      it 'returns an empty list of roles' do
        load_roles

        expect(entry).to have_received(:add_matching_roles_from).with([])
      end
    end

    context 'with an input that matches default roles' do
      let(:project) { create(:project, :private) }

      it 'returns the default roles as an array of integers' do
        load_roles

        expect(entry).to have_received(:add_matching_roles_from).with([Gitlab::Access::DEVELOPER,
          Gitlab::Access::MAINTAINER])
      end
    end
  end
end
