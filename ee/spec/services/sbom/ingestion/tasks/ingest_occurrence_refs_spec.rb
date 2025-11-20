# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::Tasks::IngestOccurrenceRefs, feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let(:pipeline) { create(:ci_pipeline, project: project, ref: 'main') }
  let(:occurrence) { create(:sbom_occurrence, project: project, pipeline: pipeline) }

  let(:occurrence_map) do
    build(:sbom_occurrence_map).tap do |map|
      map.occurrence_id = occurrence.id
    end
  end

  let(:occurrence_maps) { [occurrence_map] }

  before do
    allow(project).to receive(:default_branch).and_return('main')
    allow(project.repository).to receive(:branch_exists?).with(pipeline.ref).and_return(true)
  end

  subject(:task) { described_class.new(pipeline, occurrence_maps) }

  describe '#execute' do
    context 'when tracked context exists for branch' do
      let!(:tracked_context) do
        create(:security_project_tracked_context,
          :tracked,
          project: project,
          context_name: pipeline.ref,
          context_type: :branch)
      end

      it 'creates occurrence refs' do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(1)

        ref = Sbom::OccurrenceRef.last
        expect(ref.sbom_occurrence_id).to eq(occurrence.id)
        expect(ref.security_project_tracked_context_id).to eq(tracked_context.id)
        expect(ref.pipeline).to eq(pipeline)
        expect(ref.project).to eq(project)
        expect(ref.commit_sha).to eq(pipeline.sha)
      end
    end

    context 'when tracked context exists for tag' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'v1.0', tag: true) }

      let!(:tag_context) do
        create(:security_project_tracked_context, :tracked, project: project, context_name: pipeline.ref,
          context_type: :tag)
      end

      before do
        allow(project.repository).to receive(:find_tag).with('v1.0').and_return(instance_double(Gitlab::Git::Tag,
          target_commit: pipeline.sha))
      end

      it 'finds tag context for tag pipeline' do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(1)

        ref = Sbom::OccurrenceRef.last
        expect(ref.tracked_context).to eq(tag_context)
      end
    end

    context 'when tracked context does not exist and is default branch' do
      it 'creates tracked context and occurrence ref' do
        expect { task.execute }
          .to change { Security::ProjectTrackedContext.count }.by(1)
          .and change { Sbom::OccurrenceRef.count }.by(1)

        created_context = Security::ProjectTrackedContext.last
        expect(created_context.context_name).to eq('main')
        expect(created_context.context_type).to eq('branch')
        expect(created_context.is_default).to be(true)
        expect(created_context.project).to eq(project)
      end
    end

    context 'when occurrence_map has no occurrence_id' do
      let(:occurrence_map) { build(:sbom_occurrence_map) }

      it 'does not create occurrence ref' do
        expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }
      end
    end

    context 'when multiple occurrence maps exist' do
      let(:occurrence2) { create(:sbom_occurrence, project: project, pipeline: pipeline) }
      let(:occurrence_map2) do
        map = build(:sbom_occurrence_map)
        map.occurrence_id = occurrence2.id
        map
      end

      let(:occurrence_maps) { [occurrence_map, occurrence_map2] }
      let!(:tracked_context) do
        create(:security_project_tracked_context, :tracked, project: project, context_name: pipeline.ref,
          context_type: :branch)
      end

      it 'creates occurrence refs for all valid maps' do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(2)

        refs = Sbom::OccurrenceRef.last(2)
        expect(refs.map(&:sbom_occurrence_id)).to match_array([occurrence.id, occurrence2.id])
        expect(refs.map(&:tracked_context)).to all(eq(tracked_context))
      end
    end

    context 'when finding/creating tracked context fails' do
      before do
        allow_next_instance_of(described_class) do |task|
          allow(task).to receive(:tracked_context).and_return(nil)
        end
      end

      it 'does not create occurrence ref' do
        expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }
      end
    end

    context 'when pipeline is not on default branch' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

      before do
        allow(project.repository).to receive(:branch_exists?).with('feature-branch').and_return(false)
      end

      it 'does not create tracked context or occurrence ref' do
        expect { task.execute }
          .to not_change { Security::ProjectTrackedContext.count }
          .and not_change { Sbom::OccurrenceRef.count }
      end
    end

    context 'when no occurrence maps exist' do
      let(:occurrence_maps) { [] }

      it 'does not create any occurrence refs' do
        expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }
      end
    end

    context 'when pipeline has tag but tag does not exist in repository' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'v1.0', tag: true) }

      before do
        allow(project.repository).to receive(:find_tag).with('v1.0').and_return(nil)
      end

      it 'does not create occurrence refs' do
        expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }
      end
    end
  end

  describe 'edge cases' do
    context 'when no tracked context exists and branch does not exist in repository' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }

      before do
        allow(project.repository).to receive(:branch_exists?).with('feature-branch').and_return(false)
      end

      it 'does not create occurrence refs' do
        expect { task.execute }.not_to change { Sbom::OccurrenceRef.count }
      end
    end

    context 'when tracked context creation fails for default branch' do
      before do
        16.times do |i|
          create(:security_project_tracked_context, :tracked, project: project, context_name: "branch-#{i}")
        end
      end

      it 'raises validation error and does not create occurrence ref' do
        expect { task.execute }.to raise_error(ActiveRecord::RecordInvalid, /cannot exceed 16 tracked refs/)
          .and not_change { Sbom::OccurrenceRef.count }
      end
    end

    context 'when untracked context exists for branch' do
      let!(:untracked_context) do
        create(:security_project_tracked_context, :untracked,
          project: project,
          context_name: pipeline.ref,
          context_type: :branch)
      end

      it 'uses existing untracked context' do
        expect { task.execute }.to change { Sbom::OccurrenceRef.count }.by(1)
          .and not_change { Security::ProjectTrackedContext.count }

        ref = Sbom::OccurrenceRef.last
        expect(ref.tracked_context).to eq(untracked_context)
      end
    end

    context 'when tracked context exists for non-default branch' do
      let(:pipeline) { create(:ci_pipeline, project: project, ref: 'feature-branch') }
      let!(:tracked_context) do
        create(:security_project_tracked_context, :tracked,
          project: project,
          context_name: 'feature-branch',
          context_type: :branch)
      end

      before do
        allow(project.repository).to receive(:branch_exists?).with('feature-branch').and_return(true)
      end

      it 'creates occurrence refs using existing context' do
        expect { task.execute }
          .to change { Sbom::OccurrenceRef.count }.by(1)
          .and not_change { Security::ProjectTrackedContext.count }

        occurrence_ref = Sbom::OccurrenceRef.last
        expect(occurrence_ref.tracked_context).to eq(tracked_context)
      end
    end
  end
end
