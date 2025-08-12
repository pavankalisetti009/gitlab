<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import createAiFlowTriggerMutation from '../../graphql/mutations/create_ai_flow_trigger.mutation.graphql';
import { FLOW_TRIGGERS_INDEX_ROUTE } from '../../router/constants';
import FlowTriggerForm from './components/flow_trigger_form.vue';

export default {
  name: 'FlowTriggersNew',
  components: {
    FlowTriggerForm,
    PageHeading,
  },
  inject: ['flowTriggersEventTypeOptions', 'projectPath'],
  data() {
    return {
      errorMessages: [],
      isLoading: false,
    };
  },
  methods: {
    async createAiFlowTrigger(input) {
      this.resetErrorMessages();
      this.isLoading = true;

      try {
        const {
          data: {
            aiFlowTriggerCreate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: createAiFlowTriggerMutation,
          variables: {
            input: {
              ...input,
              projectPath: this.projectPath,
            },
          },
        });

        if (errors.length > 0) {
          this.errorMessages = errors;
          return;
        }
        this.$toast.show(s__('DuoAgentsPlatform|Flow trigger created successfully.'));
        this.$router.push({
          name: FLOW_TRIGGERS_INDEX_ROUTE,
        });
      } catch (error) {
        this.errorMessages = [
          error.message ||
            s__('DuoAgentsPlatform|The flow trigger could not be created. Try again.'),
        ];
      } finally {
        this.isLoading = false;
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
    <page-heading :heading="s__('DuoAgentsPlatform|New flow trigger')">
      <template #description>
        {{ s__('DuoAgentsPlatform|Create a new flow trigger.') }}
      </template>
    </page-heading>
    <flow-trigger-form
      :event-type-options="flowTriggersEventTypeOptions"
      :error-messages="errorMessages"
      :project-path="projectPath"
      :is-loading="isLoading"
      mode="create"
      @dismiss-errors="resetErrorMessages"
      @submit="createAiFlowTrigger"
    />
  </div>
</template>
