# frozen_string_literal: true

require 'spec_helper'

RSpec.describe VirtualRegistries::Container::Upstream, feature_category: :virtual_registry do
  using RSpec::Parameterized::TableSyntax

  subject(:upstream) { build(:virtual_registries_container_upstream) }

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
end
