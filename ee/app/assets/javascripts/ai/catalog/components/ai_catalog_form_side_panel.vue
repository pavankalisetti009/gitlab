<script>
import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import { fetchPolicies } from '~/lib/graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';

export default {
  components: {
    GlButton,
    GlCollapsibleListbox,
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
    activeStepIndex: {
      type: Number,
      required: false,
      default: null,
    },
  },
  data() {
    return {
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
    agentListBoxToggleText() {
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
  watch: {
    activeStepIndex() {
      this.selectedAgent = this.formattedSteps[this.activeStepIndex] || null;
    },
  },
  created() {
    if (this.activeStepIndex !== null) {
      this.selectedAgent = this.formattedSteps[this.activeStepIndex] || null;
    }
  },
  methods: {
    selectAgent(agentId) {
      this.selectedAgent = this.aiCatalogAgents.find((agent) => agent.value === agentId);
    },
    onSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onSubmit() {
      let updatedSteps = [];
      const { value: id, text: name } = this.selectedAgent;
      if (this.steps.length <= this.activeStepIndex) {
        updatedSteps = this.steps.concat({ id, name });
      } else {
        updatedSteps = [...this.steps];
        updatedSteps[this.activeStepIndex] = { id, name };
      }
      this.$emit('setSteps', updatedSteps);

      this.selectedAgent = null;
      this.$emit('close');
    },
    onDelete() {
      const updatedSteps = [
        ...this.steps.slice(0, this.activeStepIndex),
        ...this.steps.slice(this.activeStepIndex + 1),
      ];
      this.$emit('setSteps', updatedSteps);
      this.selectedAgent = null;
      this.$emit('close');
    },
    onCancel() {
      this.selectedAgent = null;
      this.$emit('close');
    },
  },
};
</script>

<template>
  <div class="gl-border gl-flex gl-flex-col gl-justify-between">
    <div class="gl-p-4">
      <label for="agent-select-listbox-label" class="gl-mt-3 gl-font-bold">
        {{ s__('AICatalog| Agent') }}
      </label>
      <gl-collapsible-listbox
        block
        searchable
        :items="aiCatalogAgents"
        :toggle-text="agentListBoxToggleText"
        :loading="isAgentsLoading"
        :searching="isLoading"
        toggle-id="agent-select-listbox-label"
        @select="selectAgent"
        @search="onSearch"
      />
    </div>
    <div class="gl-border-t gl-flex gl-justify-between gl-gap-3 gl-p-4">
      <div>
        <gl-button variant="confirm" @click="onSubmit">
          {{ __('Save') }}
        </gl-button>
        <gl-button data-testid="agent-select-cancel-button" @click="onCancel">{{
          __('Cancel')
        }}</gl-button>
      </div>
      <gl-button
        category="tertiary"
        variant="danger"
        data-testid="agent-node-delete-button"
        @click="onDelete"
      >
        {{ s__('AICatalog|Delete node') }}
      </gl-button>
    </div>
  </div>
</template>
