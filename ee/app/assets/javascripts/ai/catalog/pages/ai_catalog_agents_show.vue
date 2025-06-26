<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import { isNumeric } from '~/lib/utils/number_utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import aiCatalogAgentQuery from '../graphql/ai_catalog_agent.query.graphql';
import { AI_CATALOG_AGENTS_ROUTE, AI_CATALOG_AGENTS_RUN_ROUTE } from '../router/constants';
import AiCatalogAgentCreateEditForm from '../components/ai_catalog_agent_create_edit_form.vue';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    AiCatalogAgentCreateEditForm,
    GlButton,
    GlModal,
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
      isLoading: false,
      updatedValues: {
        name: '',
        description: '',
        systemPrompt: '',
        userPrompt: '',
      },
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
    handleSubmit(formValues) {
      this.isLoading = true;
      // TODO: Handle submission, dummy cody here. Replace with real implementation
      setTimeout(() => {
        this.updatedValues = formValues;
        this.$refs.modal.show();
        this.isLoading = false;
      }, 1000);
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
    <p>
      {{ s__('AICatalog|Modify the agent settings and configuration.') }}
    </p>
    <ai-catalog-agent-create-edit-form
      v-if="aiCatalogAgent"
      mode="edit"
      :name="aiCatalogAgent.name"
      :description="aiCatalogAgent.description"
      :system-prompt="aiCatalogAgent.systemPrompt"
      :user-prompt="aiCatalogAgent.userPrompt"
      :is-loading="isLoading"
      @submit="handleSubmit"
    />
    <gl-modal ref="modal" modal-id="TEMPORARY-MODAL">
      <pre>{{ JSON.stringify(updatedValues) }}</pre>
    </gl-modal>
  </div>
</template>
