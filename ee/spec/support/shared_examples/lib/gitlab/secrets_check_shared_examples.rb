# frozen_string_literal: true

RSpec.shared_examples 'skips the push check' do
  include_context 'secrets check context'

  it "does not call format_response on the next instance" do
    # Instead of expecting `validate!` to return nil to be sure the check was skipped,
    # we check the next instance of the class will not receive `format_response` method.
    expect_next_instance_of(described_class) do |instance|
      expect(instance).not_to receive(:format_response)
    end

    secrets_check.validate!
  end
end

RSpec.shared_examples 'scan passed' do
  include_context 'secrets check context'

  let(:passed_scan_response) { ::Gitlab::SecretDetection::Response.new(Gitlab::SecretDetection::Status::NOT_FOUND) }
  let(:new_blob_reference) do
    'da66bef46dbf0ad7fdcbeec97c9eaa24c2846dda'
  end

  let(:diff_blob_no_secrets) do
    have_attributes(
      class: Gitlab::GitalyClient::DiffBlob,
      left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: new_blob_reference,
      patch: "@@ -0,0 +1 @@\n+BASE_URL=https://foo.bar\n\\ No newline at end of file\n",
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  let(:diff_blob_no_secrets_response) do
    [
      Gitaly::DiffBlobsResponse.new(
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: "@@ -0,0 +1 @@\n+BASE_URL=https://foo.bar\n\\ No newline at end of file\n",
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    ]
  end

  context 'when there is no secret in the commit' do
    before do
      allow(repository).to receive(:new_commits).and_return(commits)
    end

    it 'returns passed scan response' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob_no_secrets],
            timeout: kind_of(Float)
          )
          .once
          .and_return(passed_scan_response)
          .and_call_original
      end

      expect_next_instance_of(described_class) do |instance|
        expect(instance).to receive(:get_diffs)
          .once
          .and_return(diff_blob_no_secrets_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:secrets_not_found])

      expect { subject.validate! }.not_to raise_error
    end
  end

  context 'when there is an existing secret in the file but not in the commit diffs' do
    let_it_be(:commit_with_secret) { create_commit('.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow
    let_it_be(:blob_reference_with_secret) { 'fe29d93da4843da433e62711ace82db601eb4f8f' }

    let(:tree_entries) do
      [
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: '.env',
          flat_path: '.env',
          commit_id: new_commit
        )
      ]
    end

    before do
      allow(repository).to receive(:new_commits).and_return(commits)
    end

    it 'returns passed scan response' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_no_secrets_response)
        .and_call_original
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob_no_secrets],
            timeout: kind_of(Float)
          )
          .once
          .and_return(passed_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:secrets_not_found])

      expect { subject.validate! }.not_to raise_error
    end
  end
end

