<script>
import { GlButton, GlCollapsibleListbox, GlModal } from '@gitlab/ui';
import { debounce } from 'lodash';
import { fetchPolicies } from '~/lib/graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import AiCatalogNodeField from './ai_catalog_node_field.vue';

export default {
  components: {
    AiCatalogNodeField,
    GlButton,
    GlCollapsibleListbox,
    GlModal,
  },
  model: {
    prop: 'steps',
    event: 'setSteps',
  },
  props: {
    steps: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    return {
      isAgentModalVisible: false,
      aiCatalogAgents: [],
      selectedAgent: null,
      activeStepIndex: null,
      isAgentsLoading: true,
      searchTerm: '',
    };
  },
  apollo: {
    aiCatalogAgents: {
      query: aiCatalogAgentsQuery,
      variables() {
        return {
          search: this.searchTerm,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) =>
        data.aiCatalogItems.nodes.map((agent) => ({
          value: agent.id,
          text: agent.name,
        })) || [],
      result() {
        this.isAgentsLoading = false;
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogAgents.loading;
    },
    listBoxToggleText() {
      if (this.selectedAgent) {
        return this.selectedAgent.text;
      }
      return s__('AICatalog|Select agent');
    },
    formattedSteps() {
      return this.steps.map((agent) => ({
        value: agent.id,
        text: agent.name,
      }));
    },
  },
  methods: {
    openAgentModal(stepIndex) {
      this.isAgentModalVisible = true;
      this.activeStepIndex = stepIndex;
      this.selectedAgent = this.formattedSteps[stepIndex];
    },
    selectAgent(agentId) {
      this.selectedAgent = this.aiCatalogAgents.find((agent) => agent.value === agentId);
    },
    onSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    confirmAgentModal() {
      let updatedSteps = [];
      const { value: id, text: name } = this.selectedAgent;
      if (this.steps.length <= this.activeStepIndex) {
        updatedSteps = this.steps.concat({ id, name });
      } else {
        updatedSteps = [...this.steps];
        updatedSteps[this.activeStepIndex] = { id, name };
      }
      this.$emit('setSteps', updatedSteps);
      this.activeStepIndex = null;
      this.selectedAgent = null;
    },
    cancelAgentSelection() {
      this.selectedAgent = null;
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-node-field
      v-for="(step, index) in formattedSteps"
      :key="index"
      :selected="step"
      class="gl-mb-3"
      aria-labelledby="flow-edit-steps"
      @primary="openAgentModal(index)"
    />
    <gl-button icon="plus" @click="openAgentModal(steps.length)">
      {{ s__('AICatalog|Flow node') }}
    </gl-button>
    <gl-modal
      v-model="isAgentModalVisible"
      :title="s__('AICatalog|Draft node')"
      modal-id="flow-editor-agent-select"
      @primary="confirmAgentModal"
      @cancel="cancelAgentSelection"
    >
      <label
        id="agent-select-listbox-label"
        class="gl-mt-3 gl-font-bold"
        data-testid="agent-select-listbox-label"
        >{{ s__('AICatalog| Agent') }}</label
      >
      <gl-collapsible-listbox
        block
        searchable
        :items="aiCatalogAgents"
        :toggle-text="listBoxToggleText"
        :loading="isAgentsLoading"
        :searching="isLoading"
        toggle-aria-labelled-by="agent-select-listbox-label"
        @select="selectAgent"
        @search="onSearch"
      />
    </gl-modal>
  </div>
</template>
