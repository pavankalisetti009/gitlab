# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::TrackedRefType, feature_category: :vulnerability_management do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  before_all { project.add_developer(user) }

  specify { expect(described_class).to require_graphql_authorizations(:read_security_project_tracked_refs) }

  describe 'custom field resolvers' do
    let_it_be(:tracked_ref) { create(:security_project_tracked_context, :tracked, project: project) }
    let(:type_instance) { described_class.send(:new, tracked_ref, {}) }

    describe '#state' do
      where(:tracked_status, :expected_state) do
        true  | 'TRACKED'
        false | 'UNTRACKED'
      end

      with_them do
        it "returns correct state" do
          allow(tracked_ref).to receive(:tracked?).and_return(tracked_status)
          expect(type_instance.state).to eq(expected_state)
        end
      end
    end

    describe '#vulnerabilities_count' do
      it 'returns count of vulnerability reads' do
        allow(tracked_ref).to receive_message_chain(:vulnerability_reads, :count).and_return(5)
        expect(type_instance.vulnerabilities_count).to eq(5)
      end

      it 'returns 0 when error occurs' do
        allow(tracked_ref).to receive(:vulnerability_reads).and_raise(StandardError, 'DB error')
        expect(type_instance.vulnerabilities_count).to eq(0)
      end
    end

    describe '#protected?' do
      before do
        allow(type_instance).to receive_messages(project: project)
      end

      where(:context_type, :ref_exists, :has_protected_match, :expected_result) do
        'branch'   | true  | true  | true
        'branch'   | true  | false | false
        'branch'   | false | false | false
        'tag'      | true  | true  | true
        'tag'      | true  | false | false
        'tag'      | false | false | false
        'unknown'  | true  | false | false
      end

      with_them do
        it "returns correct protection status" do
          allow(type_instance).to receive(:ref_exists_in_repository?).and_return(ref_exists)
          allow(tracked_ref).to receive(:context_type).and_return(context_type)

          if context_type == 'branch'
            matching_result = has_protected_match ? [instance_double(ProtectedBranch)] : []
            allow(project).to receive_message_chain(:protected_branches, :matching).and_return(matching_result)
          elsif context_type == 'tag'
            matching_result = has_protected_match ? [instance_double(ProtectedTag)] : []
            allow(project).to receive_message_chain(:protected_tags, :matching).and_return(matching_result)
          end

          expect(type_instance.protected?).to eq(expected_result)
        end
      end
    end

    describe '#commit' do
      before do
        allow(type_instance).to receive(:project).and_return(project)
      end

      where(:context_type, :ref_exists, :raw_commit_result, :expected_result) do
        'branch' | false | nil           | nil
        'tag'    | false | nil           | nil
        'branch' | true  | 'raw_commit'  | 'commit_object'
        'tag'    | true  | 'raw_commit'  | 'commit_object'
        'branch' | true  | nil           | nil
        'tag'    | true  | nil           | nil
      end

      with_them do
        it "handles different commit scenarios" do
          allow(type_instance).to receive(:ref_exists_in_repository?).and_return(ref_exists)
          allow(tracked_ref).to receive(:context_type).and_return(context_type)

          if ref_exists
            allow(type_instance).to receive(:fetch_raw_commit).and_return(raw_commit_result)

            if raw_commit_result
              expect(Commit).to receive(:new).with(raw_commit_result, project).and_return('commit_object')
            end
          end

          expect(type_instance.commit).to eq(expected_result)
        end
      end

      where(:error_type) do
        [Gitlab::Git::Repository::NoRepository]
        [Rugged::ReferenceError]
      end

      with_them do
        it "handles repository errors gracefully" do
          allow(type_instance).to receive(:ref_exists_in_repository?).and_return(true)
          allow(type_instance).to receive(:fetch_raw_commit).and_raise(error_type)

          expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
            an_instance_of(error_type),
            hash_including(project_id: project.id, ref_name: tracked_ref.context_name)
          )

          expect(type_instance.commit).to be_nil
        end
      end
    end

    describe '#fetch_raw_commit' do
      before do
        allow(type_instance).to receive(:project).and_return(project)
      end

      where(:context_type, :setup_method, :expected_result) do
        'branch'       | :setup_branch  | 'branch_commit'
        'tag'          | :setup_tag     | 'tag_commit'
        'tag'          | :setup_nil_tag | nil
        'unknown_type' | nil            | nil
        'invalid'      | nil            | nil
        ''             | nil            | nil
      end

      with_them do
        it "handles different context types correctly" do
          allow(tracked_ref).to receive(:context_type).and_return(context_type)

          case setup_method
          when :setup_branch
            allow(project).to receive_message_chain(:repository, :commit).and_return('branch_commit')
          when :setup_tag
            tag = instance_double(Gitlab::Git::Tag, dereferenced_target: 'tag_commit')
            allow(project).to receive_message_chain(:repository, :find_tag).and_return(tag)
          when :setup_nil_tag
            allow(project).to receive_message_chain(:repository, :find_tag).and_return(nil)
          end

          expect(type_instance.send(:fetch_raw_commit)).to eq(expected_result)
        end
      end
    end

    describe '#ref_exists_in_repository?' do
      before do
        allow(type_instance).to receive(:project).and_return(project)
      end

      where(:repository_exists, :context_type, :ref_exists_result, :expected_result) do
        false   | 'branch'   | true  | false
        false   | 'tag'      | true  | false
        false   | 'unknown'  | true  | false
        true    | 'branch'   | true  | true
        true    | 'branch'   | false | false
        true    | 'tag'      | true  | true
        true    | 'tag'      | false | false
        true    | 'unknown'  | true  | false
        true    | 'invalid'  | true  | false
        true    | ''         | true  | false
      end

      with_them do
        it "handles different repository and context scenarios" do
          allow(project).to receive(:repository_exists?).and_return(repository_exists)
          allow(tracked_ref).to receive(:context_type).and_return(context_type)

          if repository_exists && context_type == 'branch'
            allow(project).to receive_message_chain(:repository, :branch_exists?).and_return(ref_exists_result)
          elsif repository_exists && context_type == 'tag'
            allow(project).to receive_message_chain(:repository, :tag_exists?).and_return(ref_exists_result)
          end

          expect(type_instance.send(:ref_exists_in_repository?)).to eq(expected_result)
        end
      end
    end

    describe 'connection type' do
      it 'uses CountableConnectionType for pagination with count' do
        expect(described_class.connection_type_class).to eq(Types::CountableConnectionType)
      end
    end
  end
end
