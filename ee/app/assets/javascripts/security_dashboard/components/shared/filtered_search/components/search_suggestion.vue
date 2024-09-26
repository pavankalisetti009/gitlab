<script>
import { GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';

export default {
  components: {
    GlFilteredSearchSuggestion,
    GlIcon,
  },
  props: {
    /**
     * The value of the suggestion.
     * This is passed to gl-filtered-search-suggestion and used in data test ids.
     */
    value: {
      type: [String, Number],
      required: true,
    },
    text: {
      type: String,
      required: true,
    },
    /**
     * The name of the token. Used for data test ids.
     */
    name: {
      type: String,
      required: true,
    },
    selected: {
      type: Boolean,
      required: true,
    },
  },
};
</script>
<template>
  <gl-filtered-search-suggestion :value="value">
    <div :data-testid="`${name}-search-token-suggestion-${value}`" class="gl-flex gl-items-center">
      <gl-icon
        name="check"
        class="gl-mr-3 gl-shrink-0 gl-text-gray-700"
        :class="{ 'gl-invisible': !selected }"
        :data-testid="`${name}-icon-${value}`"
      />
      {{ text }}
    </div>
  </gl-filtered-search-suggestion>
</template>
