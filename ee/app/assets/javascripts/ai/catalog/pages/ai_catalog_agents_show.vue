<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isNumeric } from '~/lib/utils/number_utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import aiCatalogAgentQuery from '../graphql/ai_catalog_agent.query.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_AGENTS_RUN_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    GlButton,
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
    agentId() {
      return this.aiCatalogAgent?.id || this.$route.params.id;
    },
    agentName() {
      return this.aiCatalogAgent?.name || '';
    },
    pageTitle() {
      return `${s__('AICatalog|Edit agent')}: ${this.agentName}`;
    },
  },
  methods: {
    onBack() {
      // TODO: Consider routing strategy for "back" navigation
      // Currently using hardcoded routes to go "back" to previous page in user flow.
      // Issue: Users could theoretically come from anywhere, then get routed back to
      // whatever is in history, which may not be the intended previous step.
      // For now, keeping this approach but may need to revisit if we implement
      // run page in drawer or need more sophisticated navigation handling.
      this.$router.back();
    },
  },
  runRoute: AI_CATALOG_AGENTS_RUN_ROUTE,
};
</script>

<template>
  <div>
    <gl-button @click="onBack">
      {{ __('Go back') }}
    </gl-button>

    <page-heading :heading="pageTitle">
      <template #actions>
        <gl-button :to="{ name: $options.runRoute, params: { id: agentId } }">
          {{ s__('AICatalog|Run') }}
        </gl-button>
      </template>
    </page-heading>
  </div>
</template>
