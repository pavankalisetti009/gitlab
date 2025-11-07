# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Packages::Maven::Upstream, type: :model, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:other_project) { create(:project) }
  let_it_be(:other_project_global_id) { other_project.to_global_id.to_s }
  let_it_be(:other_group) { create(:group) }
  let_it_be(:other_group_global_id) { other_group.to_global_id.to_s }

  subject(:upstream) { build(:virtual_registries_packages_maven_upstream) }

  it_behaves_like 'it has loose foreign keys' do
    let(:factory_name) { :virtual_registries_packages_maven_upstream }
  end

  describe 'associations' do
    it 'has many cache entries' do
      is_expected.to have_many(:cache_entries)
        .class_name('VirtualRegistries::Packages::Maven::Cache::Entry')
        .inverse_of(:upstream)
    end

    it 'has many cache local entries' do
      is_expected.to have_many(:cache_local_entries)
        .class_name('VirtualRegistries::Packages::Maven::Cache::Local::Entry')
        .inverse_of(:upstream)
    end

    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::RegistryUpstream')
        .inverse_of(:upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Packages::Maven::Registry')
    end

    context 'with an upstream with remote cache entries' do
      let_it_be(:cache_entry) { create(:virtual_registries_packages_maven_cache_entry) }
      let_it_be(:upstream) { cache_entry.upstream }

      it 'has the remote cache entries' do
        expect(upstream.cache_entries).to contain_exactly(cache_entry)
      end

      it 'has no cache local entries' do
        expect(upstream.cache_local_entries).to eq([])
      end
    end

    context 'with an upstream with cache local entries' do
      let_it_be(:cache_entry) { create(:virtual_registries_packages_maven_cache_local_entry) }
      let_it_be(:upstream) { cache_entry.upstream }

      it 'has no remote cache entries' do
        expect(upstream.cache_entries).to eq([])
      end

      it 'has the cache local entries' do
        expect(upstream.cache_local_entries).to contain_exactly(cache_entry)
      end
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_length_of(:url).is_at_most(255) }
    it { is_expected.to validate_length_of(:username).is_at_most(510) }
    it { is_expected.to validate_length_of(:password).is_at_most(510) }
    it { is_expected.to validate_numericality_of(:cache_validity_hours).only_integer.is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:metadata_cache_validity_hours).only_integer.is_greater_than(0) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1024) }

    context 'for remote upstream' do
      it { is_expected.to validate_presence_of(:username) }
      it { is_expected.to validate_presence_of(:password) }

      context 'for url' do
        where(:url, :valid, :error_messages) do
          'http://test.maven'   | true  | nil
          'https://test.maven'  | true  | nil
          'git://test.maven'    | false | ['Url is blocked: Only allowed schemes are http, https']
          nil                   | false | ["Url can't be blank", 'Url must be a valid URL']
          ''                    | false | ["Url can't be blank", 'Url must be a valid URL']
          "http://#{'a' * 255}" | false | 'Url is too long (maximum is 255 characters)'
          'http://127.0.0.1'    | false | 'Url is blocked: Requests to localhost are not allowed'
          'maven.local'         | false | 'Url is blocked: Only allowed schemes are http, https'
          'http://192.168.1.2'  | false | 'Url is blocked: Requests to the local network are not allowed'
          'http://foobar.x'     | false | 'Url is blocked: Host cannot be resolved or invalid'
        end

        with_them do
          before do
            upstream.url = url
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_messages))) }
          end
        end

        context 'for normalization' do
          where(:url_to_set, :expected_url) do
            'http://test.maven'       | 'http://test.maven'
            'http://test.maven/'      | 'http://test.maven'
            'http://test.maven//'     | 'http://test.maven'
            'http://test.maven/path'  | 'http://test.maven/path'
            'http://test.maven/path/' | 'http://test.maven/path'
          end

          with_them do
            before do
              upstream.url = url_to_set
            end

            it { is_expected.to be_valid.and have_attributes(url: expected_url) }
          end

          context 'when creating upstreams with same URL but different trailing slashes' do
            let_it_be(:group) { create(:group) }

            it 'prevents duplicate upstreams with trailing slash' do
              create(:virtual_registries_packages_maven_upstream, url: 'http://test.maven', group: group)

              duplicate = build(:virtual_registries_packages_maven_upstream, url: 'http://test.maven/', group: group)

              expect(duplicate).to be_invalid.and have_attributes(
                errors: match_array(Array.wrap(
                  'Group already has a remote upstream with the same url and credentials'
                )),
                url: 'http://test.maven'
              )
            end
          end
        end
      end

      context 'for credentials' do
        where(:username, :password, :valid, :error_message) do
          'user'      | 'password'   | true  | nil
          ''          | ''           | true  | nil
          ''          | nil          | true  | nil
          nil         | ''           | true  | nil
          nil         | 'password'   | false | "Username can't be blank"
          'user'      | nil          | false | "Password can't be blank"
          ''          | 'password'   | false | "Username can't be blank"
          'user'      | ''           | false | "Password can't be blank"
          ('a' * 511) | 'password'   | false | 'Username is too long (maximum is 510 characters)'
          'user'      | ('a' * 511)  | false | 'Password is too long (maximum is 510 characters)'
        end

        with_them do
          before do
            upstream.assign_attributes(username:, password:)
          end

          if params[:valid]
            it { is_expected.to be_valid }
          else
            it { is_expected.to be_invalid.and have_attributes(errors: match_array(Array.wrap(error_message))) }
          end
        end

        context 'when url is updated' do
          where(:new_url, :new_user, :new_pwd, :expected_user, :expected_pwd) do
            'http://original_url.test' | 'test' | 'test' | 'test' | 'test'
            'http://update_url.test'   | 'test' | 'test' | 'test' | 'test'
            'http://update_url.test'   | :none  | :none  | nil    | nil
            'http://update_url.test'   | 'test' | :none  | nil    | nil
            'http://update_url.test'   | :none  | 'test' | nil    | nil
          end

          with_them do
            before do
              upstream.update!(url: 'http://original_url.test', username: 'original_user', password: 'original_pwd')
            end

            it 'resets the username and the password when necessary' do
              new_attributes = { url: new_url, username: new_user, password: new_pwd }.select { |_, v| v != :none }
              upstream.update!(new_attributes)

              expect(upstream.reload).to have_attributes(
                url: new_url,
                username: expected_user,
                password: expected_pwd
              )
            end
          end
        end
      end
    end

    context 'for local upstreams' do
      context 'for local project upstream' do
        subject(:upstream) do
          build(:virtual_registries_packages_maven_upstream, :without_credentials, url: other_project_global_id)
        end

        it { is_expected.to validate_absence_of(:username) }
        it { is_expected.to validate_absence_of(:password) }
      end

      context 'for local group upstream' do
        subject(:upstream) do
          build(:virtual_registries_packages_maven_upstream, :without_credentials, url: other_group_global_id)
        end

        it { is_expected.to validate_absence_of(:username) }
        it { is_expected.to validate_absence_of(:password) }
      end

      describe '#ensure_local_project_or_local_group' do
        let_it_be(:user_global_id) { create(:user).to_global_id.to_s }

        let(:invalid_project_global_id) { Project.new(id: non_existing_record_id).to_global_id.to_s }
        let(:invalid_group_global_id) { Group.new(id: non_existing_record_id).to_global_id.to_s }

        where(:url, :expected_error_messages) do
          ref(:other_project_global_id)   | []
          ref(:other_group_global_id)     | []
          ref(:invalid_project_global_id) | ['Url should point to an existing Project']
          ref(:invalid_group_global_id)   | ['Url should point to an existing Group']
          nil                             | ["Url can't be blank", 'Url must be a valid URL']
          'test'                          | ['Url is blocked: Only allowed schemes are http, https']
          ref(:user_global_id)            | ['Url should point to a Project or Group']
        end

        with_them do
          subject(:upstream) { build(:virtual_registries_packages_maven_upstream, :without_credentials, url:) }

          if params[:expected_error_messages].any?
            it { is_expected.to be_invalid.and have_attributes(errors: match_array(expected_error_messages)) }
          else
            it { is_expected.to be_valid }
          end
        end
      end
    end

    describe '#credentials_uniqueness_for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:existing_upstream) do
        create(
          :virtual_registries_packages_maven_upstream,
          group: group,
          url: 'https://example.com',
          username: 'user',
          password: 'pass'
        )
      end

      let_it_be(:local_project_url) do
        other_project_global_id.to_s.tap do |url|
          create(:virtual_registries_packages_maven_upstream, :without_credentials, group:, url:)
        end
      end

      let_it_be(:local_group_url) do
        other_group_global_id.tap do |url|
          create(:virtual_registries_packages_maven_upstream, :without_credentials, group:, url:)
        end
      end

      where(:test_group, :url, :username, :password, :valid, :description) do
        ref(:group)  | 'https://example.com'   | 'user'      | 'pass'      | false | 'same group, same credentials'
        ref(:group)  | 'https://example.com'   | 'user'      | 'different' | true  | 'same group, different password'
        ref(:group)  | 'https://example.com'   | 'different' | 'pass'      | true  | 'same group, different username'
        ref(:group)  | 'https://different.com' | 'user'      | 'pass'      | true  | 'same group, different URL'
        ref(:group2) | 'https://example.com'   | 'user'      | 'pass'      | true  | 'different group, same credentials'

        ref(:group)  | ref(:local_project_url)  | nil | nil | false | 'same local project'
        ref(:group)  | ref(:local_group_url)    | nil | nil | false | 'same local group'
      end

      with_them do
        context 'when creating new upstream' do
          subject(:new_upstream) do
            build(
              :virtual_registries_packages_maven_upstream,
              group: test_group,
              url: url,
              username: username,
              password: password
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              error = if new_upstream.remote?
                        described_class::SAME_URL_AND_CREDENTIALS_ERROR
                      else
                        described_class::SAME_LOCAL_PROJECT_OR_GROUP_ERROR
                      end

              is_expected.to be_invalid.and have_attributes(errors: match_array(["Group #{error}"]))
            end
          end
        end

        context 'when updating existing upstream' do
          let_it_be(:updated_upstream) do
            create(
              :virtual_registries_packages_maven_upstream,
              group: group,
              url: 'https://example2.com',
              username: 'user',
              password: 'pass'
            )
          end

          subject { updated_upstream }

          before do
            updated_upstream.assign_attributes(
              group: test_group,
              url: url,
              username: username,
              password: password
            )
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when updating to #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              expected_message = if updated_upstream.remote?
                                   'Group already has a remote upstream with the same url and credentials'
                                 else
                                   'Group already has a local upstream with the same target project or group'
                                 end

              is_expected.to be_invalid
                .and have_attributes(errors: match_array([expected_message]))
            end
          end
        end
      end
    end
  end

  describe 'callbacks' do
    context 'for set_cache_validity_hours_for_maven_central' do
      %w[
        https://repo1.maven.org/maven2
        https://repo1.maven.org/maven2/
      ].each do |maven_central_url|
        context "with url set to #{maven_central_url}" do
          before do
            upstream.url = maven_central_url
          end

          it 'sets the cache validity hours to 0' do
            upstream.save!

            expect(upstream.cache_validity_hours).to eq(0)
          end
        end
      end

      context 'with url other than maven central' do
        before do
          upstream.url = 'https://test.org/maven2'
        end

        it 'sets the cache validity hours to the database default value' do
          upstream.save!

          expect(upstream.cache_validity_hours).not_to eq(0)
        end
      end

      context 'with no url' do
        before do
          upstream.url = nil
        end

        it 'does not set the cache validity hours' do
          expect(upstream).not_to receive(:set_cache_validity_hours_for_maven_central)

          expect { upstream.save! }.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end
  end

  describe 'scopes' do
    describe '.eager_load_registry_upstream' do
      let_it_be(:registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams, upstreams_count: 2) }
      let_it_be(:other_registry) { create(:virtual_registries_packages_maven_registry, :with_upstreams) }

      subject(:upstreams) { described_class.eager_load_registry_upstream(registry:) }

      it { is_expected.to eq(registry.upstreams) }

      it { is_expected.not_to include(other_registry.upstreams) }

      it 'eager loads the registry_upstream association' do
        recorder = ActiveRecord::QueryRecorder.new { upstreams.each(&:registry_upstreams) }

        expect(recorder.count).to eq(1)
      end

      it 'eager loads the registries association' do
        recorder = ActiveRecord::QueryRecorder.new { upstreams.each(&:registries) }

        expect(recorder.count).to eq(1)
      end
    end

    describe '.for_id_and_group' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

      before do
        create(:virtual_registries_packages_maven_upstream)
      end

      subject { described_class.for_id_and_group(id: upstream.id, group: upstream.group) }

      it { is_expected.to contain_exactly(upstream) }
    end

    describe '.for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, group:) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }

      subject { described_class.for_group(group) }

      it { is_expected.to eq([upstream]) }
    end

    describe '.for_url' do
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, url: 'https://gitlab.com/maven/test') }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }

      subject { described_class.for_url('https://gitlab.com/maven/test') }

      it { is_expected.to eq([upstream]) }
    end

    describe '.search_by_name' do
      let(:query) { 'abc' }
      let_it_be(:name) { 'pkg-name-abc' }
      let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream, name: name) }
      let_it_be(:other_upstream) { create(:virtual_registries_packages_maven_upstream) }

      subject { described_class.search_by_name(query) }

      it { is_expected.to eq([upstream]) }
    end
  end

  describe 'encryption' do
    subject(:saved_upstream) { upstream.tap(&:save!) }

    it { is_expected.to be_encrypted_attribute(:username).and be_encrypted_attribute(:password) }
  end

  describe '#url_for' do
    subject { upstream.url_for(path) }

    where(:path, :expected_url) do
      'path'      | 'http://test.maven/path'
      ''          | 'http://test.maven/'
      '/path'     | 'http://test.maven/path'
      '/sub/path' | 'http://test.maven/sub/path'
    end

    with_them do
      before do
        upstream.url = 'http://test.maven/'
      end

      it { is_expected.to eq(expected_url) }

      context 'for local upstream' do
        before do
          upstream.url = other_project_global_id
        end

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#headers' do
    subject { upstream.headers }

    where(:username, :password, :expected_headers) do
      'user' | 'pass' | { Authorization: 'Basic dXNlcjpwYXNz' }
      'user' | ''     | {}
      ''     | 'pass' | {}
      ''     | ''     | {}
    end

    with_them do
      before do
        upstream.username = username
        upstream.password = password
      end

      it { is_expected.to eq(expected_headers) }
    end
  end

  describe '#as_json' do
    subject { upstream.as_json }

    it { is_expected.not_to include('password') }
  end

  describe '#default_cache_entries' do
    let_it_be(:upstream) { create(:virtual_registries_packages_maven_upstream) }

    let_it_be(:default_cache_entry) do
      create(:virtual_registries_packages_maven_cache_entry, upstream: upstream)
    end

    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_packages_maven_cache_entry, :pending_destruction, upstream: upstream)
    end

    subject { upstream.default_cache_entries }

    it { is_expected.to contain_exactly(default_cache_entry) }
  end

  describe '#object_storage_key' do
    let_it_be(:upstream) { build_stubbed(:virtual_registries_packages_maven_upstream) }

    subject { upstream.object_storage_key }

    it 'contains the expected terms' do
      is_expected.to include(
        "virtual_registries/packages/maven/#{upstream.group_id}/upstream/#{upstream.id}/cache/entry"
      )
    end

    it 'does not return the same value when called twice' do
      first_value = upstream.object_storage_key
      second_value = upstream.object_storage_key

      expect(first_value).not_to eq(second_value)
    end

    context 'for local upstream' do
      before do
        upstream.url = other_project_global_id
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#purge_cache!' do
    it 'enqueues the MarkEntriesForDestructionWorker' do
      expect(::VirtualRegistries::Packages::Cache::MarkEntriesForDestructionWorker)
        .to receive(:perform_async).with(upstream.id)

      upstream.purge_cache!
    end
  end

  describe '#test' do
    let(:test_url) { upstream.url_for('com/company/app/maven-metadata.xml') }
    let(:response) { ActiveSupport::OrderedOptions.new }
    let(:code) { 200 }
    let(:message) { 'OK' }

    subject(:test) { upstream.test }

    before do
      allow(Gitlab::HTTP).to receive(:head) do
        response.code = code
        response.message = message
        response
      end
    end

    it 'makes a HEAD request to the test endpoint' do
      test

      expect(Gitlab::HTTP).to have_received(:head).with(
        test_url,
        headers: upstream.headers,
        follow_redirects: true
      )
    end

    context 'with different HTTP response codes' do
      where(:code, :message, :expected_result) do
        200 | 'OK'                    | { success: true }
        201 | 'Created'               | { success: true }
        299 | 'Misc Success'          | { success: true }
        404 | 'Not Found'             | { success: true }
        400 | 'Bad Request'           | { success: false, result: 'Error: 400 - Bad Request' }
        401 | 'Unauthorized'          | { success: false, result: 'Error: 401 - Unauthorized' }
        403 | 'Forbidden'             | { success: false, result: 'Error: 403 - Forbidden' }
        500 | 'Internal Server Error' | { success: false, result: 'Error: 500 - Internal Server Error' }
      end

      with_them do
        it { is_expected.to eq(expected_result) }
      end
    end

    context 'when HTTP errors occur' do
      where(:error_class, :error_message) do
        Net::OpenTimeout | 'Connection timeout'
        SocketError      | 'getaddrinfo: Name or service not known'
      end

      before do
        allow(Gitlab::HTTP).to receive(:head).and_raise(error_class, error_message)
      end

      with_them do
        it { is_expected.to eq({ success: false, result: "Error: #{error_message}" }) }
      end
    end

    context 'with credentials' do
      where(:username, :password, :expected_headers) do
        'testuser' | 'testpass' | { Authorization: 'Basic dGVzdHVzZXI6dGVzdHBhc3M=' }
        nil        | nil        | {}
      end

      before do
        upstream.assign_attributes(username:, password:)
      end

      with_them do
        it 'uses the appropriate headers' do
          test

          expect(Gitlab::HTTP).to have_received(:head).with(
            test_url,
            headers: expected_headers,
            follow_redirects: true
          )
        end
      end
    end

    context 'with existing upstream cache entries' do
      before do
        upstream.save!
        create(
          :virtual_registries_packages_maven_cache_entry,
          upstream: upstream,
          relative_path: 'dummy/path/maven-metadata.xml'
        )
      end

      it 'uses the cache entry relative_path for the HEAD request' do
        test

        expect(Gitlab::HTTP).to have_received(:head).with(
          upstream.url_for('dummy/path/maven-metadata.xml'),
          headers: upstream.headers,
          follow_redirects: true
        )
      end
    end

    context 'for local upstream' do
      before do
        upstream.url = other_project_global_id
      end

      it { is_expected.to eq(success: true) }
    end
  end

  describe '#local_project' do
    where(:url, :expected_project) do
      nil                             | nil
      ref(:other_project_global_id)   | ref(:other_project)
      ref(:other_group_global_id)     | nil
      'https://gitlab.com/maven/test' | nil
    end

    with_them do
      subject(:local_project_upstream) do
        build(:virtual_registries_packages_maven_upstream, :without_credentials, url:).local_project
      end

      it { is_expected.to eq(expected_project) }
    end
  end

  describe '#local_group' do
    where(:url, :expected_project) do
      nil                             | nil
      ref(:other_project_global_id)   | nil
      ref(:other_group_global_id)     | ref(:other_group)
      'https://gitlab.com/maven/test' | nil
    end

    with_them do
      subject(:local_project_upstream) do
        build(:virtual_registries_packages_maven_upstream, :without_credentials, url:).local_group
      end

      it { is_expected.to eq(expected_project) }
    end
  end

  describe '#destroy_and_sync_positions' do
    let_it_be(:registry1) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry1_upstream) { create(:virtual_registries_packages_maven_registry_upstream, registry: registry1) }

    let_it_be(:other_registry1_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry1)
    end

    let_it_be(:registry2) { create(:virtual_registries_packages_maven_registry) }
    let_it_be(:registry2_upstream) do
      create(
        :virtual_registries_packages_maven_registry_upstream,
        registry: registry2,
        upstream: registry1_upstream.upstream
      )
    end

    let_it_be(:other_registry2_upstream) do
      create(:virtual_registries_packages_maven_registry_upstream, registry: registry2)
    end

    subject(:destroy_and_sync) { registry1_upstream.upstream.destroy_and_sync_positions }

    it 'destroys the upstream and sync the registries positions' do
      expect { destroy_and_sync }.to change { ::VirtualRegistries::Packages::Maven::Upstream.count }.by(-1)
        .and change { registry1.reload.registry_upstreams.count }.from(2).to(1)
        .and change { registry2.reload.registry_upstreams.count }.from(2).to(1)
        .and change { other_registry1_upstream.reload.position }.from(2).to(1)
        .and change { other_registry2_upstream.reload.position }.from(2).to(1)
    end
  end
end
