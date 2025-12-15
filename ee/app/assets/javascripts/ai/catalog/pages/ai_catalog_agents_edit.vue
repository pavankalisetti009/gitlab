<script>
import { GlExperimentBadge, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { AI_CATALOG_ITEM_TYPE_APOLLO_CONFIG, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from '../constants';
import {
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
} from '../router/constants';
import AiCatalogAgentForm from '../components/ai_catalog_agent_form.vue';

export default {
  name: 'AiCatalogAgentsEdit',
  components: {
    AiCatalogAgentForm,
    PageHeading,
    GlExperimentBadge,
    GlAlert,
    GlSprintf,
    GlLink,
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
      errors: [],
      isSubmitting: false,
    };
  },
  computed: {
    // We compute whether to show the "editing latest version" warning because editing a pinned version would result in version content
    // becoming mis-aligned with the version numbers.
    shouldShowEditingLatestAlert() {
      return this.version.isUpdateAvailable;
    },
    systemPrompt() {
      return this.aiCatalogAgent.latestVersion.systemPrompt;
    },
    toolIds() {
      return (this.aiCatalogAgent.latestVersion.tools?.nodes ?? []).map((t) => t.id);
    },
    definition() {
      return this.aiCatalogAgent.latestVersion.definition;
    },
    isThirdPartyFlow() {
      return this.aiCatalogAgent.itemType === AI_CATALOG_TYPE_THIRD_PARTY_FLOW;
    },
    duplicateLink() {
      return {
        name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
        params: { id: this.$route.params.id },
      };
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
    <page-heading>
      <template #heading>
        <span class="gl-flex">
          {{ s__('AICatalog|Edit agent') }}
          <gl-experiment-badge
            :type="isThirdPartyFlow ? 'experiment' : 'beta'"
            class="gl-self-center"
          />
        </span>
      </template>
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Manage agent settings.') }}
        </div>
      </template>
    </page-heading>
    <gl-alert
      v-if="shouldShowEditingLatestAlert"
      :dismissible="false"
      variant="warning"
      class="gl-my-6"
    >
      <gl-sprintf
        :message="
          s__(
            'AICatalog|To prevent versioning issues, you can edit only the latest version of this agent. To edit an earlier version, %{linkStart}duplicate the agent%{linkEnd}.',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :to="duplicateLink">{{ content }}</gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>
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
