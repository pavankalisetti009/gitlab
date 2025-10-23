<script>
import {
  GlBadge,
  GlButton,
  GlCollapsibleListbox,
  GlExperimentBadge,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__ } from '~/locale';
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
    withDefaultModelTooltip: {
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
    defaultModelTooltipText() {
      return this.withDefaultModelTooltip ? s__('AdminAIPoweredFeatures|GitLab default model') : '';
    },
  },
  methods: {
    isBetaModel(model) {
      return model?.releaseState === RELEASE_STATES.BETA;
    },
    isDefaultModel(model) {
      return model?.value === GITLAB_DEFAULT_MODEL;
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
    :fluid_width="true"
    category="primary"
    block
    @select="onSelect"
  >
    <template #toggle>
      <gl-button
        data-testid="toggle-button"
        :disabled="disabled"
        :loading="isLoading"
        :text="dropdownToggleText"
        :aria-label="dropdownToggleText"
        block
      >
        <template #emoji>
          <div data-testid="dropdown-toggle-text" class="gl-flex gl-w-full gl-justify-between">
            <div class="gl-align-items gl-flex gl-overflow-hidden">
              <gl-badge
                v-if="isDefaultModel(selectedOption)"
                v-gl-tooltip
                :title="defaultModelTooltipText"
                data-testid="default-model-selected-badge"
                class="!gl-ml-0 gl-mr-3"
                variant="info"
                icon="tanuki"
                icon-size="sm"
              />
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
      <div class="gl-flex gl-items-center gl-justify-between">
        {{ item.text }}
        <gl-badge
          v-if="isDefaultModel(item)"
          v-gl-tooltip
          :title="defaultModelTooltipText"
          data-testid="default-model-dropdown-badge"
          variant="info"
          icon="tanuki"
        />
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
