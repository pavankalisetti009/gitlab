<script>
import { GlCollapsibleListbox, GlModal } from '@gitlab/ui';
import { debounce } from 'lodash';
import { fetchPolicies } from '~/lib/graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';
import AiCatalogNodeField from './ai_catalog_node_field.vue';

export default {
  components: {
    AiCatalogNodeField,
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
  mounted() {
    if (this.formattedSteps.length > 0) {
      [this.selectedAgent] = this.formattedSteps;
    }
  },
  methods: {
    openAgentModal() {
      this.isAgentModalVisible = true;
    },
    selectAgent(agentId) {
      this.selectedAgent = this.aiCatalogAgents.find((agent) => agent.value === agentId);
      this.$emit('setSteps', [
        {
          id: agentId,
          name: this.selectedAgent.text,
        },
      ]);
    },
    onSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    cancelAgentSelection() {
      this.selectedAgent = null;
    },
  },
};
</script>

<template>
  <div>
    <ai-catalog-node-field
      :selected="selectedAgent"
      aria-labelledby="flow-edit-steps"
      @primary="openAgentModal"
    />
    <gl-modal
      v-model="isAgentModalVisible"
      :title="s__('AICatalog|Draft node')"
      modal-id="flow-editor-agent-select"
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