RSpec.shared_examples 'scan detected secrets' do
  include_context 'secrets check context'

  let_it_be(:new_commit) { create_commit('.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow
  let_it_be(:new_blob_reference) { 'fe29d93da4843da433e62711ace82db601eb4f8f' }

  let(:diff_blob) do
    have_attributes(
      class: Gitlab::GitalyClient::DiffBlob,
      left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: new_blob_reference,
      patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n",
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  let(:diff_blob_response) do
    [
      Gitaly::DiffBlobsResponse.new(
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    ]
  end

  let(:successful_scan_response) do
    ::Gitlab::SecretDetection::Response.new(
      Gitlab::SecretDetection::Status::FOUND,
      [
        Gitlab::SecretDetection::Finding.new(
          new_blob_reference,
          Gitlab::SecretDetection::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab Personal Access Token"
        )
      ]
    )
  end

  context 'when there is a secret in the commit' do
    it 'scans diffs' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_response)
        .and_call_original
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_path,
          finding_message_occurrence_line,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  it 'loads tree entries of the new commit' do
    expect_next_instance_of(described_class) do |secrets_push_check|
      expect(secrets_push_check).to receive(:get_diffs)
      .once
      .and_return(diff_blob_response)
      .and_call_original
    end

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .once
      .with(**expected_tree_args)
      .and_return([tree_entries, gitaly_pagination_cursor])
      .and_call_original

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  context 'when no tree entries exist or cannot be loaded' do
    it 'gracefully raises an error with existing information' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_response)
        .and_call_original
      end

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .once
        .with(**expected_tree_args)
        .and_return([{}, gitaly_pagination_cursor])

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_with_blob,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when tree has too many entries' do
    let(:gitaly_pagination_cursor) { Gitaly::PaginationCursor.new(next_cursor: "abcdef") }

    it 'logs an error and continue to raise and present findings' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_response)
        .and_call_original
      end

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .once
        .with(**expected_tree_args)
        .and_return([tree_entries, gitaly_pagination_cursor])

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect(secret_detection_logger).to receive(:error)
        .once
        .with(message: too_many_tree_entries_error)

      expect { subject.validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end

  context 'when new commit has file in subdirectory' do
    let_it_be(:new_commit) { create_commit('config/.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow

    let(:finding_path) { 'config/.env' }
    let(:tree_entries) do
      [
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: finding_path,
          flat_path: finding_path,
          commit_id: new_commit
        )
      ]
    end

    it 'loads tree entries of the new commit in subdirectories' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_response)
        .and_call_original
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_scan_response)
          .and_call_original
      end

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .once
        .with(**expected_tree_args)
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_path,
          finding_message_occurrence_line,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when there are multiple secrets in a commit' do
    let_it_be(:secret1) { 'SECRET=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow
    let_it_be(:secret2) { 'TOKEN=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow

    let_it_be(:new_commit) do
      create_commit('.env' => "#{secret1}\n#{secret2}")
    end

    let(:new_blob_reference) { '59ef300b246861163ee1e2ab4146e16144e4770f' }

    let(:diff_blob_multiple_secrets_in_commit) do
      have_attributes(
        class: Gitlab::GitalyClient::DiffBlob,
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: "@@ -0,0 +1,2 @@\n+#{secret1}\n+#{secret2}\n\\ No newline at end of file\n",
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:diff_blob_multiple_secrets_in_commit_response) do
      [
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: new_blob_reference,
          patch: "@@ -0,0 +1,2 @@\n+#{secret1}\n+#{secret2}\n\\ No newline at end of file\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      ]
    end

    let(:successful_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            2,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          )
        ]
      )
    end

    context 'when there is a secret in the commit' do
      it 'scans diffs' do
        expect_next_instance_of(described_class) do |secrets_push_check|
          expect(secrets_push_check).to receive(:get_diffs)
          .once
          .and_return(diff_blob_multiple_secrets_in_commit_response)
          .and_call_original
        end

        expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
          expect(instance).to receive(:secrets_scan)
            .with(
              [diff_blob_multiple_secrets_in_commit],
              timeout: kind_of(Float)
            )
            .once
            .and_return(successful_scan_response)
            .and_call_original
        end

        expect(secret_detection_logger).to receive(:info)
          .once
          .with(message: log_messages[:found_secrets])

        expect { subject.validate! }.to raise_error do |error|
          expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
          expect(error.message).to include(
            log_messages[:found_secrets],
            finding_message_header,
            finding_message_path,
            finding_message_multiple_occurrence_lines,
            log_messages[:found_secrets_post_message],
            found_secrets_docs_link
          )
        end
      end
    end
  end

  context 'when a blob is present in multiple commits' do
    let_it_be(:another_new_commit) do
      create_commit(
        { '.env' => "SECRET=glpat-JUST20LETTERSANDNUMB" }, # gitleaks:allow
        'Same commit different message'
      )
    end

    let(:diff_blob_same_in_multiple_commits) do
      have_attributes(
        class: Gitlab::GitalyClient::DiffBlob,
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:diff_blob_same_in_multiple_commits_response) do
      [
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: new_blob_reference,
          patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      ]
    end

    let(:tree_entries) do
      [
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: '.env',
          flat_path: '.env',
          commit_id: new_commit
        ),
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: '.env',
          flat_path: '.env',
          commit_id: another_new_commit
        )
      ]
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: another_new_commit, ref: 'refs/heads/master' }
      ]
    end

    let(:commits) do
      [
        Gitlab::Git::Commit.find(repository, new_commit),
        Gitlab::Git::Commit.find(repository, another_new_commit)
      ]
    end

    let(:successful_with_same_blob_in_multiple_commits_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          )
        ]
      )
    end

    before do
      allow(repository).to receive(:new_commits)
        .with([another_new_commit])
        .and_return(commits)
    end

    it 'displays the findings with their corresponding commit sha/file path' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_same_in_multiple_commits_response)
        .and_call_original
      end

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .with(**expected_tree_args.merge(sha: new_commit))
        .once
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .with(**expected_tree_args.merge(sha: another_new_commit))
        .once
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob_same_in_multiple_commits, diff_blob_same_in_multiple_commits],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_same_blob_in_multiple_commits_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_same_blob_in_multiple_commits_header_path_and_lines,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when a blob has multiple secrets on the same line' do
    let_it_be(:secret1) { 'SECRET=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow
    let_it_be(:secret2) { 'TOKEN=GR1348941JUST20LETTERSANDNUMB' } # gitleaks:allow

    let_it_be(:new_commit) do
      create_commit('.env' => "#{secret1};#{secret2}")
    end

    let(:new_blob_reference) { '13a31e7c93bbe8781f341e24e8ef26ef717d0da2' }

    let(:second_finding_description) { 'GitLab Runner Registration Token' }

    let(:diff_blob_secrets_same_line) do
      have_attributes(
        class: Gitlab::GitalyClient::DiffBlob,
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: "@@ -0,0 +1 @@\n+#{secret1};#{secret2}\n\\ No newline at end of file\n",
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:diff_blob_secrets_same_line_response) do
      [
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: new_blob_reference,
          patch: "@@ -0,0 +1 @@\n+#{secret1};#{secret2}\n\\ No newline at end of file\n",
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      ]
    end

    let(:successful_with_multiple_findings_on_same_line_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_runner_registration_token",
            "GitLab Runner Registration Token"
          )
        ]
      )
    end

    it 'displays the findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blob_secrets_same_line_response)
        .and_call_original
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob_secrets_same_line],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_multiple_findings_on_same_line_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_multiple_findings_on_same_line,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when multiple commits contain secrets' do
    let_it_be(:another_new_commit) { create_commit('test.txt' => 'TOKEN=glrt-12312312312312312312') } # gitleaks:allow

    let(:another_blob_reference) { 'e10edae379797ad5649a65ad364f6c940ee5bbc3' }

    let(:commits) do
      [
        Gitlab::Git::Commit.find(repository, new_commit),
        Gitlab::Git::Commit.find(repository, another_new_commit)
      ]
    end

    let(:another_diff_blob) do
      have_attributes(
        class: Gitlab::GitalyClient::DiffBlob,
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: another_blob_reference,
        patch: "@@ -0,0 +1 @@\n+TOKEN=glrt-12312312312312312312\n\\ No newline at end of file\n", # gitleaks:allow
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:diff_blob_multiple_commits_response) do
      [
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: new_blob_reference,
          patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        ),
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: another_blob_reference,
          patch: "@@ -0,0 +1 @@\n+TOKEN=glrt-12312312312312312312\n\\ No newline at end of file\n", # gitleaks:allow
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      ]
    end

    let(:successful_with_multiple_commits_contain_secrets_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            another_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_runner_auth_token",
            "GitLab Runner Authentication Token"
          )
        ]
      )
    end

    let(:tree_entries) do
      [
        Gitlab::Git::Tree.new(
          id: new_blob_reference,
          type: :blob,
          mode: '100644',
          name: '.env',
          path: '.env',
          flat_path: '.env',
          commit_id: new_commit
        ),
        Gitlab::Git::Tree.new(
          id: another_blob_reference,
          type: :blob,
          mode: '100644',
          name: 'test.txt',
          path: 'test.txt',
          flat_path: 'test.txt',
          commit_id: another_new_commit
        )
      ]
    end

    before do
      allow(repository).to receive(:new_commits).and_return(commits)
    end

    it 'successful scans findings in multiple commits' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
          .once
          .and_return(diff_blob_multiple_commits_response)
          .and_call_original
      end

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .with(**expected_tree_args.merge(sha: new_commit))
        .once
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect(::Gitlab::Git::Tree).to receive(:tree_entries)
        .with(**expected_tree_args.merge(sha: another_new_commit))
        .once
        .and_return([tree_entries, gitaly_pagination_cursor])
        .and_call_original

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob, another_diff_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_multiple_commits_contain_secrets_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_path,
          finding_message_multiple_findings_multiple_commits_occurrence_lines,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  context 'when multiple diffs contain secrets in a commit' do
    let_it_be(:new_commit) do
      create_commit('.env' => "SECRET=glpat-JUST20LETTERSANDNUMB", # gitleaks:allow
        'test.txt' => "SECRET=glrt-JUST20LETTERSANDNUMB") # gitleaks:allow
    end

    let(:another_new_blob_reference) { '5f571267577ed6e0b4b24fb87f7a8218d5912eb9' }

    let(:another_diff_blob) do
      have_attributes(
        class: Gitlab::GitalyClient::DiffBlob,
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: another_new_blob_reference,
        patch: "@@ -0,0 +1 @@\n+SECRET=glrt-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:diff_blobs_multiple_blobs_with_secrets_response) do
      [
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: new_blob_reference,
          patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        ),
        Gitaly::DiffBlobsResponse.new(
          left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
          right_blob_id: another_new_blob_reference,
          patch: "@@ -0,0 +1 @@\n+SECRET=glrt-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
          status: :STATUS_END_OF_PATCH,
          binary: false,
          over_patch_bytes_limit: false
        )
      ]
    end

    let(:successful_with_multiple_files_findings_scan_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            another_new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_runner_authentication_token",
            "GitLab Runner Authentication Token"
          )
        ]
      )
    end

    it 'displays the findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(described_class) do |secrets_push_check|
        expect(secrets_push_check).to receive(:get_diffs)
        .once
        .and_return(diff_blobs_multiple_blobs_with_secrets_response)
        .and_call_original
      end

      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            [diff_blob, another_diff_blob],
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_with_multiple_files_findings_scan_response)
          .and_call_original
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets],
          finding_message_header,
          finding_message_path,
          finding_message_multiple_files_occurrence_lines,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end

  it_behaves_like 'internal event tracking' do
    let(:event) { "detect_secret_type_on_push" }
    let(:namespace) { project.namespace }
    let(:label) { "GitLab Personal Access Token" }
    let(:category) { described_class.name }

    before do
      allow(secret_detection_logger).to receive(:info)
    end

    subject do
      expect { super().validate! }.to raise_error(::Gitlab::GitAccess::ForbiddenError)
    end
  end
