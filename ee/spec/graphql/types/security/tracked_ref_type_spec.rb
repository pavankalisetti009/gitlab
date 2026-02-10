# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Security::TrackedRefType, feature_category: :vulnerability_management do
  include GraphqlHelpers
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  before_all { project.add_developer(user) }

  specify { expect(described_class).to require_graphql_authorizations(:read_security_project_tracked_ref) }

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
      let_it_be(:expected_reads) do
        create_list(:vulnerability_read, 5, project: project, tracked_context: tracked_ref)
      end

      let_it_be(:other_reads) do
        create_list(:vulnerability_read, 5)
      end

      it 'returns count of vulnerability reads' do
        expect(type_instance.vulnerabilities_count).to eq(expected_reads.count)
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

      context 'when ref does not exist in repository' do
        it 'returns nil' do
          allow(type_instance).to receive(:ref_exists_in_repository?).and_return(false)
          expect(type_instance.commit).to be_nil
        end
      end

      context 'when ref exists in repository' do
        before do
          allow(type_instance).to receive(:ref_exists_in_repository?).and_return(true)
        end

        where(:context_type, :ref_name, :has_commit, :expected_result) do
          'branch'  | 'main'    | true  | :commit_object
          'branch'  | 'main'    | false | nil
          'tag'     | 'v1.0.0'  | true  | :commit_object
          'tag'     | 'v1.0.0'  | false | nil
        end

        with_them do
          it "handles #{params[:context_type]} context returning #{params[:expected_result] || 'nil'}" do
            allow(tracked_ref).to receive_messages(
              context_type: context_type,
              context_name: ref_name
            )

            qualified_ref = case context_type
                            when 'branch' then "#{Gitlab::Git::BRANCH_REF_PREFIX}#{ref_name}"
                            when 'tag' then "#{Gitlab::Git::TAG_REF_PREFIX}#{ref_name}"
                            end

            commit_result = has_commit ? instance_double(Commit) : nil
            allow(project).to receive_message_chain(:repository, :commit)
              .with(qualified_ref).and_return(commit_result)

            result = type_instance.commit

            if expected_result == :commit_object && has_commit
              expect(result).to be_present
            else
              expect(result).to be_nil
            end
          end
        end

        context 'when context type is unknown' do
          it 'returns nil' do
            allow(tracked_ref).to receive_messages(
              context_type: 'unknown',
              context_name: 'ref'
            )

            allow(project).to receive_message_chain(:repository, :commit)
              .with(nil).and_return(nil)

            expect(type_instance.commit).to be_nil
          end
        end
      end

      context 'when repository errors occur' do
        before do
          allow(type_instance).to receive(:ref_exists_in_repository?).and_return(true)
          allow(tracked_ref).to receive_messages(
            context_type: 'branch',
            context_name: 'main'
          )
        end

        where(:error_type) do
          [Gitlab::Git::Repository::NoRepository, Rugged::ReferenceError]
        end

        with_them do
          it "handles #{params[:error_type]} gracefully" do
            qualified_ref = "#{Gitlab::Git::BRANCH_REF_PREFIX}main"
            allow(project).to receive_message_chain(:repository, :commit)
              .with(qualified_ref).and_raise(error_type)

            expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
              an_instance_of(error_type),
              hash_including(project_id: project.id, ref_name: 'main')
            )

            expect(type_instance.commit).to be_nil
          end
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
