<script>
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG } from '../constants';
import { AI_CATALOG_AGENTS_SHOW_ROUTE } from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsEdit',
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
      errors: [],
      isSubmitting: false,
    };
  },
  computed: {
    // Default to latest version in EDIT mode because editing a pinned version would result in non-linear versions
    // being produced. Instead, we will enforce that the user update the agent before being allowed to edit.
    systemPrompt() {
      return this.aiCatalogAgent.latestVersion.systemPrompt;
    },
    toolIds() {
      return (this.aiCatalogAgent.latestVersion.tools?.nodes ?? []).map((t) => t.id);
    },
    definition() {
      return this.aiCatalogAgent.latestVersion.definition;
    },
    initialValues() {
      return {
        projectId: this.aiCatalogAgent.project?.id,
        name: this.aiCatalogAgent.name,
        description: this.aiCatalogAgent.description,
        systemPrompt: this.systemPrompt,
        tools: this.toolIds,
        definition: this.definition,
        public: this.aiCatalogAgent.public,
        type: this.aiCatalogAgent.itemType,
      };
    },
  },
  methods: {
    async handleSubmit({ type, ...input }) {
      this.isSubmitting = true;
      this.resetErrorMessages();
      const config = AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG[type].update;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: config.mutation,
          variables: {
            input: {
              ...input,
              id: this.aiCatalogAgent.id,
            },
          },
        });

        if (data) {
          const { errors } = data[config.responseKey];
          if (errors.length > 0) {
            this.errors = errors;
            return;
          }

          this.$toast.show(s__('AICatalog|Agent updated.'));
          this.$router.push({
            name: AI_CATALOG_AGENTS_SHOW_ROUTE,
            params: { id: this.$route.params.id },
          });
        }
      } catch (error) {
        this.errors = [s__('AICatalog|Could not update agent. Try again.')];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
    resetErrorMessages() {
      this.errors = [];
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Edit agent')">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Manage agent settings.') }}
        </div>
      </template>
    </page-heading>
    <ai-catalog-agent-form
      mode="edit"
      :errors="errors"
      :initial-values="initialValues"
      :is-loading="isSubmitting"
      @dismiss-errors="resetErrorMessages"
      @submit="handleSubmit"
    />
  </div>
</template>
