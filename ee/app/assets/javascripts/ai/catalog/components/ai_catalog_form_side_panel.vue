<script>
import { GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { debounce } from 'lodash';
import { fetchPolicies } from '~/lib/graphql';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { s__ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import aiCatalogAgentsQuery from '../graphql/queries/ai_catalog_agents.query.graphql';

export default {
  components: {
    GlButton,
    GlCollapsibleListbox,
  },
  mixins: [glFeatureFlagsMixin()],
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
    isFlowPublic: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      aiCatalogAgents: [],
      selectedAgent: null,
      selectedVersion: null,
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
          versions: agent.versions,
          public: agent.public,
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
    agentOptions() {
      if (this.isFlowPublic) {
        return this.aiCatalogAgents.filter((a) => a.public === true);
      }
      return this.aiCatalogAgents;
    },
    agentListBoxToggleText() {
      if (this.selectedAgent) {
        return this.selectedAgent.text;
      }
      return s__('AICatalog|Select agent');
    },
    versionListBoxToggleText() {
      if (this.selectedVersion) {
        return this.selectedVersion.text;
      }
      return s__('AICatalog|Always use latest version');
    },
    formattedSteps() {
      return this.steps.map((agent) => ({
        value: agent.id,
        text: agent.name,
        versions: agent.versions,
        versionName: agent.versionName,
      }));
    },
    versionOptions() {
      return (
        this.selectedAgent?.versions?.nodes.map((version) => ({
          value: version.id,
          text: version.versionName,
        })) || []
      );
    },
  },
  watch: {
    activeStepIndex: {
      handler() {
        this.selectedAgent = this.formattedSteps[this.activeStepIndex] || null;
        this.selectedVersion =
          this.versionOptions.find((version) => version.text === this.selectedAgent?.versionName) ||
          null;
      },
      immediate: true,
    },
  },
  methods: {
    selectAgent(agentId) {
      this.selectedAgent = this.agentOptions.find((agent) => agent.value === agentId);
      this.selectedVersion = null;
    },
    selectVersion(versionId) {
      this.selectedVersion = this.versionOptions.find((version) => version.value === versionId);
    },
    onSearch: debounce(function debouncedSearch(searchTerm) {
      this.searchTerm = searchTerm;
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    onSubmit() {
      let updatedSteps = [];
      const { value: id, text: name, versions } = this.selectedAgent;
      const versionName = this.selectedVersion?.text || this.versionOptions[0]?.text;
      if (this.steps.length <= this.activeStepIndex) {
        updatedSteps = this.steps.concat({ id, name, versionName, versions });
      } else {
        updatedSteps = [...this.steps];
        updatedSteps[this.activeStepIndex] = { id, name, versionName, versions };
      }
      this.$emit('setSteps', updatedSteps);

      this.onClose();
    },
    onDelete() {
      const updatedSteps = [
        ...this.steps.slice(0, this.activeStepIndex),
        ...this.steps.slice(this.activeStepIndex + 1),
      ];
      this.$emit('setSteps', updatedSteps);
      this.onClose();
    },
    onClose() {
      this.selectedAgent = null;
      this.selectedVersion = null;
      this.$emit('close');
    },
  },
};
</script>

<template>
  <div class="gl-border gl-flex gl-flex-col gl-justify-between gl-rounded-base gl-bg-subtle">
    <div class="gl-p-4">
      <label
        for="agent-select-listbox"
        class="gl-mt-3 gl-font-bold"
        data-testid="agent-select-listbox-label"
      >
        {{ s__('AICatalog| Agent') }}
        <div v-if="isFlowPublic" class="gl-mt-3 gl-font-normal gl-text-subtle">
          {{ s__('AICatalog|Only public agents can be used in public flows.') }}
        </div>
      </label>
      <gl-collapsible-listbox
        block
        searchable
        :items="agentOptions"
        :toggle-text="agentListBoxToggleText"
        :loading="isAgentsLoading"
        :searching="isLoading"
        toggle-id="agent-select-listbox"
        data-testid="agent-select-listbox"
        @select="selectAgent"
        @search="onSearch"
      />
      <div v-if="glFeatures.aiCatalogEnforceReadonlyVersions">
        <label for="version-select-listbox" class="gl-mt-3 gl-font-bold">
          {{ s__('AICatalog|Version') }}
        </label>
        <gl-collapsible-listbox
          block
          :items="versionOptions"
          :toggle-text="versionListBoxToggleText"
          :loading="isAgentsLoading"
          :disabled="selectedAgent === null"
          toggle-id="version-select-listbox"
          data-testid="version-select-listbox"
          @select="selectVersion"
        />
      </div>
    </div>
    <div class="gl-border-t gl-flex gl-justify-between gl-gap-3 gl-p-4">
      <div>
        <gl-button variant="confirm" @click="onSubmit">
          {{ __('Save') }}
        </gl-button>
        <gl-button data-testid="agent-select-cancel-button" @click="onClose">
          {{ __('Cancel') }}
        </gl-button>
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
