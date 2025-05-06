<script>
import { GlBreadcrumb } from '@gitlab/ui';
import { s__ } from '~/locale';
import { ROUTES } from '../constants';

export default {
  components: {
    GlBreadcrumb,
  },
  computed: {
    breadcrumbs() {
      const breadcrumbs = [
        {
          text: s__('ServiceAccounts|Service Accounts'),
          to: '/',
        },
      ];

      if (this.$route.name === ROUTES.accessTokens) {
        breadcrumbs.push({
          text: s__('ServiceAccounts|Access Tokens'),
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
