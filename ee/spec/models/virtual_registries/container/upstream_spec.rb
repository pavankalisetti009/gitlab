# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Upstream, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group) }

  subject(:upstream) do
    build(
      :virtual_registries_container_upstream,
      username: 'testuser',
      password: 'testpassword',
      url: 'https://registry-1.docker.io',
      group: group
    )
  end

  describe 'associations', :aggregate_failures do
    it 'has many registry upstreams' do
      is_expected.to have_many(:registry_upstreams)
        .class_name('VirtualRegistries::Container::RegistryUpstream')
        .inverse_of(:upstream)
        .autosave(true)
    end

    it 'has many registries' do
      is_expected.to have_many(:registries)
        .through(:registry_upstreams)
        .class_name('VirtualRegistries::Container::Registry')
    end
  end

  describe 'validations', :aggregate_failures do
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_length_of(:username).is_at_most(510) }
    it { is_expected.to validate_presence_of(:password) }
    it { is_expected.to validate_length_of(:password).is_at_most(510) }

    context 'for credentials' do
      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands -- false positive
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
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands

      with_them do
        before do
          upstream.username = username
          upstream.password = password
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

    describe '#credentials_uniqueness_for_group' do
      let_it_be(:group) { create(:group) }
      let_it_be(:group2) { create(:group) }
      let_it_be(:existing_upstream) do
        create(
          :virtual_registries_container_upstream,
          group: group,
          url: 'https://example.com',
          username: 'user',
          password: 'pass'
        )
      end

      where(:test_group, :url, :username, :password, :valid, :description) do
        ref(:group)  | 'https://example.com'   | 'user'      | 'pass'      | false | 'same group, same credentials'
        ref(:group)  | 'https://example.com'   | 'user'      | 'different' | true  | 'same group, different password'
        ref(:group)  | 'https://example.com'   | 'different' | 'pass'      | true  | 'same group, different username'
        ref(:group)  | 'https://different.com' | 'user'      | 'pass'      | true  | 'same group, different URL'
        ref(:group2) | 'https://example.com'   | 'user'      | 'pass'      | true  | 'different group, same credentials'
      end

      with_them do
        context 'when creating new upstream' do
          subject do
            build(
              :virtual_registries_container_upstream,
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
              is_expected.to be_invalid
                .and have_attributes(errors: match_array(['Group already has an upstream with the same credentials']))
            end
          end
        end

        context 'when updating existing upstream' do
          let_it_be(:updated_upstream) do
            create(
              :virtual_registries_container_upstream,
              group: group,
              url: 'https://example2.com',
              username: 'user',
              password: 'pass'
            )
          end

          subject { updated_upstream }

          before do
            updated_upstream.assign_attributes(group: test_group, url: url, username: username, password: password)
          end

          it "is #{params[:valid] ? 'valid' : 'invalid'} when updating to #{params[:description]}" do
            if valid
              is_expected.to be_valid
            else
              is_expected.to be_invalid
                .and have_attributes(errors: match_array(['Group already has an upstream with the same credentials']))
            end
          end
        end
      end
    end
  end

  describe 'scopes' do
    describe '.search_by_name' do
      let(:query) { 'abc' }
      let_it_be(:name) { 'name-abc' }
      let_it_be(:upstream) { create(:virtual_registries_container_upstream, name: name) }
      let_it_be(:other_upstream) { create(:virtual_registries_container_upstream) }

      subject { described_class.search_by_name(query) }

      it { is_expected.to eq([upstream]) }
    end
  end

  it_behaves_like 'virtual registry upstream scopes',
    registry_factory: :virtual_registries_container_registry,
    upstream_factory: :virtual_registries_container_upstream

  describe '#as_json' do
    subject { upstream.as_json }

    it { is_expected.not_to include('password') }
  end

  describe '#object_storage_key' do
    let_it_be(:upstream) { build_stubbed(:virtual_registries_container_upstream) }

    it_behaves_like 'virtual registries: has object storage key', key_prefix: 'container'
  end

  it_behaves_like 'virtual registry upstream common behavior'

  describe '#local?' do
    subject { upstream.local? }

    it { is_expected.to be false }
  end

  describe '#remote?' do
    subject { upstream.remote? }

    it { is_expected.to be true }
  end

  describe '#url_for' do
    subject { upstream.url_for(path) }

    where(:path, :expected_url) do
      'library/alpine/manifests/latest'     | 'https://registry-1.docker.io/v2/library/alpine/manifests/latest'
      'nginx/nginx/tags/list'               | 'https://registry-1.docker.io/v2/nginx/nginx/tags/list'
      ''                                    | 'https://registry-1.docker.io/v2/'
      '/library/alpine/manifests/latest'    | 'https://registry-1.docker.io/v2/library/alpine/manifests/latest'
      '/project/app/blobs/sha256:abc123'    | 'https://registry-1.docker.io/v2/project/app/blobs/sha256:abc123'
    end

    with_them do
      before do
        upstream.url = 'https://registry-1.docker.io'
      end

      it { is_expected.to eq(expected_url) }
    end

    context 'with URL edge cases' do
      where(:registry_url, :path, :expected_url) do
        'https://registry.example.com/'    | 'alpine/manifests/latest' | 'https://registry.example.com/v2/alpine/manifests/latest'
        'https://registry.example.com/v2'  | 'alpine/manifests/latest' | 'https://registry.example.com/v2/alpine/manifests/latest'
        'https://registry.example.com/v2/' | 'alpine/manifests/latest' | 'https://registry.example.com/v2/alpine/manifests/latest'
      end

      with_them do
        before do
          upstream.url = registry_url
        end

        it { is_expected.to eq(expected_url) }
      end
    end
  end

  describe '#headers' do
    let(:path) { 'library/alpine/manifests/latest' }

    subject { upstream.headers(path) }

    context 'without credentials' do
      # rubocop:disable Lint/BinaryOperatorWithIdenticalOperands -- binary operator is used in parameterized table
      where(:username, :password) do
        nil  |  nil
        ''   |  ''
        ''   |  nil
        nil  |  ''
      end
      # rubocop:enable Lint/BinaryOperatorWithIdenticalOperands

      with_them do
        before do
          upstream.username = username
          upstream.password = password

          # Stub the authentication discovery request (Layer 1 discovery)
          stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

          # Stub the token exchange request (Layer 1 authentication)
          stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
            .to_return(
              status: 200,
              body: '{"token": "successful_bearer_token_123"}'
            )
        end

        it { is_expected.to eq(with_accept_headers({ 'Authorization' => 'Bearer successful_bearer_token_123' })) }
      end
    end

    context 'with credentials and successful authentication' do
      before do
        upstream.url = 'https://registry-1.docker.io'

        # Stub the authentication discovery request (Layer 1 discovery)
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        # Stub the token exchange request (Layer 1 authentication)
        stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
          .with(headers: { 'Authorization' => 'Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk' })
          .to_return(
            status: 200,
            body: '{"token": "successful_bearer_token_123"}'
          )
      end

      it { is_expected.to eq(with_accept_headers({ 'Authorization' => 'Bearer successful_bearer_token_123' })) }
    end

    context 'with credentials but authentication discovery fails' do
      before do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(status: 200)
      end

      it { is_expected.to eq({}) }
    end

    context 'with credentials but token exchange fails' do
      before do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
          .with(headers: { 'Authorization' => 'Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk' })
          .to_return(status: 401, body: '{"error": "invalid_credentials"}')
      end

      it { is_expected.to eq({}) }
    end

    context 'with different registry types' do
      # rubocop:disable Layout/LineLength -- have the params in the same line for readability
      where(:registry_url, :auth_realm, :service_name, :expected_token) do
        'https://registry-1.docker.io' | 'https://auth.docker.io/token' | 'registry.docker.io' | 'dockerhub_bearer_token'
        'https://gcr.io'               | 'https://gcr.io/v2/token'           | 'gcr.io'              | 'gcr_bearer_token'
        'https://public.ecr.aws'       | 'https://public.ecr.aws/token'      | 'public.ecr.aws'      | 'ecr_bearer_token'
        'https://quay.io'              | 'https://quay.io/v2/auth'           | 'quay.io'             | 'quay_bearer_token'
        'https://harbor.example.com'   | 'https://harbor.example.com/service/token' | 'harbor.example.com' | 'harbor_bearer_token'
      end
      # rubocop:enable Layout/LineLength

      with_them do
        before do
          upstream.url = registry_url
          scope = 'repository:library/alpine:pull'

          # Stub auth discovery for each registry type
          stub_request(:head, "#{registry_url}/v2/#{path}")
            .to_return(
              status: 401,
              headers: {
                'www-authenticate' => "Bearer realm=\"#{auth_realm}\",service=\"#{service_name}\",scope=\"#{scope}\""
              }
            )

          # Stub token exchange for each registry type
          stub_request(:get, "#{auth_realm}?service=#{service_name}&scope=#{scope}")
            .with(headers: { 'Authorization' => 'Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk' })
            .to_return(
              status: 200,
              body: "{\"token\": \"#{expected_token}\"}"
            )
        end

        it 'successfully authenticates with different registry types' do
          result = upstream.headers(path)
          expect(result).to eq(with_accept_headers({ 'Authorization' => "Bearer #{expected_token}" }))
        end
      end
    end

    context 'with network error scenarios' do
      before do
        upstream.url = 'https://registry-1.docker.io'
      end

      it 'handles auth discovery network errors gracefully' do
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_raise(Errno::ECONNREFUSED.new('Network timeout'))

        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(Errno::ECONNREFUSED),
          hash_including(message: /Failed to get auth challenge/)
        )
        expect(upstream.headers(path)).to eq({})
      end

      it 'handles token exchange network errors gracefully' do
        # Successful auth discovery
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        # Failed token exchange
        stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
          .to_raise(SocketError.new('Auth service unavailable'))

        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(SocketError),
          hash_including(message: /Token request error/)
        )
        expect(upstream.headers(path)).to eq({})
      end

      it 'handles invalid JSON token response gracefully' do
        # Successful auth discovery
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io",scope="repository:library/alpine:pull"'
            }
          )

        # Token exchange with invalid JSON
        stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/alpine:pull')
          .to_return(status: 200, body: 'invalid json response')

        expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
          an_instance_of(JSON::ParserError),
          hash_including(message: /Failed to parse token response/)
        )
        expect(upstream.headers(path)).to eq({})
      end
    end

    context 'with malformed auth challenges' do
      before do
        upstream.url = 'https://registry-1.docker.io'
        stub_request(:head, "#{upstream.url}/v2/#{path}")
                    .to_return(
                      status: 401,
                      headers: { 'www-authenticate' => auth_header }
                    )

        unless should_fail
          stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io')
            .to_return(status: 200, body: '{"token": "valid_token"}')
        end
      end

      where(:auth_header, :should_fail) do
        'Basic realm="test"' | true
        'Bearer invalid_format'                                | true
        'Bearer realm="https://auth.example.com/token"'        | true  # Missing service
        'Bearer service="registry.example.com"'                | true  # Missing realm
        'Bearer realm="https://auth.docker.io/token",service="registry.docker.io"' | false # Valid
      end

      with_them do
        if params[:should_fail]
          it 'returns empty headers for malformed auth challenges' do
            expect(upstream.headers(path)).to eq({})
          end
        else
          it 'processes valid auth challenges successfully' do
            expect(upstream.headers(path)).to eq(with_accept_headers({ 'Authorization' => 'Bearer valid_token' }))
          end
        end
      end
    end

    context 'without scope parameter' do
      before do
        upstream.url = 'https://registry-1.docker.io'

        # Auth discovery without scope
        stub_request(:head, "#{upstream.url}/v2/#{path}")
          .to_return(
            status: 401,
            headers: {
              'www-authenticate' => 'Bearer realm="https://auth.docker.io/token",service="registry.docker.io"'
            }
          )

        # Token exchange without scope parameter
        stub_request(:get, 'https://auth.docker.io/token?service=registry.docker.io')
          .with(headers: { 'Authorization' => 'Basic dGVzdHVzZXI6dGVzdHBhc3N3b3Jk' })
          .to_return(
            status: 200,
            body: '{"access_token": "no_scope_token"}'
          )
      end

      it 'handles authentication without scope parameter' do
        result = upstream.headers(path)
        expect(result).to eq(with_accept_headers({ 'Authorization' => 'Bearer no_scope_token' }))
      end
    end
  end

  describe '#default_cache_entries' do
    let_it_be(:upstream) { create(:virtual_registries_container_upstream) }
    let_it_be(:default_cache_entry) { create(:virtual_registries_container_cache_entry, upstream:) }
    let_it_be(:pending_destruction_cache_entry) do
      create(:virtual_registries_container_cache_entry, :pending_destruction, upstream:)
    end

    subject { upstream.default_cache_entries }

    it { is_expected.to contain_exactly(default_cache_entry) }
  end

  def with_accept_headers(headers)
    headers.merge(described_class::REGISTRY_ACCEPT_HEADERS)
  end
end
