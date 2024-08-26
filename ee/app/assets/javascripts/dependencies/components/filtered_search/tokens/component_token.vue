<script>
import {
  GlIcon,
  GlFilteredSearchToken,
  GlFilteredSearchSuggestion,
  GlLoadingIcon,
  GlIntersperse,
} from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

export default {
  components: {
    GlIcon,
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
    GlLoadingIcon,
    GlIntersperse,
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      searchTerm: '',
      components: [],
      selectedComponents: [],
      isLoadingComponents: true,
    };
  },
  computed: {
    filteredComponents() {
      if (!this.searchTerm) {
        return this.components;
      }

      const nameIncludesSearchTerm = (component) =>
        component.name.toLowerCase().includes(this.searchTerm);
      const isSelected = (component) => this.selectedComponentNames.includes(component.name);

      return this.components.filter(
        (component) => nameIncludesSearchTerm(component) || isSelected(component),
      );
    },
    selectedComponentNames() {
      return this.selectedComponents.map(({ name }) => name);
    },
    selectedComponentIds() {
      return this.selectedComponents.map(({ id }) => getIdFromGraphQLId(id));
    },
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-ui/-/issues/2381
        data: this.active ? null : this.selectedComponentNames,
      };
    },
  },
  created() {
    this.fetchComponents();
  },
  methods: {
    async fetchComponents() {
      try {
        this.isLoadingComponents = true;
        // Note: This is just a placeholder. Adding the actual fetch logic will be addressed in a separate issue:
        // https://gitlab.com/gitlab-org/gitlab/-/issues/442407
        this.components = await new Promise((resolve) => {
          resolve([
            { id: 'gid://gitlab/Component/1', name: 'activerecord' },
            { id: 'gid://gitlab/Component/2', name: 'rails' },
            { id: 'gid://gitlab/Component/3', name: 'rack' },
          ]);
        });
      } catch {
        createAlert({
          message: this.$options.i18n.fetchErrorMessage,
        });
      } finally {
        this.isLoadingComponents = false;
      }
    },
    isComponentSelected(component) {
      return this.selectedComponents.some((c) => c.id === component.id);
    },
    toggleSelectedComponent(component) {
      if (this.isComponentSelected(component)) {
        this.selectedComponents = this.selectedComponents.filter((c) => c.id !== component.id);
      } else {
        this.selectedComponents.push(component);
      }
    },
    handleInput(token) {
      // the dropdown shows a list of component names but we need to emit the components' names for filtering
      this.$emit('input', { ...token, data: this.selectedComponentNames });
    },
    setSearchTerm(token) {
      // the data can be either a string or an array, in which case we don't want to perform the search
      if (typeof token.data === 'string') {
        this.searchTerm = token.data.toLowerCase();
      }
    },
  },
  i18n: {
    fetchErrorMessage: s__(
      'Dependencies|There was an error fetching the components for this group. Please try again later.',
    ),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedComponentNames"
    :value="tokenValue"
    v-on="{ ...$listeners, input: handleInput }"
    @select="toggleSelectedComponent"
    @input="setSearchTerm"
  >
    <template #view>
      <gl-intersperse data-testid="selected-components">
        <span
          v-for="selectedComponentName in selectedComponentNames"
          :key="selectedComponentName"
          >{{ selectedComponentName }}</span
        >
      </gl-intersperse>
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoadingComponents" size="sm" />
      <template v-else>
        <gl-filtered-search-suggestion
          v-for="component in filteredComponents"
          :key="component.id"
          :value="component"
        >
          <div class="gl-flex gl-items-center">
            <gl-icon
              v-if="config.multiSelect"
              name="check"
              class="gl-mr-3 gl-shrink-0 gl-text-gray-700"
              :class="{
                'gl-invisible': !selectedComponentNames.includes(component.name),
              }"
            />
            {{ component.name }}
          </div>
        </gl-filtered-search-suggestion>
      </template>
    </template>
  </gl-filtered-search-token>
</template>
