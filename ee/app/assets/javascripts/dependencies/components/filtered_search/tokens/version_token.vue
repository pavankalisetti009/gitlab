<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';

export default {
  components: {
    GlFilteredSearchToken,
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
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {};
  },
  computed: {
    ...mapGetters(['selectedComponents']),
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : [],
      };
    },
    noSelectedComponent() {
      return this.selectedComponents.length === 0;
    },
    multipleSelectedComponents() {
      return this.selectedComponents.length > 1;
    },
    viewOnly() {
      return this.noSelectedComponent || this.multipleSelectedComponents;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :value="tokenValue"
    :view-only="viewOnly"
    v-on="$listeners"
  >
    <template #suggestions>
      <div v-if="noSelectedComponent" class="gl-p-2 gl-text-secondary">
        {{ s__('Dependencies|To filter by version, filter by one component first') }}
      </div>
      <div v-else-if="multipleSelectedComponents" class="gl-p-2 gl-text-secondary">
        {{ s__('Dependencies|To filter by version, select exactly one component first') }}
      </div>
    </template>
  </gl-filtered-search-token>
</template>
