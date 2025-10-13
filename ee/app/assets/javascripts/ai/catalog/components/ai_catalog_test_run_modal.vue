<script>
import { GlAlert, GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { sprintf, s__, __ } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

import { FORM_ID_TEST_RUN } from 'ee/ai/catalog/constants';
import executeAiCatalogAgent from '../graphql/mutations/execute_ai_catalog_agent.mutation.graphql';
import AiCatalogAgentRunForm from './ai_catalog_agent_run_form.vue';

export default {
  name: 'AiCatalogTestRunModal',
  components: {
    AiCatalogAgentRunForm,
    ErrorsAlert,
    GlAlert,
    GlLink,
    GlModal,
    GlSprintf,
  },
  props: {
    item: {
      type: Object,
      required: true,
    },
    open: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isOpen: this.open,
      errors: [],
      isSubmitting: false,
      workflow: null,
    };
  },
  computed: {
    title() {
      return `${s__('AICatalog|Test run agent')}: ${this.item.name}`;
    },
    workflowId() {
      return this.workflow ? getIdFromGraphQLId(this.workflow.id) : null;
    },
    workflowLink() {
      // Hardcoded for an easier integration with any page at GitLab. // https://gitlab.com/gitlab-org/gitlab/-/blob/b50c9e5ad666bab0e45365b2c6994d99407a68d1/ee/app/assets/javascripts/ai/duo_agents_platform/router/index.js#L61
      return this.workflow
        ? `/${this.workflow.project.fullPath}/-/automate/agent-sessions/${this.workflowId}`
        : '';
    },
    actionPrimary() {
      return {
        text: __('Run'),
        attributes: {
          icon: 'play',
          variant: 'confirm',
          type: 'submit',
          loading: this.isSubmitting,
          form: FORM_ID_TEST_RUN,
        },
      };
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
          variables: { input: { agentId: this.item.id, userPrompt } },
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
  modal: {
    actionSecondary: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <gl-modal
    v-model="isOpen"
    modal-id="ai-catalog-test-run-modal"
    :title="title"
    :action-primary="actionPrimary"
    :action-secondary="$options.modal.actionSecondary"
    @primary.prevent
    @hidden="$emit('hide')"
  >
    <div class="gl-mb-5 gl-pb-3 gl-text-subtle">
      {{ s__('AICatalog|Create a session that uses this agent.') }}
    </div>

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
    <ai-catalog-agent-run-form @submit="onSubmit" />
  </gl-modal>
</template>

<style scoped>
#ai-catalog-test-run-modal .modal-header {
  border-bottom: 1px #dcdcde solid;
  border-style: solid;
}
</style>
