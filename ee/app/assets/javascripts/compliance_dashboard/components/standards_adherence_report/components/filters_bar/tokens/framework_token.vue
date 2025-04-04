<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import FrameworkBadge from '../../../../shared/framework_badge.vue';

export default {
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,

    FrameworkBadge,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  methods: {
    findActiveFramework(inputValue) {
      return this.config.frameworks.find((f) => f.id === inputValue);
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="$listeners">
    <template #view="{ inputValue }">
      <framework-badge popover-mode="hidden" :framework="findActiveFramework(inputValue)" />
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="framework in config.frameworks"
        :key="framework.id"
        :value="framework.id"
      >
        <framework-badge popover-mode="hidden" :framework="framework" />
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
