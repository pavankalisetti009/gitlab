<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
} from '../router/constants';

export default {
  name: 'AiCatalogNavActions',
  components: {
    GlButton,
  },
  props: {
    canAdmin: {
      type: Boolean,
      required: false,
      default: true, // this will change when we remove the ability to create item from Explore level
    },
    newButtonVariant: {
      type: String,
      required: false,
      default: 'confirm',
    },
  },
  computed: {
    showNewButton() {
      return isLoggedIn() && this.canAdmin && this.newButtonProps.route;
    },
    newButtonProps() {
      switch (this.$route.name) {
        case AI_CATALOG_INDEX_ROUTE:
        case AI_CATALOG_AGENTS_ROUTE:
          return {
            route: AI_CATALOG_AGENTS_NEW_ROUTE,
            label: s__('AICatalog|New agent'),
          };
        case AI_CATALOG_FLOWS_ROUTE:
          return {
            route: AI_CATALOG_FLOWS_NEW_ROUTE,
            label: s__('AICatalog|New flow'),
          };
        default:
          return {
            route: null,
            label: '',
          };
      }
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <gl-button
      v-if="showNewButton"
      :to="{ name: newButtonProps.route }"
      :variant="newButtonVariant"
    >
      {{ newButtonProps.label }}
    </gl-button>
    <slot></slot>
  </div>
</template>
