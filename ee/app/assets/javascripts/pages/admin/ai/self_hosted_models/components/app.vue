<script>
import { GlEmptyState, GlButton, GlSkeletonLoader } from '@gitlab/ui';
import EmptyEnvironmentSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-environment-md.svg?url';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getSelfHostedModelsQuery from '../graphql/queries/get_self_hosted_models.query.graphql';
import SelfHostedModelsTable from './self_hosted_models_table.vue';

export default {
  name: 'SelfHostedModelsApp',
  components: {
    GlEmptyState,
    GlButton,
    GlSkeletonLoader,
    SelfHostedModelsTable,
    PageHeading,
  },
  provide() {
    return {
      aiFeatureSettingsPath: this.aiFeatureSettingsPath,
    };
  },
  props: {
    basePath: {
      type: String,
      required: true,
    },
    aiFeatureSettingsPath: {
      type: String,
      required: true,
    },
    newSelfHostedModelPath: {
      type: String,
      required: true,
    },
  },
  i18n: {
    emptyStateTitle: s__('AdminSelfHostedModels|Get started with Self‑hosted models'),
    emptyStateDescription: s__(
      'AdminSelfHostedModels|Add and manage models that can be used for GitLab AI features.',
    ),
    emptyStatePrimaryButtonText: s__('AdminSelfHostedModels|Add self-hosted model'),
    errorMessage: s__(
      'AdminSelfHostedModels|An error occurred while loading self-hosted models. Please try again.',
    ),
  },
  data() {
    return {
      selfHostedModels: [],
    };
  },
  apollo: {
    selfHostedModels: {
      query: getSelfHostedModelsQuery,
      update(data) {
        return data.aiSelfHostedModels?.nodes || [];
      },
      error(error) {
        createAlert({ message: this.$options.i18n.errorMessage, error, captureError: true });
      },
    },
  },
  computed: {
    hasModels() {
      return this.selfHostedModels.length > 0;
    },
    isLoading() {
      return this.$apollo?.queries?.selfHostedModels?.loading;
    },
  },
  emptyStateSvgPath: EmptyEnvironmentSvg,
};
</script>
<template>
  <div>
    <div v-if="!hasModels && !isLoading">
      <div class="justify-content-center gl-flex gl-items-center">
        <gl-empty-state
          class="gl-w-1/4"
          :title="$options.i18n.emptyStateTitle"
          :description="$options.i18n.emptyStateDescription"
          :svg-path="$options.emptyStateSvgPath"
          :svg-height="150"
          :primary-button-text="$options.i18n.emptyStatePrimaryButtonText"
          :primary-button-link="newSelfHostedModelPath"
        />
      </div>
    </div>
    <div v-else>
      <page-heading :heading="s__('AdminSelfHostedModels|Self-hosted models')">
        <template #description>
          {{
            s__('AdminSelfHostedModels|Manage AI models that can be used for GitLab AI features.')
          }}
        </template>

        <template v-if="hasModels" #actions>
          <gl-button category="primary" variant="confirm" :href="newSelfHostedModelPath"
            >{{ s__('AdminSelfHostedModels|Add self-hosted model') }}
          </gl-button>
        </template>
      </page-heading>

      <gl-skeleton-loader v-if="isLoading" />
      <self-hosted-models-table v-else :models="selfHostedModels" :base-path="basePath" />
    </div>
  </div>
</template>
