<script>
import { GlLink, GlModal, GlSprintf } from '@gitlab/ui';

import { __ } from '~/locale';

import productAnalyticsProjectSettingsUpdate from '../../../graphql/mutations/product_analytics_project_settings_update.mutation.graphql';
import { updateProjectSettingsApolloCache } from './utils';

const NULL_PROJECT_SETTINGS = {
  productAnalyticsConfiguratorConnectionString: null,
  productAnalyticsDataCollectorHost: null,
  cubeApiBaseUrl: null,
  cubeApiKey: null,
};

export default {
  name: 'ClearProjectSettingsModal',
  components: { GlLink, GlModal, GlSprintf },
  inject: ['analyticsSettingsPath', 'namespaceFullPath'],
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
      hasError: false,
    };
  },
  computed: {
    modalPrimaryAction() {
      return {
        text: __('Continue'),
        attributes: {
          variant: 'confirm',
          loading: this.isLoading,
        },
      };
    },
    modalCancelAction() {
      return {
        text: __('Cancel'),
        attributes: {
          disabled: this.isLoading,
        },
      };
    },
  },
  methods: {
    onCancelClearSettings() {
      this.$emit('hide');
    },
    async clearProductAnalyticsProjectSettings() {
      this.hasError = false;
      this.isLoading = true;

      const { data } = await this.$apollo.mutate({
        mutation: productAnalyticsProjectSettingsUpdate,
        variables: {
          fullPath: this.namespaceFullPath,
          ...NULL_PROJECT_SETTINGS,
        },
        update: (store) => {
          updateProjectSettingsApolloCache(store, this.namespaceFullPath, NULL_PROJECT_SETTINGS);
        },
      });

      this.isLoading = false;
      const { errors } = data.productAnalyticsProjectSettingsUpdate;

      if (errors?.length) {
        this.hasError = true;
        return;
      }

      this.$emit('hide');
      this.$emit('cleared');
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    :action-primary="modalPrimaryAction"
    :action-cancel="modalCancelAction"
    data-testid="clear-project-level-settings-confirmation-modal"
    modal-id="clear-project-level-settings-confirmation-modal"
    :title="s__('ProductAnalytics|Reset existing project provider settings')"
    @primary="clearProductAnalyticsProjectSettings"
    @canceled="onCancelClearSettings"
  >
    <slot></slot>
    <p v-if="hasError" class="gl-mt-5 gl-text-red-500" data-testid="modal-error">
      <gl-sprintf
        :message="
          s__(
            'Analytics|Failed to clear project-level settings. Please try again or %{linkStart}clear them manually%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="analyticsSettingsPath">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </p>
  </gl-modal>
</template>
