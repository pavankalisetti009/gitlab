<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import CodeBlockHighlighted from '~/vue_shared/components/code_block_highlighted.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import AiCatalogAgentRunForm from '../components/ai_catalog_agent_run_form.vue';
import executeAiCatalogAgent from '../graphql/mutations/execute_ai_catalog_agent.mutation.graphql';

export default {
  name: 'AiCatalogAgentsRun',
  components: {
    PageHeading,
    AiCatalogAgentRunForm,
    ClipboardButton,
    CodeBlockHighlighted,
  },
  props: {
    aiCatalogAgent: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      isSubmitting: false,
      flowConfig: null,
    };
  },
  computed: {
    pageTitle() {
      return `${s__('AICatalog|Run agent')}: ${this.aiCatalogAgent.name}`;
    },
  },
  methods: {
    async onSubmit() {
      try {
        this.isSubmitting = true;

        const { data } = await this.$apollo.mutate({
          mutation: executeAiCatalogAgent,
          variables: { input: { agentId: this.aiCatalogAgent.id } },
        });

        if (data) {
          this.flowConfig = data.aiCatalogAgentExecute.flowConfig;
          this.$toast.show(s__('AICatalog|Agent executed successfully.'));
        }
      } catch (error) {
        this.$toast.show(s__('AICatalog|Failed to execute agent.'));
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

    <ai-catalog-agent-run-form
      :is-submitting="isSubmitting"
      :ai-catalog-agent="aiCatalogAgent"
      @submit="onSubmit"
    />

    <div v-if="flowConfig" class="gl-relative">
      <code-block-highlighted class="gl-border gl-mt-4 gl-p-4" :code="flowConfig" language="yaml" />

      <clipboard-button
        :text="flowConfig"
        :title="s__('AICatalog|Copy flow config')"
        category="tertiary"
        class="gl-absolute gl-right-0 gl-top-0 gl-m-3 gl-hidden md:gl-flex"
      />
    </div>
  </div>
</template>
