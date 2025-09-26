<script>
import { GlAlert, GlLink, GlSprintf } from '@gitlab/ui';
import { sprintf, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import AiCatalogAgentRunForm from '../components/ai_catalog_agent_run_form.vue';
import executeAiCatalogAgent from '../graphql/mutations/execute_ai_catalog_agent.mutation.graphql';

export default {
  name: 'AiCatalogAgentsRun',
  components: {
    AiCatalogAgentRunForm,
    ErrorsAlert,
    GlAlert,
    GlLink,
    GlSprintf,
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
      workflow: null,
    };
  },
  computed: {
    pageTitle() {
      return `${s__('AICatalog|Run agent')}: ${this.aiCatalogAgent.name}`;
    },
    workflowId() {
      return this.workflow ? getIdFromGraphQLId(this.workflow.id) : null;
    },
    workflowLink() {
      // Hardcoded for an easier integration with any page at GitLab.
      // https://gitlab.com/gitlab-org/gitlab/-/blob/b50c9e5ad666bab0e45365b2c6994d99407a68d1/ee/app/assets/javascripts/ai/duo_agents_platform/router/index.js#L61
      return this.workflow
        ? `/${this.workflow.project.fullPath}/-/automate/agent-sessions/${this.workflowId}`
        : '';
    },
  },
  methods: {
    dismissErrors() {
      this.errors = [];
    },
    resetWorkflow() {
      this.workflow = null;
    },
    async onSubmit({ userPrompt }) {
      try {
        this.dismissErrors();
        this.resetWorkflow();
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
          this.workflow = workflow;
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

    <gl-alert
      v-if="workflow"
      :key="workflow.id"
      class="gl-mb-5"
      data-testid="success-alert"
      variant="success"
      @dismiss="resetWorkflow"
    >
      <gl-sprintf
        :message="
          s__(
            `AICatalog|Test run executed successfully, see %{linkStart}Session %{workflowId}%{linkEnd}.`,
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="workflowLink">
            <gl-sprintf :message="content">
              <template #workflowId>{{ workflowId }}</template>
            </gl-sprintf>
          </gl-link>
        </template>
      </gl-sprintf>
    </gl-alert>

    <ai-catalog-agent-run-form
      :is-submitting="isSubmitting"
      :ai-catalog-agent="aiCatalogAgent"
      @submit="onSubmit"
    />
  </div>
</template>
