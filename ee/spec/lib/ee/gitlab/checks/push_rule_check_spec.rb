# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::Checks::PushRuleCheck, feature_category: :source_code_management do
  include_context 'changes access checks context'

  let(:push_rule) { create(:push_rule, :commit_message) }
  let(:project) { create(:project, :public, :repository, push_rule: push_rule) }

  before do
    allow(project.repository).to receive(:new_commits).and_return(
      project.repository.commits_between('be93687618e4b132087f430a4d8fc3a609c9b77c', '54fcc214b94e78d7a41a9a8fe6d87a5e59500e51')
    )
  end

  shared_examples "push checks" do
    before do
      allow_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
        .to receive(:validate!).and_return(nil)
      allow_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
        .to receive(:validate!).and_return(nil)

      allow(project).to receive(:jira_integration).and_return(nil)

      allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
        .to receive(:validate!).and_return(nil)
    end

    it "returns nil on success" do
      expect(subject.validate!).to be_nil
    end

    context 'when tag name exists' do
      let(:changes) do
        [
          { oldrev: oldrev, newrev: newrev, ref: 'refs/tags/name' }
        ]
      end

      it 'validates tags push rules' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
          .to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
          .not_to receive(:validate!)

        subject.validate!
      end
    end

    context 'when branch name exists' do
      let(:changes) do
        [
          { oldrev: oldrev, newrev: newrev, ref: 'refs/heads/name' }
        ]
      end

      it 'validates branches push rules' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
          .not_to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
          .to receive(:validate!)

        subject.validate!
      end
    end

    context 'when changes are from notes ref' do
      let(:changes) do
        [{ oldrev: oldrev, newrev: newrev, ref: 'refs/notes/commits' }]
      end

      it 'does not validate push rules for tags or branches' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck).not_to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck).not_to receive(:validate!)

        subject.validate!
      end
    end

    context 'when tag and branch exist' do
      let(:changes) do
        [
          { oldrev: oldrev, newrev: newrev, ref: 'refs/heads/name' },
          { oldrev: oldrev, newrev: newrev, ref: 'refs/tags/name' }
        ]
      end

      it 'validates tag and branch push rules' do
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
          .to receive(:validate!)
        expect_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
          .to receive(:validate!)

        subject.validate!
      end
    end
  end

  describe '#validate!' do
    context "parallel push checks" do
      before do
        ::Gitlab::Git::HookEnv.set(project.repository.gl_repository,
          project.repository.raw_repository.relative_path,
          "GIT_OBJECT_DIRECTORY_RELATIVE" => "objects",
          "GIT_ALTERNATE_OBJECT_DIRECTORIES_RELATIVE" => [])
      end

      it_behaves_like "push checks"

      it "sets the git env correctly for all hooks", :request_store do
        allow(project).to receive(:jira_integration).and_return(nil)

        expect(Gitaly::Repository).to receive(:new)
                                        .at_least(:once)
                                        .with(a_hash_including(git_object_directory: "objects"))
                                        .and_call_original

        expect { subject.validate! }.to raise_error(Gitlab::GitAccess::ForbiddenError)
      end
    end

    context ":parallel_push_checks feature is disabled" do
      before do
        stub_feature_flags(parallel_push_checks: false)
      end

      it_behaves_like "push checks"
    end

    context 'when Jira verification is needed' do
      before do
        allow_any_instance_of(described_class)
          .to receive(:push_rule).and_return(nil)

        jira_integration = instance_double(Integrations::Jira, present?: true)
        allow(project).to receive(:jira_integration).and_return(jira_integration)
      end

      context 'with parallel push checks enabled' do
        before do
          stub_feature_flags(parallel_push_checks: true)

          ::Gitlab::Git::HookEnv.set(project.repository.gl_repository,
            project.repository.raw_repository.relative_path,
            "GIT_OBJECT_DIRECTORY_RELATIVE" => "objects",
            "GIT_ALTERNATE_OBJECT_DIRECTORIES_RELATIVE" => [])
        end

        it 'calls JiraVerificationCheck once with changes_access' do
          allow_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
            .to receive(:validate!).and_return(nil)
          allow_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
            .to receive(:validate!).and_return(nil)

          expect_next_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck, changes_access) do |instance|
            expect(instance).to receive(:validate!)
          end

          subject.validate!
        end

        it 'handles multiple changes correctly' do
          allow_any_instance_of(EE::Gitlab::Checks::PushRules::TagCheck)
            .to receive(:validate!).and_return(nil)
          allow_any_instance_of(EE::Gitlab::Checks::PushRules::BranchCheck)
            .to receive(:validate!).and_return(nil)

          expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:new).once.with(changes_access)
            .and_call_original

          allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:validate!)

          subject.validate!
        end

        context 'when JiraVerificationCheck raises an error' do
          it 'propagates the error' do
            allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
              .to receive(:validate!).and_raise(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")

            expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")
          end
        end

        context 'when only Jira verification is needed (no push rules)' do
          let_it_be(:project) { create(:project, :public, :repository, push_rule: nil) }

          before do
            jira_integration = instance_double(Integrations::Jira, present?: true)
            allow(project).to receive(:jira_integration).and_return(jira_integration)

            ::Gitlab::Git::HookEnv.set(project.repository.gl_repository,
              project.repository.raw_repository.relative_path,
              "GIT_OBJECT_DIRECTORY_RELATIVE" => "objects",
              "GIT_ALTERNATE_OBJECT_DIRECTORIES_RELATIVE" => [])
          end

          it 'executes check_jira_verification! in parallel thread' do
            check_jira_called = false

            allow_any_instance_of(described_class).to receive(:check_jira_verification!) do
              check_jira_called = true
            end

            subject.validate!

            expect(check_jira_called).to be(true)
          end

          it 'creates and manages threads correctly' do
            threads_created = []
            threads_joined = []
            threads_exited = []

            allow_any_instance_of(described_class).to receive(:parallelize).and_wrap_original do |method, *args, &block|
              original_result = method.call(*args, &block)

              instance = method.receiver
              current_threads = instance.instance_variable_get(:@threads) || []
              threads_created.concat(current_threads)

              original_result
            end

            allow_any_instance_of(Thread).to receive(:join) do |thread|
              threads_joined << thread
            end

            allow_any_instance_of(Thread).to receive(:exit) do |thread|
              threads_exited << thread
            end

            allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
              .to receive(:validate!)

            subject.validate!

            expect(threads_created).not_to be_empty
            expect(threads_joined).not_to be_empty
            expect(threads_exited).not_to be_empty
          end

          it 'handles errors in parallel Jira verification' do
            allow(subject).to receive(:check_tag_or_branch!).and_return(nil)

            allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
              .to receive(:validate!).and_raise(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")

            expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")
          end
        end
      end

      context 'with parallel push checks disabled' do
        before do
          stub_feature_flags(parallel_push_checks: false)
        end

        it 'calls JiraVerificationCheck once with changes_access' do
          expect_next_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck, changes_access) do |instance|
            expect(instance).to receive(:validate!)
          end

          subject.validate!
        end

        it 'creates JiraVerificationCheck instance with correct parameters' do
          expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:new).once.with(changes_access).and_call_original

          allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:validate!)

          subject.validate!
        end

        context 'when JiraVerificationCheck raises an error' do
          it 'stops execution and propagates the error' do
            allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
              .to receive(:validate!).and_raise(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")

            expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError, "Jira validation failed")
          end
        end
      end

      context 'with different types of changes' do
        let(:changes) do
          [
            { oldrev: oldrev, newrev: newrev, ref: 'refs/heads/feature-branch' },
            { oldrev: oldrev, newrev: newrev, ref: 'refs/tags/v1.0.0' },
            { newrev: newrev, ref: 'refs/heads/new-branch' },
            { oldrev: oldrev, ref: 'refs/heads/deleted-branch' }
          ]
        end

        before do
          stub_feature_flags(parallel_push_checks: false)
        end

        it 'processes all change types through Jira verification' do
          expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:new).once.with(changes_access).and_call_original

          allow_any_instance_of(::Gitlab::Checks::PushRules::JiraVerificationCheck)
            .to receive(:validate!)

          subject.validate!
        end
      end
    end
  end

  describe '#check_jira_verification!' do
    let(:jira_check) { instance_double(Gitlab::Checks::PushRules::JiraVerificationCheck) }

    it 'creates single JiraVerificationCheck with changes_access and calls validate!' do
      expect(::Gitlab::Checks::PushRules::JiraVerificationCheck)
        .to receive(:new).with(changes_access).and_return(jira_check)

      expect(jira_check).to receive(:validate!)

      subject.send(:check_jira_verification!)
    end

    context 'when validate! raises an exception' do
      before do
        allow(::Gitlab::Checks::PushRules::JiraVerificationCheck)
          .to receive(:new).with(changes_access).and_return(jira_check)
        allow(jira_check).to receive(:validate!)
          .and_raise(::Gitlab::GitAccess::ForbiddenError, "Jira issue not found")
      end

      it 'propagates the exception' do
        expect { subject.send(:check_jira_verification!) }
          .to raise_error(::Gitlab::GitAccess::ForbiddenError, "Jira issue not found")
      end
    end
  end
end
