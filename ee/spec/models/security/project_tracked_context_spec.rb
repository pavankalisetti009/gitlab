# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ProjectTrackedContext, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    subject(:new_ref) { build(:security_project_tracked_context, project: project) }

    it { is_expected.to validate_presence_of(:context_name) }
    it { is_expected.to validate_presence_of(:context_type) }
    it { is_expected.to validate_length_of(:context_name).is_at_most(1024) }
    it { is_expected.to validate_uniqueness_of(:context_name).scoped_to([:project_id, :context_type]) }

    it 'is invalid when trying to make a tag ref default' do
      new_ref.context_type = :tag
      new_ref.is_default = true

      expect(new_ref).not_to be_valid
      expect(new_ref.errors[:base]).to include('only branch refs can be default')
    end

    describe 'tracked_refs_limit' do
      it 'allows up to MAX_TRACKED_REFS_PER_PROJECT tracked refs' do
        create_list(:security_project_tracked_context, described_class::MAX_TRACKED_REFS_PER_PROJECT - 1, :tracked,
          project: project)

        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref).to be_valid
      end

      it 'prevents exceeding MAX_TRACKED_REFS_PER_PROJECT tracked refs' do
        create_list(:security_project_tracked_context, described_class::MAX_TRACKED_REFS_PER_PROJECT, :tracked,
          project: project)

        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref).not_to be_valid
        expect(ref.errors[:base]).to include(
          "cannot exceed #{described_class::MAX_TRACKED_REFS_PER_PROJECT} tracked refs per project"
        )
      end

      it 'allows unlimited untracked refs' do
        stub_const("#{described_class}::MAX_TRACKED_REFS_PER_PROJECT", 1)
        create_list(:security_project_tracked_context, 2, project: project)

        ref = build(:security_project_tracked_context, project: project)
        expect(ref).to be_valid
      end
    end

    describe 'default_ref_cannot_be_untracked' do
      # This is only true until we build the long term quota system
      it 'prevents default refs from being untracked' do
        ref = build(:security_project_tracked_context, :default, :untracked, project: project)
        expect(ref).not_to be_valid
        expect(ref.errors[:base]).to include('default ref must be tracked')
      end

      it 'allows default refs to be tracked' do
        ref = build(:security_project_tracked_context, :default, project: project)
        expect(ref).to be_valid
      end

      it 'allows non-default refs to be untracked' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref).to be_valid
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:context_type).with_values(branch: 1, tag: 2) }
  end

  describe 'state machine events' do
    let_it_be(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let_it_be(:untracked_ref) { create(:security_project_tracked_context, project: project) }

    describe '#archive!' do
      it 'transitions from untracked to archiving' do
        expect(untracked_ref.archive!).to be_truthy
        expect(untracked_ref.reload.state_name).to eq(:archiving)
      end

      it 'transitions from tracked to archiving' do
        expect(tracked_ref.archive!).to be_truthy
        expect(tracked_ref.reload.state_name).to eq(:archiving)
      end

      it 'returns false when called on archiving state' do
        archiving_ref = create(:security_project_tracked_context, :archiving, project: project)
        expect { archiving_ref.archive! }.to raise_error(StateMachines::InvalidTransition)
      end

      it 'returns false when called on deleting state' do
        deleting_ref = create(:security_project_tracked_context, :deleting, project: project)
        expect { deleting_ref.archive! }.to raise_error(StateMachines::InvalidTransition)
      end
    end

    describe '#remove!' do
      it 'transitions from untracked to deleting' do
        expect(untracked_ref.remove!).to be_truthy
        expect(untracked_ref.reload.state_name).to eq(:deleting)
      end

      it 'transitions from tracked to deleting' do
        tracked_ref_for_remove = create(:security_project_tracked_context, :tracked, project: project)
        expect(tracked_ref_for_remove.remove!).to be_truthy
        expect(tracked_ref_for_remove.reload.state_name).to eq(:deleting)
      end

      it 'transitions from archiving to deleting' do
        archiving_ref = create(:security_project_tracked_context, :archiving, project: project)
        expect(archiving_ref.remove!).to be_truthy
        expect(archiving_ref.reload.state_name).to eq(:deleting)
      end

      it 'allows deleting from deleting state' do
        deleting_ref = create(:security_project_tracked_context, :deleting, project: project)
        expect(deleting_ref.remove!).to be_truthy
        expect(deleting_ref.reload.state_name).to eq(:deleting)
      end
    end
  end

  describe 'state transition validations' do
    describe 'archive event' do
      it 'allows transition from untracked to archiving' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.can_archive?).to be_truthy
      end

      it 'allows transition from tracked to archiving' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.can_archive?).to be_truthy
      end

      it 'does not allow transition from archiving to archiving' do
        ref = build(:security_project_tracked_context, :archiving, project: project)
        expect(ref.can_archive?).to be_falsey
      end

      it 'does not allow transition from deleting to archiving' do
        ref = build(:security_project_tracked_context, :deleting, project: project)
        expect(ref.can_archive?).to be_falsey
      end
    end

    describe 'remove event' do
      it 'allows transition from untracked to deleting' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.can_remove?).to be_truthy
      end

      it 'allows transition from tracked to deleting' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.can_remove?).to be_truthy
      end

      it 'allows transition from archiving to deleting' do
        ref = build(:security_project_tracked_context, :archiving, project: project)
        expect(ref.can_remove?).to be_truthy
      end

      it 'allows transition from deleting to deleting' do
        ref = build(:security_project_tracked_context, :deleting, project: project)
        expect(ref.can_remove?).to be_truthy
      end
    end
  end

  describe 'state predicate methods' do
    describe '#untracked?' do
      it 'returns true when state is untracked' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.untracked?).to be_truthy
      end

      it 'returns false when state is not untracked' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.untracked?).to be_falsey
      end
    end

    describe '#tracked?' do
      it 'returns true when state is tracked' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.tracked?).to be_truthy
      end

      it 'returns false when state is not tracked' do
        ref = build(:security_project_tracked_context, project: project)
        expect(ref.tracked?).to be_falsey
      end
    end

    describe '#archiving?' do
      it 'returns true when state is archiving' do
        ref = build(:security_project_tracked_context, :archiving, project: project)
        expect(ref.archiving?).to be_truthy
      end

      it 'returns false when state is not archiving' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.archiving?).to be_falsey
      end
    end

    describe '#deleting?' do
      it 'returns true when state is deleting' do
        ref = build(:security_project_tracked_context, :deleting, project: project)
        expect(ref.deleting?).to be_truthy
      end

      it 'returns false when state is not deleting' do
        ref = build(:security_project_tracked_context, :tracked, project: project)
        expect(ref.deleting?).to be_falsey
      end
    end
  end

  describe 'scopes' do
    let_it_be(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let_it_be(:untracked_ref) { create(:security_project_tracked_context, project: project) }
    let_it_be(:default_ref) { create(:security_project_tracked_context, :default, project: project) }
    let_it_be(:other_project_ref) { create(:security_project_tracked_context, :tracked) }
    let_it_be(:archiving_ref) { create(:security_project_tracked_context, :archiving, project: project) }
    let_it_be(:deleting_ref) { create(:security_project_tracked_context, :deleting, project: project) }

    describe '.tracked' do
      it 'returns only tracked refs' do
        expect(described_class.tracked).to contain_exactly(tracked_ref, default_ref, other_project_ref)
      end
    end

    describe '.untracked' do
      it 'returns only untracked refs' do
        expect(described_class.untracked).to contain_exactly(untracked_ref)
      end
    end

    describe '.archiving' do
      it 'returns only archiving refs' do
        expect(described_class.archiving).to contain_exactly(archiving_ref)
      end
    end

    describe '.deleting' do
      it 'returns only deleting refs' do
        expect(described_class.deleting).to contain_exactly(deleting_ref)
      end
    end

    describe '.for_project' do
      it 'returns refs for the specified project' do
        expect(described_class.for_project(project.id)).to contain_exactly(tracked_ref, untracked_ref, default_ref,
          archiving_ref, deleting_ref)
      end
    end

    describe '.default_refs' do
      it 'returns only default refs' do
        expect(described_class.default_refs).to contain_exactly(default_ref)
      end
    end

    describe '.for_ref' do
      it 'returns refs with matching context_name that are branches or tags' do
        expect(described_class.for_ref(tracked_ref.context_name)).to contain_exactly(tracked_ref)
        expect(described_class.for_ref(default_ref.context_name)).to contain_exactly(default_ref)
      end

      it 'returns empty when no matching refs exist' do
        expect(described_class.for_ref('nonexistent-ref')).to be_empty
      end
    end
  end
end
