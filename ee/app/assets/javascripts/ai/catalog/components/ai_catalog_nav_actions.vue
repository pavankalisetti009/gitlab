<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
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
    buttonProps() {
      switch (this.$route.name) {
        case AI_CATALOG_INDEX_ROUTE:
        case AI_CATALOG_AGENTS_ROUTE:
          return {
            route: AI_CATALOG_AGENTS_NEW_ROUTE,
            label: s__('AICatalog|Create agent'),
          };
        case AI_CATALOG_FLOWS_ROUTE:
          return {
            route: AI_CATALOG_FLOWS_NEW_ROUTE,
            label: s__('AICatalog|Create flow'),
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
  <gl-button v-if="buttonProps.route" :to="{ name: buttonProps.route }" variant="confirm">
    {{ buttonProps.label }}
  </gl-button>
</template>
