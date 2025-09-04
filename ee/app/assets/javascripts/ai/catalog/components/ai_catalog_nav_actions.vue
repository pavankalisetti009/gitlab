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
  computed: {
    isLoggedIn() {
      return isLoggedIn();
    },
    buttonProps() {
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
  <div class="gl-flex gl-items-center">
    <gl-button 
      v-if="isLoggedIn && buttonProps.route" 
      :to="{ name: buttonProps.route }" 
      variant="confirm"
    >
      {{ buttonProps.label }}
    </gl-button>
  </div>
</template>
