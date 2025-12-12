<script>
import { GlExperimentBadge } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';
import { prerequisitesError, getByVersionKey } from '../utils';

export default {
  name: 'AiCatalogAgentsDuplicate',
  components: {
    AiCatalogAgentForm,
    PageHeading,
    GlExperimentBadge,
  },
  props: {
    aiCatalogAgent: {
      type: Object,
      required: true,
    },
    version: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      errorMessages: [],
      isSubmitting: false,
    };
  },
  computed: {
    agentName() {
      return this.aiCatalogAgent.name;
    },
    activeVersion() {
      return getByVersionKey(this.aiCatalogAgent, this.version.activeVersionKey);
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
    isThirdPartyFlow() {
      return this.aiCatalogAgent.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    initialValues() {
      return {
        name: `${s__('AICatalog|Copy of')} ${this.agentName}`,
        description: this.aiCatalogAgent.description,
        systemPrompt: this.systemPrompt,
        tools: this.toolIds,
        definition: this.definition,
        public: false,
        type: this.aiCatalogAgent.itemType,
      };
    },
  },
  methods: {
    async handleSubmit({ type, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[type].create;

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
    <page-heading>
      <template #heading>
        <span class="gl-flex">
          {{ s__('AICatalog|Duplicate agent') }}
          <gl-experiment-badge
            :type="isThirdPartyFlow ? 'experiment' : 'beta'"
            class="gl-self-center"
          />
        </span>
      </template>
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Create a copy of this agent with the same configuration.') }}
        </div>
      </template>
    </page-heading>

    <ai-catalog-agent-form
      mode="create"
      :is-loading="isSubmitting"
      :errors="errorMessages"
      :initial-values="initialValues"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
