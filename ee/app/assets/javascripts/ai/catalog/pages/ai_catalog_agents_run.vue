<script>
import { sprintf, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import AiCatalogAgentRunForm from '../components/ai_catalog_agent_run_form.vue';
import executeAiCatalogAgent from '../graphql/mutations/execute_ai_catalog_agent.mutation.graphql';

export default {
  name: 'AiCatalogAgentsRun',
  components: {
    AiCatalogAgentRunForm,
    ErrorsAlert,
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
    pageTitle() {
      return `${s__('AICatalog|Run agent')}: ${this.aiCatalogAgent.name}`;
    },
  },
  methods: {
    dismissErrors() {
      this.errors = [];
    },
    successAlert({ id, project }) {
      const formattedId = getIdFromGraphQLId(id);

      // Hardcoded for an easier integration with any page at GitLab.
      // https://gitlab.com/gitlab-org/gitlab/-/blob/b50c9e5ad666bab0e45365b2c6994d99407a68d1/ee/app/assets/javascripts/ai/duo_agents_platform/router/index.js#L61
      const link = `/${project.fullPath}/-/automate/agent-sessions/${formattedId}`;

      return {
        message: sprintf(
          s__(
            `AICatalog|Test run executed successfully, see %{linkStart}Session %{formattedId}%{linkEnd}.`,
          ),
          { formattedId },
        ),
        variant: 'success',
        messageLinks: { link },
      };
    },
    async onSubmit({ userPrompt }) {
      try {
        this.dismissErrors();
        this.isSubmitting = true;

        const { data } = await this.$apollo.mutate({
          mutation: executeAiCatalogAgent,
          variables: { input: { agentId: this.aiCatalogAgent.id, userPrompt } },
        });

        if (data) {
          const { errors, workflow } = data.aiCatalogAgentExecute;

          if (errors.length > 0) {
            this.errors = errors;
            return;
          }
          createAlert(this.successAlert(workflow));
        }
      } catch (error) {
        this.errors = [
          sprintf(s__('AICatalog|The test run failed. %{error}'), {
            error: error.message || error.toString(),
          }),
        ];
        Sentry.captureException(error);
      } finally {
        this.isSubmitting = false;
      }
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="pageTitle">
      <template #description>
        <div class="gl-border-b gl-pb-3">
          {{ s__('AICatalog|Test run agents to see how they respond.') }}
        </div>
      </template>
    </page-heading>

    <errors-alert :errors="errors" @dismiss="dismissErrors" />

    <ai-catalog-agent-run-form
      :is-submitting="isSubmitting"
      :ai-catalog-agent="aiCatalogAgent"
      @submit="onSubmit"
    />
  </div>
</template>
