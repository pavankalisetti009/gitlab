<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ROUTES } from '../constants';

export default {
  components: {
    GlBreadcrumb,
  },
  props: {
    staticBreadcrumbs: {
      type: Object,
      default: () => ({ items: [] }),
      required: false,
    },
  },
  computed: {
    breadcrumbs() {
      const breadcrumbs = [
        ...this.staticBreadcrumbs.items,
        {
          text: s__('ServiceAccounts|Service accounts'),
          to: '/',
        },
      ];

      if (this.$route.name === ROUTES.accessTokens) {
        breadcrumbs.push({
          text: s__('ServiceAccounts|Personal access tokens'),
          to: this.$route.path,
        });
      }

      return breadcrumbs;
    },
  },
};
</script>

<template>
  <gl-breadcrumb :items="breadcrumbs" />
</template>
