<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { TYPENAME_AI_FLOW_TRIGGER } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import updateAiFlowTriggerMutation from '../../graphql/mutations/update_ai_flow_trigger.mutation.graphql';
import getAiFlowTriggersQuery from '../../graphql/queries/get_ai_flow_triggers.query.graphql';
import FlowTriggerForm from './components/flow_trigger_form.vue';

export default {
  name: 'FlowTriggersEdit',
  components: {
    FlowTriggerForm,
    GlEmptyState,
    GlLoadingIcon,
    PageHeading,
  },
  inject: ['flowTriggersEventTypeOptions', 'projectPath', 'projectId'],
  data() {
    return {
      flowTrigger: {},
      errorMessages: [],
      isLoadingMutation: false,
    };
  },
  apollo: {
    flowTrigger: {
      query: getAiFlowTriggersQuery,
      variables() {
        return {
          projectPath: this.projectPath,
          ids: [this.flowTriggerGraphQlId],
        };
      },
      update(data) {
        const flowTrigger = data.project?.aiFlowTriggers?.nodes[0];
        return flowTrigger
          ? {
              description: flowTrigger.description,
              eventTypes: flowTrigger.eventTypes,
              user: flowTrigger.user,
              configPath: flowTrigger.configPath,
              aiCatalogItemConsumer: {
                id: flowTrigger?.aiCatalogItemConsumer?.id,
                name: flowTrigger?.aiCatalogItemConsumer?.item.name,
              },
            }
          : {};
      },
      error(error) {
        createAlert({
          message: error.message,
          captureError: true,
        });
      },
    },
  },
  computed: {
    isQueryLoading() {
      return this.$apollo.queries.flowTrigger.loading;
    },
    flowTriggerGraphQlId() {
      return convertToGraphQLId(TYPENAME_AI_FLOW_TRIGGER, this.$route.params.id);
    },
    isNotFound() {
      return this.flowTrigger && Object.keys(this.flowTrigger).length === 0;
    },
  },
  methods: {
    async updateAiFlowTrigger(input) {
      this.resetErrorMessages();
      this.isLoadingMutation = true;

      try {
        const {
          data: {
            aiFlowTriggerUpdate: { errors },
          },
        } = await this.$apollo.mutate({
          mutation: updateAiFlowTriggerMutation,
          variables: {
            input: {
              ...input,
              id: this.flowTriggerGraphQlId,
            },
          },
        });

        if (errors.length > 0) {
          this.errorMessages = errors;
          return;
        }

        this.$toast.show(s__('DuoAgentsPlatform|Flow trigger updated successfully.'));
        this.$router.go(-1);
      } catch (error) {
        this.errorMessages = [
          error.message ||
            s__('DuoAgentsPlatform|The flow trigger could not be updated. Try again.'),
        ];
      } finally {
        this.isLoadingMutation = false;
      }
    },
    resetErrorMessages() {
      this.errorMessages = [];
    },
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <page-heading :heading="s__('DuoAgentsPlatform|Edit flow trigger')">
      <template #description>
        {{ s__('DuoAgentsPlatform|Edit flow trigger.') }}
      </template>
    </page-heading>
    <gl-loading-icon v-if="isQueryLoading" size="lg" class="gl-my-5" />
    <gl-empty-state
      v-else-if="isNotFound"
      :title="s__('DuoAgentsPlatform|Flow trigger not found.')"
      :svg-path="$options.emptySearchSvg"
    />
    <flow-trigger-form
      v-else
      :event-type-options="flowTriggersEventTypeOptions"
      :error-messages="errorMessages"
      :project-path="projectPath"
      :project-id="projectId"
      :is-loading="isLoadingMutation"
      :initial-values="flowTrigger"
      mode="edit"
      @dismiss-errors="resetErrorMessages"
      @submit="updateAiFlowTrigger"
    />
  </div>
</template>
