# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Security::ScanProfilesResolver, feature_category: :security_asset_inventories do
  include GraphqlHelpers

  let_it_be(:root_group) { create(:group) }
  let_it_be(:subgroup) { create(:group, parent: root_group) }
  let_it_be(:user) { create(:user) }

  let(:current_user) { user }

  subject(:resolve_scan_profiles) do
    resolve(described_class, obj: group, args: args, ctx: { current_user: current_user })
  end

  before_all do
    root_group.add_developer(user)
  end

  def default_profile_by_type(type)
    ::Security::DefaultScanProfilesHelper.default_scan_profiles
      .find { |p| p.scan_type == type.to_s }
  end

  describe '#resolve' do
    context 'when security_scan_profiles feature is not available' do
      let(:group) { root_group }
      let(:args) { {} }

      it 'raises an authorization error' do
        expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
          resolve_scan_profiles
        end
      end
    end

    context 'when security_scan_profiles feature is available' do
      before do
        stub_licensed_features(security_scan_profiles: true)
      end

      context 'when user does not have permission' do
        let(:group) { root_group }
        let(:args) { {} }
        let(:current_user) { create(:user) }

        it 'raises an authorization error' do
          expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ResourceNotAvailable) do
            resolve_scan_profiles
          end
        end
      end

      context 'when user has permission' do
        context 'when resolving from root group' do
          let(:group) { root_group }

          context 'without type argument' do
            let(:args) { {} }

            context 'when there are no persisted scan profiles' do
              it 'returns only default scan profiles' do
                profiles = resolve_scan_profiles
                default_profiles = ::Security::DefaultScanProfilesHelper.default_scan_profiles

                expect(profiles.size).to eq(default_profiles.size)

                default_profiles.each do |default|
                  matching_profile = profiles.find { |p| p.scan_type == default.scan_type }
                  expect(matching_profile).to have_attributes(
                    scan_type: default.scan_type,
                    name: default.name,
                    description: default.description,
                    gitlab_recommended: default.gitlab_recommended,
                    namespace_id: root_group.id
                  )
                end
              end
            end

            context 'when there are persisted profiles without gitlab_recommended' do
              let_it_be(:custom_profile) do
                create(:security_scan_profile,
                  namespace: root_group,
                  scan_type: :sast,
                  name: 'Custom SAST',
                  gitlab_recommended: false)
              end

              it 'returns both persisted and default scan profiles' do
                profiles = resolve_scan_profiles

                expect(profiles.size).to eq(2)
                expect(profiles).to include(custom_profile)
                expect(profiles.map(&:scan_type)).to match_array(%w[secret_detection sast])
              end
            end

            context 'when there is a persisted gitlab_recommended profile' do
              let_it_be(:recommended_secret_detection) do
                create(:security_scan_profile,
                  namespace: root_group,
                  scan_type: :secret_detection,
                  name: 'Persisted Secret Detection (default)',
                  gitlab_recommended: true)
              end

              it 'returns only the persisted profile without the default' do
                profiles = resolve_scan_profiles
                default_secret_detection = default_profile_by_type(:secret_detection)

                expect(profiles.size).to eq(1)
                expect(profiles).to include(recommended_secret_detection)
                expect(profiles.map(&:name)).not_to include(default_secret_detection.name)
              end
            end

            context 'when there are multiple persisted profiles without gitlab_recommended' do
              let_it_be(:sast_profile) do
                create(:security_scan_profile,
                  namespace: root_group,
                  scan_type: :sast,
                  name: 'SAST Profile',
                  gitlab_recommended: false)
              end

              it 'returns all persisted profiles and defaults for types without recommended profiles' do
                profiles = resolve_scan_profiles

                expect(profiles).to include(sast_profile)
                expect(profiles.map(&:scan_type)).to match_array(%w[secret_detection sast])
              end
            end
          end

          context 'with type argument' do
            context 'when filtering by secret_detection' do
              let(:args) { { type: 'secret_detection' } }

              context 'when there are no persisted profiles of that type' do
                let_it_be(:sast_profile) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :sast,
                    name: 'SAST Profile')
                end

                it 'returns only the default secret_detection profile' do
                  profiles = resolve_scan_profiles
                  default_secret_detection = default_profile_by_type(:secret_detection)

                  expect(profiles.size).to eq(1)
                  expect(profiles.first).to have_attributes(
                    scan_type: default_secret_detection.scan_type,
                    name: default_secret_detection.name,
                    description: default_secret_detection.description,
                    gitlab_recommended: default_secret_detection.gitlab_recommended
                  )
                end
              end

              context 'when there is a persisted gitlab_recommended profile of that type' do
                let_it_be(:recommended_secret_detection) do
                  create(:security_scan_profile,
                    namespace: root_group,
                    scan_type: :secret_detection,
                    name: 'Persisted Secret Detection (default)',
                    gitlab_recommended: true)
                end

                it 'returns only the recommended profile without the default' do
                  profiles = resolve_scan_profiles
                  default_secret_detection = default_profile_by_type(:secret_detection)

                  expect(profiles.size).to eq(1)
                  expect(profiles).to include(recommended_secret_detection)
                  expect(profiles.map(&:name)).not_to include(default_secret_detection.name)
                end
              end
            end
          end
        end

        context 'when resolving from subgroup' do
          let(:group) { subgroup }
          let(:args) { {} }

          it 'uses root ancestor for fetching profiles' do
            profiles = resolve_scan_profiles

            expect(profiles.first.namespace_id).to eq(root_group.id)
          end
        end
      end
    end
  end
end
