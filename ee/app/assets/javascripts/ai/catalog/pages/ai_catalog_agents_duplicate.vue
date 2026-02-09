<script>
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import AiCatalogAgentHeader from '../components/ai_catalog_agent_header.vue';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG } from '../constants';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';
import { prerequisitesError, resolveVersion } from '../utils';

export default {
  name: 'AiCatalogAgentsDuplicate',
  components: {
    AiCatalogAgentForm,
    AiCatalogAgentHeader,
  },
  inject: {
    isGlobal: {
      default: false,
    },
  },
  props: {
    aiCatalogAgent: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errorMessages: [],
      isSubmitting: false,
      selectedItemType: this.aiCatalogAgent.itemType,
    };
  },
  computed: {
    agentName() {
      return this.aiCatalogAgent.name;
    },
    activeVersion() {
      return resolveVersion(this.aiCatalogAgent, this.isGlobal);
    },
    systemPrompt() {
      return this.activeVersion.systemPrompt;
    },
    toolIds() {
      return (this.activeVersion.tools?.nodes ?? []).map((t) => t.id);
    },
    definition() {
      return this.activeVersion.definition;
    },
    initialValues() {
      return {
        name: `${s__('AICatalog|Copy of')} ${this.agentName}`,
        description: this.aiCatalogAgent.description,
        systemPrompt: this.systemPrompt,
        tools: this.toolIds,
        definition: this.definition,
        public: false,
        itemType: this.aiCatalogAgent.itemType,
      };
    },
  },
  methods: {
    async handleSubmit({ itemType, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[itemType].create;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input,
          },
        });

        if (data) {
          const { item, errors } = data[config.responseKey];
          if (errors.length > 0) {
            this.errorMessages = errors;
            return;
          }

          const newAgentId = getIdFromGraphQLId(item.id);
          this.$toast.show(s__('AICatalog|Agent created.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: newAgentId },
          });
        }
      } catch (error) {
        this.errorMessages = [
          prerequisitesError(
            s__(
              'AICatalog|Could not create agent in the project. Check that the project meets the %{linkStart}prerequisites%{linkEnd} and try again.',
            ),
          ),
        ];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errorMessages = [];
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-agent-header
      :heading="s__('AICatalog|Duplicate agent')"
      :description="s__('AICatalog|Create a copy of this agent with the same configuration.')"
      :item-type="aiCatalogAgent.itemType"
    />
    <ai-catalog-agent-form
      mode="create"
      :is-loading="isSubmitting"
      :errors="errorMessages"
      :initial-values="initialValues"
      @dismiss-errors="resetErrorMessages"
      @select-item-type="selectedItemType = $event"
      @submit="handleSubmit"
    />
  </div>
</template>
