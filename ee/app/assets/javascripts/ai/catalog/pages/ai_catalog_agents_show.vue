<script>
import { GlButton, GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';

import PageHeading from '~/vue_shared/components/page_heading.vue';
import aiCatalogAgentQuery from '../graphql/queries/ai_catalog_agent.query.graphql';
import { AI_CATALOG_AGENTS_RUN_ROUTE, AI_CATALOG_AGENTS_ROUTE } from '../router/constants';
import AiCatalogAgentCreateEditForm from '../components/ai_catalog_agent_create_edit_form.vue';
import { TYPENAME_AI_CATALOG_ITEM } from '../constants';

export default {
  name: 'AiCatalogAgentsShow',
  components: {
    AiCatalogAgentCreateEditForm,
    GlButton,
    GlModal,
    PageHeading,
  },
  apollo: {
    aiCatalogItem: {
      query: aiCatalogAgentQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_ITEM, this.$route.params.id),
        };
      },
      result(res) {
        this.onAgentQueryResult(res);
      },
    },
  },
  data() {
    return {
      aiCatalogItem: null,
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
      return getIdFromGraphQLId(this.aiCatalogItem?.id) || this.$route.params.id;
    },
    agentName() {
      return this.aiCatalogItem?.name || '';
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
    onAgentQueryResult({ data }) {
      if (!data || !data.aiCatalogItem) {
        const queryError = new Error(
          `Agent not found: Failed to query agent with ID ${this.$route.params.id}`,
        );
        Sentry.captureException(queryError);
        this.$router.push({ name: AI_CATALOG_AGENTS_ROUTE });
      }
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
  <div v-if="aiCatalogItem">
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
      v-if="aiCatalogItem"
      mode="edit"
      :name="aiCatalogItem.name"
      :description="aiCatalogItem.description"
      :system-prompt="aiCatalogItem.systemPrompt"
      :user-prompt="aiCatalogItem.userPrompt"
      :is-loading="isLoading"
      @submit="handleSubmit"
    />
    <gl-modal ref="modal" modal-id="TEMPORARY-MODAL">
      <pre>{{ JSON.stringify(updatedValues) }}</pre>
    </gl-modal>
  </div>
</template>
