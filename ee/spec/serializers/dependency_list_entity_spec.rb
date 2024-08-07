# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyListEntity do
  describe '#as_json' do
    let(:entity) do
      described_class.represent(items, build: ci_build, request: request)
    end

    let(:request) { EntityRequest.new(project: project, user: user) }
    let(:name) { :dependencies }
    let(:collection) { [build(:dependency)] }
    let(:no_items_status) { :no_dependencies }

    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted records
    let_it_be(:project) { create(:project, :repository, :private) }
    let_it_be(:developer) { create(:user) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject(:as_json) { entity.as_json }

    before_all do
      project.add_developer(developer)
    end

    context 'with success build' do
      let(:user) { developer }
      let(:ci_build) { build_stubbed(:ee_ci_build, :success) }

      context 'with provided items' do
        let(:items) { collection }

        it 'has array of items with status ok' do
          job_path = "/#{project.full_path}/builds/#{ci_build.id}"

          expect(as_json[name]).to be_kind_of(Array)
          expect(as_json[:report][:status]).to eq(:ok)
          expect(as_json[:report][:job_path]).to eq(job_path)
          expect(as_json[:report][:generated_at]).to eq(ci_build.finished_at)
        end
      end

      context 'with no items' do
        let(:user) { developer }
        let(:items) { [] }

        it 'has empty array of items with status no_items' do
          job_path = "/#{project.full_path}/builds/#{ci_build.id}"

          expect(as_json[name].length).to eq(0)
          expect(as_json[:report][:status]).to eq(no_items_status)
          expect(as_json[:report][:job_path]).to eq(job_path)
        end
      end
    end

    context 'with failed build' do
      let(:ci_build) { build_stubbed(:ee_ci_build, :failed) }
      let(:items) { [] }

      context 'with authorized user' do
        let(:user) { developer }

        it 'has job_path with status failed_job' do
          expect(as_json[:report][:status]).to eq(:job_failed)
          expect(as_json[:report]).to include(:job_path)
        end
      end

      context 'without authorized user' do
        let(:user) { build_stubbed(:user) }

        it 'has only status failed_job' do
          expect(as_json[:report][:status]).to eq(:job_failed)
          expect(as_json[:report]).not_to include(:job_path)
          expect(as_json[:report]).not_to include(:generated_at)
        end
      end
    end

    context 'with no build' do
      let(:user) { developer }
      let(:ci_build) { nil }
      let(:items) { [] }

      it 'has status job_not_set_up and no job_path' do
        expect(as_json[:report][:status]).to eq(:job_not_set_up)
        expect(as_json[:report][:job_path]).not_to be_present
        expect(as_json[:report][:generated_at]).not_to be_present
      end

      context 'without an associated project' do
        before do
          allow(request).to receive(:project).and_return(nil)
        end

        it 'returns a no_items status' do
          expect(as_json[:report][:status]).to eq(no_items_status)
        end

        context 'with items are present' do
          let(:items) { collection }

          it 'returns a ok status' do
            expect(as_json[:report][:status]).to eq(:ok)
          end
        end
      end
    end
  end
end
