<script>
import { GlTabs, GlTab, GlBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import EmptyState from './empty_state.vue';

export default {
  components: {
    GlTabs,
    GlTab,
    GlBadge,
    EmptyState,
  },
  inject: ['projectFullPath'],
  i18n: {
    pageHeading: s__('SecretDetection|Secret detection configuration'),
  },
  data() {
    return {
      count: 0,
    };
  },
  computed: {
    showEmtpyState() {
      return !this.count;
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
          <gl-badge class="gl-tab-counter-badge" variant="neutral">{{ count }}</gl-badge>
        </template>

        <div class="gl-mt-8">
          <empty-state v-if="showEmtpyState" />
        </div>
      </gl-tab>
    </gl-tabs>
  </div>
</template>
