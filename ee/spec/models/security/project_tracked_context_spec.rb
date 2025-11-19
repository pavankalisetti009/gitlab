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

    describe 'is_default' do
      context 'when there is an existing default ref' do
        let_it_be(:existing_ref) { create(:security_project_tracked_context, :default, project: project) }

        it 'fails validation if trying to create a new default ref' do
          new_ref.is_default = true

          expect(new_ref).not_to be_valid
          expect(new_ref.errors[:is_default]).to include('There is already a default tracked context')
        end

        it 'passes validation if ref is not default' do
          new_ref.is_default = false

          expect(new_ref).to be_valid
        end
      end
    end

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

  describe '.for_pipeline' do
    let_it_be(:branch_context) { create(:security_project_tracked_context, context_type: :branch, project: project) }
    let_it_be(:tag_context) { create(:security_project_tracked_context, context_type: :tag, project: project) }

    before_all do
      other_project = create(:project)
      create(:ci_pipeline, :tag, ref: tag_context.context_name, project: other_project)
      create(:ci_pipeline, ref: branch_context.context_name, project: other_project)
      create(:security_project_tracked_context,
        context_name: branch_context.context_name,
        context_type: :branch,
        project: other_project
      )
      create(:security_project_tracked_context,
        context_name: tag_context.context_name,
        context_type: :tag,
        project: other_project
      )
    end

    context 'with a branch pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, ref: branch_context.context_name, project: project) }

      it 'returns refs matching the pipeline ref and type' do
        expect(described_class.for_pipeline(pipeline)).to contain_exactly(branch_context)
      end
    end

    context 'with a tag pipeline' do
      let_it_be(:pipeline) { create(:ci_pipeline, :tag, ref: tag_context.context_name, project: project) }

      it 'returns refs matching the pipeline ref and type' do
        expect(described_class.for_pipeline(pipeline)).to contain_exactly(tag_context)
      end
    end

    context 'when no matching ref exists' do
      let_it_be(:pipeline) { create(:ci_pipeline, ref: 'non-existent-branch', project: project) }

      it 'returns an empty relation' do
        expect(described_class.for_pipeline(pipeline)).to be_empty
      end
    end
  end

  describe '.find_by_pipeline' do
    let_it_be(:tracked_branch_ref) do
      create(:security_project_tracked_context, :tracked, project: project, context_name: 'feature-branch')
    end

    let_it_be(:untracked_branch_ref) do
      create(:security_project_tracked_context, project: project, context_name: 'untracked-branch')
    end

    let_it_be(:tracked_tag_ref) do
      create(:security_project_tracked_context, :tracked, :tag, project: project, context_name: 'v1.0.0')
    end

    subject(:find_by_pipeline) { described_class.find_by_pipeline(pipeline) }

    context 'with a tracked branch pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: tracked_branch_ref.context_name) }

      it 'returns the tracked context' do
        expect(find_by_pipeline).to eq(tracked_branch_ref)
      end
    end

    context 'with an untracked branch pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: untracked_branch_ref.context_name) }

      it 'returns nil' do
        expect(find_by_pipeline).to be_nil
      end
    end

    context 'with a tracked tag pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, :tag, project: project, ref: tracked_tag_ref.context_name) }

      it 'returns the tracked context' do
        expect(find_by_pipeline).to eq(tracked_tag_ref)
      end
    end

    context 'when no matching ref exists' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: 'non-existent-branch') }

      it 'returns nil' do
        expect(find_by_pipeline).to be_nil
      end
    end
  end

  describe '.tracked_pipeline?' do
    let_it_be(:tracked_branch_ref) do
      create(:security_project_tracked_context, :tracked, project: project, context_name: 'feature-branch')
    end

    let_it_be(:untracked_branch_ref) do
      create(:security_project_tracked_context, project: project, context_name: 'untracked-branch')
    end

    subject(:tracked_pipeline?) { described_class.tracked_pipeline?(pipeline) }

    context 'with a tracked pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: tracked_branch_ref.context_name) }

      it { is_expected.to be true }
    end

    context 'with an untracked pipeline' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: untracked_branch_ref.context_name) }

      it { is_expected.to be false }
    end

    context 'when no matching ref exists' do
      let_it_be(:pipeline) { build_stubbed(:ci_pipeline, project: project, ref: 'non-existent-branch') }

      it { is_expected.to be false }
    end
  end
end
