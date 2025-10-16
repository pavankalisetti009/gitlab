<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AI_CATALOG_INDEX_ROUTE } from './constants';

export default {
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      required: true,
      type: Array,
    },
  },
  computed: {
    crumbs() {
      // Get the first matched items. Iterate over each of them and make them a breadcrumb item
      // only if they have a meta field with text
      const { id } = this.$route.params;
      const matchedRoutes = (this.$route?.matched || [])
        .map((route) => {
          const useRouteId = Boolean(route.meta?.useId);
          const text = useRouteId && id ? String(id) : route.meta?.text;

          // Skip routes without text
          if (!text) return null;

          let to;
          if (route.name) {
            // Route has a name, so we can link directly to it
            to = { name: route.name, params: this.$route.params };
          } else if (route.meta?.indexRoute) {
            // An unnamed route that has an indexRoute specified -- use the indexRoute
            to = { name: route.meta.indexRoute, params: this.$route.params };
          } else {
            // Fallback
            to = { path: route.path };
          }

          return { text, to };
        })
        .filter(Boolean);

      return [...this.staticCrumbs, ...matchedRoutes];
    },
    staticCrumbs() {
      return [
        ...this.staticBreadcrumbs,
        {
          text: s__('AICatalog|AI Catalog'),
          to: { name: AI_CATALOG_INDEX_ROUTE },
        },
      ];
    },
  },
};
</script>
<template>
  <gl-breadcrumb :items="crumbs" :auto-resize="false" />
</template>
