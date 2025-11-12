<script>
import { GlExperimentBadge } from '@gitlab/ui';
import emptyStateIllustrationPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-pipeline-md.svg?url';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { fetchPolicies } from '~/lib/graphql';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import getProjectAiFlowTriggers from 'ee/ai/duo_agents_platform/graphql/queries/get_ai_flow_triggers.query.graphql';
import deleteAiFlowTrigger from 'ee/ai/duo_agents_platform/graphql/mutations/delete_ai_flow_trigger.mutation.graphql';
import FlowTriggersCta from './components/flow_triggers_cta.vue';
import FlowTriggersTable from './components/flow_triggers_table.vue';

export default {
  name: 'FlowTriggersIndex',
  components: {
    ConfirmActionModal,
    FlowTriggersCta,
    FlowTriggersTable,
    GlExperimentBadge,
    PageHeading,
    ResourceListsEmptyState,
    ResourceListsLoadingStateList,
  },
  inject: ['projectPath', 'flowTriggersEventTypeOptions'],
  data() {
    return {
      aiFlowTriggers: [],
      idToBeDeleted: null,
    };
  },
  apollo: {
    aiFlowTriggers: {
      query: getProjectAiFlowTriggers,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project.aiFlowTriggers.nodes,
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch flow triggers'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiFlowTriggers.loading;
    },
    showEmptyState() {
      return !this.isLoading && this.aiFlowTriggers.length === 0;
    },
  },
  methods: {
    async deleteAiFlowTrigger() {
      try {
        await this.$apollo.mutate({
          mutation: deleteAiFlowTrigger,
          variables: {
            id: this.idToBeDeleted,
          },
          refetchQueries: [getProjectAiFlowTriggers],
        });

        this.$toast.show(s__('DuoAgentsPlatform|Flow trigger deleted successfully.'));
      } catch (error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to delete flow trigger.'),
        });
      } finally {
        this.resetItemIdToBeDeleted();
      }
    },
    resetItemIdToBeDeleted() {
      this.idToBeDeleted = null;
    },
  },
  emptyStateIllustrationPath,
};
</script>

<template>
  <div>
    <page-heading>
      <template #heading>
        <div class="gl-flex">
          <span>{{ s__('DuoAgentsPlatform|Triggers') }}</span>
          <gl-experiment-badge type="beta" class="gl-self-center" />
        </div>
      </template>
      <template #description>
        {{ s__('DuoAgentsPlatform|Manage automated flows within your project.') }}
      </template>
      <template #actions>
        <flow-triggers-cta />
      </template>
    </page-heading>
    <resource-lists-loading-state-list
      v-if="isLoading"
      :left-lines-count="1"
      :right-lines-count="1"
    />
    <resource-lists-empty-state
      v-else-if="showEmptyState"
      :title="s__('DuoAgentsPlatform|No flow triggers yet')"
      :description="
        s__(
          'DuoAgentsPlatform|Create flow triggers to automatically run pipelines when specified events occur in your project.',
        )
      "
      :svg-path="$options.emptyStateIllustrationPath"
    >
      <template #actions>
        <slot name="actions">
          <flow-triggers-cta />
        </slot>
      </template>
    </resource-lists-empty-state>
    <template v-else>
      <flow-triggers-table
        :ai-flow-triggers="aiFlowTriggers"
        :event-type-options="flowTriggersEventTypeOptions"
        class="gl-mt-8"
        @delete-trigger="(id) => (idToBeDeleted = id)"
      />
      <confirm-action-modal
        v-if="idToBeDeleted"
        modal-id="delete-item-modal"
        variant="danger"
        :title="s__('DuoAgentsPlatform|Delete flow trigger')"
        :action-fn="deleteAiFlowTrigger"
        :action-text="__('Delete')"
        @close="resetItemIdToBeDeleted"
      >
        {{
          s__(
            'DuoAgentsPlatform|Are you sure you want to delete this flow trigger? This action cannot be undone.',
          )
        }}
      </confirm-action-modal>
    </template>
  </div>
</template>
