<script>
import { s__ } from '~/locale';
import { isNumeric } from '~/lib/utils/number_utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import aiCatalogAgentQuery from '../graphql/ai_catalog_agent.query.graphql';
import { AI_CATALOG_AGENTS_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    PageHeading,
  },
  beforeRouteEnter(to, _, next) {
    if (!isNumeric(to.params.id)) {
      next({ name: AI_CATALOG_AGENTS_ROUTE });
      return;
    }
    next((vm) => {
      try {
        const result = vm.$apollo.provider.clients.defaultClient.cache.readQuery({
          query: aiCatalogAgentQuery,
          variables: { id: String(to.params.id) },
        });

        if (!result.aiCatalogAgent) {
          // Agent not found, redirect
          vm.$router.push({ name: AI_CATALOG_AGENTS_ROUTE });
        }
      } catch (error) {
        const queryError = new Error(
          `Agent not found: Failed to query agent with ID ${to.params.id}`,
          {
            cause: error,
          },
        );
        Sentry.captureException(queryError);
        vm.$router.push({ name: AI_CATALOG_AGENTS_ROUTE });
      }
    });
  },
  apollo: {
    aiCatalogAgent: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: this.$route.params.id.toString(),
        };
      },
    },
  },
  data() {
    return {
      aiCatalogAgent: null,
    };
  },
  computed: {
    agentName() {
      return this.aiCatalogAgent?.name || '';
    },
    pageTitle() {
      return `${s__('AICatalog|Edit agent')}: ${this.agentName}`;
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="pageTitle" />
  </div>
</template>
