<script>
import { GlTabs, GlTab, GlBadge, GlLoadingIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import ProjectSecurityExclusionQuery from 'ee/security_configuration/project_security_exclusions/project_security_exclusions.query.graphql';
import EmptyState from './empty_state.vue';
import ExclusionList from './exclusion_list.vue';

export default {
  components: {
    GlTabs,
    GlTab,
    GlBadge,
    EmptyState,
    GlLoadingIcon,
    ExclusionList,
  },
  inject: ['projectFullPath'],
  i18n: {
    pageHeading: s__('SecretDetection|Secret detection configuration'),
  },
  data() {
    return {
      exclusions: [],
    };
  },
  apollo: {
    exclusions: {
      query: ProjectSecurityExclusionQuery,
      variables() {
        return {
          fullPath: this.projectFullPath,
        };
      },
      update(data) {
        return data?.project?.exclusions?.nodes || [];
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.exclusions.loading;
    },
  },
};
</script>

<template>
  <div>
    <h1>{{ $options.i18n.pageHeading }}</h1>
    <gl-tabs>
      <gl-tab>
        <template #title>
          <span>{{ __('Exclusions') }}</span>
          <gl-badge class="gl-tab-counter-badge" variant="neutral">{{
            exclusions.length
          }}</gl-badge>
        </template>

        <div class="gl-mt-3">
          <empty-state v-if="!isLoading && !exclusions.length" />
          <gl-loading-icon v-else-if="isLoading" size="lg" class="gl-mt-5" />
          <exclusion-list v-else :exclusions="exclusions" />
        </div>
      </gl-tab>
    </gl-tabs>
  </div>
</template>
