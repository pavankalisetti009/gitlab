<script>
import { GlButton } from '@gitlab/ui';
import { AI_CATALOG_AGENTS_NEW_ROUTE, AI_CATALOG_FLOWS_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogNavActions',
  components: {
    GlButton,
  },
  computed: {
    shouldDisplayButton() {
      return this.$route.path !== AI_CATALOG_FLOWS_ROUTE;
    },
  },
  newAgentRoute: AI_CATALOG_AGENTS_NEW_ROUTE,
};
</script>

<template>
  <gl-button v-if="shouldDisplayButton" :to="{ name: $options.newAgentRoute }" variant="confirm">
    {{ s__('AICatalog|Create agent') }}
  </gl-button>
</template>
