# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::ProjectContainerRegistryProtectionTagRules, :aggregate_failures,
  feature_category: :container_registry do
  include ContainerRegistryHelpers

  let_it_be(:project) { create(:project, :private) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }

  describe 'PATCH /projects/:id/registry/protection/tag/rules/:protection_rule_id' do
    let_it_be_with_reload(:tag_rule_to_update) do
      create(:container_registry_protection_tag_rule,
        project: project,
        tag_name_pattern: 'original-*',
        minimum_access_level_for_push: :maintainer,
        minimum_access_level_for_delete: :maintainer)
    end

    let(:protection_rule) { tag_rule_to_update }
    let(:protection_rule_id) { tag_rule_to_update.id }
    let(:path) { "registry/protection/tag/rules/#{protection_rule_id}" }
    let(:url) { "/projects/#{project.id}/#{path}" }
    let(:api_user) { maintainer }

    subject(:patch_tag_rule) { patch(api(url, api_user), params: params) }

    before do
      stub_gitlab_api_client_to_support_gitlab_api(supported: true)
    end

    shared_examples 'denies update' do |status|
      it "returns #{status} and does not update rule" do
        original_pattern = tag_rule_to_update.tag_name_pattern

        patch_tag_rule

        expect(response).to have_gitlab_http_status(status)
        expect(tag_rule_to_update.reload.tag_name_pattern).to eq(original_pattern)
      end
    end

    shared_examples 'returns EE validation error for mismatched access levels' do
      it 'returns validation error' do
        patch_tag_rule

        expect(json_response['message']['error'].first)
          .to include('Access levels should either both be present or both be nil')
      end
    end

    context 'for maintainer' do
      context 'with empty string to unset minimum_access_level_for_push' do
        let(:params) { { minimum_access_level_for_push: '' } }

        it_behaves_like 'denies update', :unprocessable_entity
        it_behaves_like 'returns EE validation error for mismatched access levels'
      end

      context 'with empty string to unset minimum_access_level_for_delete' do
        let(:params) { { minimum_access_level_for_delete: '' } }

        it_behaves_like 'denies update', :unprocessable_entity
        it_behaves_like 'returns EE validation error for mismatched access levels'
      end

      context 'when unsetting both access levels (creating immutable rule)' do
        let(:params) do
          {
            minimum_access_level_for_push: '',
            minimum_access_level_for_delete: ''
          }
        end

        it 'unsets both access levels', :aggregate_failures do
          expect { patch_tag_rule }.not_to change { protection_rule.reload }

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']['error'])
            .to include('Cannot create an immutable tag rule from a protection rule')
        end
      end

      context 'when updating an immutable rule (nil access levels)' do
        let_it_be(:immutable_tag_rule) do
          create(:container_registry_protection_tag_rule,
            project: project,
            tag_name_pattern: 'immutable-*',
            minimum_access_level_for_push: nil,
            minimum_access_level_for_delete: nil)
        end

        let(:protection_rule) { immutable_tag_rule }
        let(:protection_rule_id) { immutable_tag_rule.id }
        let(:params) do
          {
            minimum_access_level_for_push: 'maintainer',
            minimum_access_level_for_delete: 'owner'
          }
        end

        it 'denies the update', :aggregate_failures do
          patch_tag_rule

          expect(response).to have_gitlab_http_status(:unprocessable_entity)
          expect(json_response['message']['error']).to eq('Operation not allowed')
        end
      end
    end
  end
end
