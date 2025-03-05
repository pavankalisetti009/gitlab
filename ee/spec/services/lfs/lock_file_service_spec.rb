# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Lfs::LockFileService, feature_category: :source_code_management do
  let(:project)      { create(:project) }
  let(:current_user) { create(:user) }
  let(:create_path_lock) { true }
  let(:params) { { path: 'README.md', create_path_lock: create_path_lock } }

  subject { described_class.new(project, current_user, params) }

  describe '#execute' do
    context 'when authorized' do
      before do
        project.add_developer(current_user)
      end

      context 'when File Locking is available' do
        before do
          stub_licensed_features(file_locks: true)
        end

        it 'creates the Path Lock' do
          expect { subject.execute }.to change { PathLock.count }.to(1)
        end

        context 'when the lfs file was not locked successfully' do
          before do
            allow(subject).to receive(:create_lock!).and_return({ status: :error })
          end

          it 'does not create a Path Lock' do
            expect { subject.execute }.not_to change { PathLock.count }
          end
        end

        context 'when create_path_lock is false' do
          let(:create_path_lock) { false }

          it 'does not create a Path Lock' do
            expect { subject.execute }.not_to change { PathLock.count }
          end
        end
      end

      context 'when File Locking is not available' do
        before do
          stub_licensed_features(file_locks: false)
        end

        it 'does not create the Path Lock' do
          expect { subject.execute }.not_to change { PathLock.count }
        end
      end
    end
  end
end
