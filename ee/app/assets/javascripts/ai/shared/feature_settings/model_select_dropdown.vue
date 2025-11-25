<script>
import {
  GlBadge,
  GlButton,
  GlCollapsibleListbox,
  GlExperimentBadge,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { GITLAB_DEFAULT_MODEL } from 'ee/ai/model_selection/constants';
import { RELEASE_STATES } from './constants';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlBadge,
    GlButton,
    GlCollapsibleListbox,
    GlExperimentBadge,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    selectedOption: {
      type: Object,
      required: false,
      default: null,
    },
    items: {
      type: Array,
      required: true,
    },
    placeholderDropdownText: {
      type: String,
      required: false,
      default: '',
    },
    buttonClass: {
      type: String,
      required: false,
      default: '',
    },
    headerText: {
      type: String,
      required: false,
      default: '',
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    selected() {
      return this.selectedOption?.value || GITLAB_DEFAULT_MODEL;
    },
    dropdownToggleText() {
      return this.selectedOption?.text || this.placeholderDropdownText;
    },
  },
  methods: {
    isGitLabManagedModel(model) {
      return model && model.provider;
    },
    isBetaModel(model) {
      return model?.releaseState === RELEASE_STATES.BETA;
    },
    onSelect(option) {
      this.$emit('select', option);
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    :selected="selected"
    data-testid="model-dropdown-selector"
    :items="items"
    :header-text="headerText"
    :loading="isLoading"
    fluid-width
    category="primary"
    block
    @select="onSelect"
  >
    <template #toggle>
      <gl-button
        data-testid="toggle-button"
        :class="buttonClass"
        :disabled="disabled"
        :loading="isLoading"
        :text="dropdownToggleText"
        :aria-label="dropdownToggleText"
        block
      >
        <template #emoji>
          <div data-testid="dropdown-toggle-text" class="gl-flex gl-w-full gl-justify-between">
            <div class="gl-align-items gl-flex gl-overflow-hidden">
              <gl-experiment-badge
                v-if="isBetaModel(selectedOption)"
                data-testid="beta-model-selected-badge"
                class="!gl-ml-0 gl-mr-3"
                type="beta"
              />
              <span class="gl-overflow-hidden gl-text-ellipsis">{{ dropdownToggleText }}</span>
            </div>
            <div>
              <gl-icon name="chevron-down" />
            </div>
          </div>
        </template>
      </gl-button>
    </template>

    <template #list-item="{ item }">
      <div class="gl-flex gl-max-w-34 gl-items-center gl-justify-between">
        <span class="gl-mr-4 gl-flex gl-flex-col">
          <span
            v-if="item.provider"
            data-testid="model-provider"
            class="gl-text-sm gl-font-semibold gl-text-secondary"
          >
            {{ item.provider }}
          </span>
          <span
            data-testid="model-name"
            :class="{ 'gl-whitespace-nowrap gl-font-bold': isGitLabManagedModel(item) }"
          >
            {{ item.text }}
          </span>
          <span v-if="item.description" data-testid="model-description" class="gl-text-secondary">
            {{ item.description }}
          </span>
        </span>
        <gl-badge
          v-if="isBetaModel(item)"
          data-testid="beta-model-dropdown-badge"
          variant="neutral"
        >
          {{ __('Beta') }}
        </gl-badge>
      </div>
    </template>

    <template #footer>
      <slot name="footer"></slot>
    </template>
  </gl-collapsible-listbox>
</template>
