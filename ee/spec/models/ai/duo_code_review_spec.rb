# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoCodeReview, feature_category: :code_suggestions do
  let_it_be(:group) { build_stubbed(:group) }
  let_it_be(:project) { build_stubbed(:project, group: group) }
  let_it_be(:merge_request) { build_stubbed(:merge_request, source_project: project) }
  let_it_be(:user) { build_stubbed(:user, developer_of: project) }

  describe '.enabled?' do
    let(:active_mode) { instance_double(Ai::DuoCodeReview::Modes::Base, enabled?: double) }

    shared_examples 'delegates to ModeResolver.enabled?' do
      it 'delegates to ModeResolver.enabled?' do
        expect(Ai::DuoCodeReview::ModeResolver)
          .to receive(:new)
          .with(user: user, container: container)
          .and_return(active_mode)

        expect(active_mode).to receive(:enabled?)

        described_class.enabled?(user: user, container: container)
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      include_examples 'delegates to ModeResolver.enabled?'
    end

    context 'when container is a project' do
      let(:container) { project }

      include_examples 'delegates to ModeResolver.enabled?'
    end
  end

  describe '.mode' do
    let(:active_mode) { instance_double(Ai::DuoCodeReview::Modes::Base, mode: double) }

    shared_examples 'delegates to ModeResolver.mode' do
      it 'delegates to ModeResolver.mode' do
        expect(Ai::DuoCodeReview::ModeResolver)
          .to receive(:new)
          .with(user: user, container: container)
          .and_return(active_mode)

        expect(active_mode).to receive(:mode)

        described_class.mode(user: user, container: container)
      end
    end

    context 'when container is a group' do
      let(:container) { group }

      include_examples 'delegates to ModeResolver.mode'
    end

    context 'when container is a project' do
      let(:container) { project }

      include_examples 'delegates to ModeResolver.mode'
    end
  end
end
