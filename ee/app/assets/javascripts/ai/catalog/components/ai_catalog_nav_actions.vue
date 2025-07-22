<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
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
    buttonInfo() {
      switch (this.$route.path) {
        case AI_CATALOG_AGENTS_ROUTE:
          return {
            route: AI_CATALOG_AGENTS_NEW_ROUTE,
            label: s__('AICatalog|Create an agent'),
          };
        case AI_CATALOG_FLOWS_ROUTE:
          return {
            route: AI_CATALOG_FLOWS_NEW_ROUTE,
            label: s__('AICatalog|Create a flow'),
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
  <gl-button v-if="buttonInfo.route" :to="{ name: buttonInfo.route }" variant="confirm">
    {{ buttonInfo.label }}
  </gl-button>
</template>
