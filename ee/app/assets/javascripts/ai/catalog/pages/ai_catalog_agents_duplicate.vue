<script>
import { s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { helpPagePath } from '~/helpers/help_page_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createAiCatalogAgent from '../graphql/mutations/create_ai_catalog_agent.mutation.graphql';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsDuplicate',
  components: {
    AiCatalogAgentForm,
    PageHeading,
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
    };
  },
  computed: {
    agentName() {
      return this.aiCatalogAgent.name;
    },
    initialValues() {
      return {
        name: `${s__('AICatalog|Copy of')} ${this.agentName}`,
        description: this.aiCatalogAgent.description,
        systemPrompt: this.aiCatalogAgent.latestVersion?.systemPrompt,
        tools: this.aiCatalogAgent.latestVersion?.tools?.nodes.map((t) => t.id) || [],
        public: false,
        release: true,
      };
    },
  },
  methods: {
    async handleSubmit(input) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      try {
        const { data } = await this.$apollo.mutate({
          mutation: createAiCatalogAgent,
          variables: {
            input,
          },
        });

        if (data) {
          const { errors } = data.aiCatalogAgentCreate;
          if (errors.length > 0) {
            this.errorMessages = errors;
            return;
          }

          const newAgentId = getIdFromGraphQLId(data.aiCatalogAgentCreate.item.id);
          this.$toast.show(s__('AICatalog|Agent created.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: newAgentId },
          });
        }
      } catch (error) {
        this.errorMessages = [
          sprintf(
            s__(
              'AICatalog|Could not create agent in the project. Check that the project meets the %{link_start}prerequisites%{link_end} and try again.',
            ),
            {
              link_start: `<a href="${helpPagePath('user/duo_agent_platform/ai_catalog', {
                anchor: 'view-the-ai-catalog',
              })}" target="_blank">`,
              link_end: '</a>',
            },
            false,
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
    <page-heading :heading="s__('AICatalog|Duplicate agent')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Duplicate this agent with all its settings and configuration.') }}
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