end

RSpec.shared_examples 'scan detected secrets but some errors occured' do
  include_context 'secrets check context'

  let(:successful_scan_with_errors_response) do
    ::Gitlab::SecretDetection::Response.new(
      Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS,
      [
        Gitlab::SecretDetection::Finding.new(
          new_blob_reference,
          Gitlab::SecretDetection::Status::FOUND,
          1,
          "gitlab_personal_access_token",
          "GitLab Personal Access Token"
        ),
        Gitlab::SecretDetection::Finding.new(
          timed_out_blob_reference,
          Gitlab::SecretDetection::Status::DIFF_TIMEOUT
        ),
        Gitlab::SecretDetection::Finding.new(
          failed_to_scan_blob_reference,
          Gitlab::SecretDetection::Status::SCAN_ERROR
        )
      ]
    )
  end

  let_it_be(:new_commit) { create_commit('.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow
  let_it_be(:timed_out_commit) { create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow
  let_it_be(:failed_to_scan_commit) { create_commit('.dev.env' => 'GLPAT=glpat-JUST20LETTERSANDNUMB') } # gitleaks:allow

  let(:changes) do
    [
      { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
      { oldrev: initial_commit, newrev: timed_out_commit, ref: 'refs/heads/master' },
      { oldrev: initial_commit, newrev: failed_to_scan_commit, ref: 'refs/heads/master' }
    ]
  end

  let(:timed_out_blob_reference) { 'eaf3c09526f50b5e35a096ef70cca033f9974653' }
  let(:failed_to_scan_blob_reference) { '4fbec77313fd240d00fc37e522d0274b8fb54bd1' }

  let(:diff_blob) do
    have_attributes(
      class: Gitlab::GitalyClient::DiffBlob,
      left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: new_blob_reference,
      patch: "@@ -0,0 +1 @@\n+SECRET=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  let(:timed_out_diff_blob) do
    have_attributes(
      class: Gitlab::GitalyClient::DiffBlob,
      left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: timed_out_blob_reference,
      patch: "@@ -0,0 +1 @@\n+TOKEN=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  let(:failed_to_scan_diff_blob) do
    have_attributes(
      class: Gitlab::GitalyClient::DiffBlob,
      left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
      right_blob_id: failed_to_scan_blob_reference,
      patch: "@@ -0,0 +1 @@\n+GLPAT=glpat-JUST20LETTERSANDNUMB\n\\ No newline at end of file\n", # gitleaks:allow
      status: :STATUS_END_OF_PATCH,
      binary: false,
      over_patch_bytes_limit: false
    )
  end

  it 'scans diffs' do
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          array_including(diff_blob, timed_out_diff_blob, failed_to_scan_diff_blob),
          timeout: kind_of(Float)
        )
        .once
        .and_return(successful_scan_with_errors_response)
    end

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets_with_errors])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets_with_errors],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        blob_timed_out_error,
        failed_to_scan_regex_error,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  it 'loads tree entries of the new commit' do
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .with(
          array_including(diff_blob, timed_out_diff_blob, failed_to_scan_diff_blob),
          timeout: kind_of(Float)
        )
        .once
        .and_return(successful_scan_with_errors_response)
    end

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .with(**expected_tree_args.merge(sha: new_commit))
      .once
      .and_return([tree_entries, gitaly_pagination_cursor])
      .and_call_original

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .with(**expected_tree_args.merge(sha: timed_out_commit))
      .once
      .and_return([[], nil])
      .and_call_original

    expect(::Gitlab::Git::Tree).to receive(:tree_entries)
      .with(**expected_tree_args.merge(sha: failed_to_scan_commit))
      .once
      .and_return([[], nil])
      .and_call_original

    expect(secret_detection_logger).to receive(:info)
      .once
      .with(message: log_messages[:found_secrets_with_errors])

    expect { subject.validate! }.to raise_error do |error|
      expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
      expect(error.message).to include(
        log_messages[:found_secrets_with_errors],
        finding_message_header,
        finding_message_path,
        finding_message_occurrence_line,
        blob_timed_out_error,
        failed_to_scan_regex_error,
        log_messages[:found_secrets_post_message],
        found_secrets_docs_link
      )
    end
  end

  context 'when a blob has multiple secrets' do
    let_it_be(:secret1) { 'SECRET=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow
    let_it_be(:secret2) { 'TOKEN=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow

    let_it_be(:new_commit) do
      create_commit('.env' => "#{secret1}\n#{secret2}")
    end

    let(:new_blob_reference) { '59ef300b246861163ee1e2ab4146e16144e4770f' }
    let(:diff_blob) do
      have_attributes(
        class: Gitlab::GitalyClient::DiffBlob,
        left_blob_id: Gitlab::Git::SHA1_BLANK_SHA,
        right_blob_id: new_blob_reference,
        patch: "@@ -0,0 +1,2 @@\n+#{secret1}\n+#{secret2}\n\\ No newline at end of file\n",
        status: :STATUS_END_OF_PATCH,
        binary: false,
        over_patch_bytes_limit: false
      )
    end

    let(:successful_scan_with_multiple_findings_and_errors_response) do
      ::Gitlab::SecretDetection::Response.new(
        Gitlab::SecretDetection::Status::FOUND_WITH_ERRORS,
        [
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            1,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            new_blob_reference,
            Gitlab::SecretDetection::Status::FOUND,
            2,
            "gitlab_personal_access_token",
            "GitLab Personal Access Token"
          ),
          Gitlab::SecretDetection::Finding.new(
            timed_out_blob_reference,
            Gitlab::SecretDetection::Status::DIFF_TIMEOUT
          ),
          Gitlab::SecretDetection::Finding.new(
            failed_to_scan_blob_reference,
            Gitlab::SecretDetection::Status::SCAN_ERROR
          )
        ]
      )
    end

    it 'displays all findings with their corresponding commit sha/filepath' do
      expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
        expect(instance).to receive(:secrets_scan)
          .with(
            array_including(diff_blob, timed_out_diff_blob, failed_to_scan_diff_blob),
            timeout: kind_of(Float)
          )
          .once
          .and_return(successful_scan_with_multiple_findings_and_errors_response)
      end

      expect(secret_detection_logger).to receive(:info)
        .once
        .with(message: log_messages[:found_secrets_with_errors])

      expect { subject.validate! }.to raise_error do |error|
        expect(error).to be_a(::Gitlab::GitAccess::ForbiddenError)
        expect(error.message).to include(
          log_messages[:found_secrets_with_errors],
          finding_message_header,
          finding_message_multiple_occurrence_lines,
          blob_timed_out_error,
          failed_to_scan_regex_error,
          log_messages[:found_secrets_post_message],
          found_secrets_docs_link
        )
      end
    end
  end
end

RSpec.shared_examples 'scan timed out' do
  include_context 'secrets check context'

  let(:scan_timed_out_scan_response) do
    ::Gitlab::SecretDetection::Response.new(Gitlab::SecretDetection::Status::SCAN_TIMEOUT)
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan timed out status.
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(scan_timed_out_scan_response)
    end

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:scan_timeout_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan failed to initialize' do
  include_context 'secrets check context'

  before do
    # Intentionally set `RULESET_FILE_PATH` to an incorrect path to cause error.
    stub_const('::Gitlab::SecretDetection::Scan::RULESET_FILE_PATH', 'gitleaks.toml')
  end

  it 'logs the error and passes the check' do
    # File parsing error is written to the logger.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(
        "Failed to parse secret detection ruleset from 'gitleaks.toml' path: " \
        "No such file or directory @ rb_sysopen - gitleaks.toml"
      )

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:scan_initialization_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan failed with invalid input' do
  include_context 'secrets check context'

  let(:failed_with_invalid_input_response) do
    ::Gitlab::SecretDetection::Response.new(::Gitlab::SecretDetection::Status::INPUT_ERROR)
  end

  it 'logs the error and passes the check' do
    # Mock the response to return a scan invalid input status.
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(failed_with_invalid_input_response)
    end

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:invalid_input_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan skipped due to invalid status' do
  include_context 'secrets check context'

  let(:invalid_scan_status_code) { 7 } # doesn't exist in ::Gitlab::SecretDetection::Status
  let(:invalid_scan_status_code_response) { ::Gitlab::SecretDetection::Response.new(invalid_scan_status_code) }

  it 'logs the error and passes the check' do
    # Mock the response to return a scan invalid status.
    expect_next_instance_of(::Gitlab::SecretDetection::Scan) do |instance|
      expect(instance).to receive(:secrets_scan)
        .and_return(invalid_scan_status_code_response)
    end

    # Error bubbles up from scan class and is handled in secrets check.
    expect(secret_detection_logger).to receive(:error)
      .once
      .with(message: error_messages[:invalid_scan_status_code_error])

    expect { subject.validate! }.not_to raise_error
  end
end

RSpec.shared_examples 'scan skipped when a commit has special bypass flag' do
  include_context 'secrets check context'

  let_it_be(:new_commit) do
    create_commit(
      { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' }, # gitleaks:allow
      'skip scanning [skip secret push protection]'
    )
  end

  it 'skips the scanning process' do
    expect { subject.validate! }.not_to raise_error
  end

  context 'when other commits have secrets in the same push' do
    let_it_be(:second_commit_with_secret) do
      create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: second_commit_with_secret, ref: 'refs/heads/master' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  it 'creates an audit event' do
    expect { subject.validate! }.to change { AuditEvent.count }.by(1)
    expect(AuditEvent.last.details[:custom_message]).to eq("Secret push protection skipped via commit message")
  end

  it_behaves_like 'internal event tracking' do
    let(:event) { 'skip_secret_push_protection' }
    let(:namespace) { project.namespace }
    let(:label) { "commit message" }
    let(:category) { described_class.name }
    subject { super().validate! }
  end
end

RSpec.shared_examples 'scan skipped when secret_push_protection.skip_all push option is passed' do
  include_context 'secrets check context'

  let(:changes_access) do
    Gitlab::Checks::ChangesAccess.new(
      changes,
      project: project,
      user_access: user_access,
      protocol: protocol,
      logger: logger,
      push_options: Gitlab::PushOptions.new(["secret_push_protection.skip_all"])
    )
  end

  let_it_be(:new_commit) do
    create_commit(
      { '.env' => 'SECRET=glpat-JUST20LETTERSANDNUMB' } # gitleaks:allow
    )
  end

  it 'skips the scanning process' do
    expect { subject.validate! }.not_to raise_error
  end

  context 'when other commits have secrets in the same push' do
    let_it_be(:second_commit_with_secret) do
      create_commit('.test.env' => 'TOKEN=glpat-JUST20LETTERSANDNUMB') # gitleaks:allow
    end

    let(:changes) do
      [
        { oldrev: initial_commit, newrev: new_commit, ref: 'refs/heads/master' },
        { oldrev: initial_commit, newrev: second_commit_with_secret, ref: 'refs/heads/master' }
      ]
    end

    it 'skips the scanning process still' do
      expect { subject.validate! }.not_to raise_error
    end
  end

  it 'creates an audit event' do
    expect { subject.validate! }.to change { AuditEvent.count }.by(1)
    expect(AuditEvent.last.details[:custom_message]).to eq("Secret push protection skipped via push option")
  end

  it_behaves_like 'internal event tracking' do
    let(:event) { 'skip_secret_push_protection' }
    let(:namespace) { project.namespace }
    let(:label) { "push option" }
    let(:category) { described_class.name }
    subject { super().validate! }
  end
end
