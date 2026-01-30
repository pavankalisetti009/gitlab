<script>
import { GlAlert, GlFormRadioGroup, GlFormRadio, GlIcon, GlModal, GlSprintf } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import {
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import HelpPopover from '~/vue_shared/components/help_popover.vue';
import {
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_ITEM_PLURAL_LABELS,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';

export default {
  name: 'VisibilityLevelRadioGroup',
  components: {
    GlAlert,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlModal,
    GlSprintf,
    HelpPopover,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
    itemType: {
      type: String,
      required: true,
    },
    texts: {
      type: Object,
      required: true,
      validator: (texts) =>
        Object.keys(texts).every((key) => ['textPrivate', 'textPublic'].includes(key)),
    },
    validationState: {
      type: Object,
      required: false,
      default: null,
    },
    value: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      showConfirmModal: false,
    };
  },
  computed: {
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.itemType];
    },
    itemTypePluralLabel() {
      return AI_CATALOG_ITEM_PLURAL_LABELS[this.itemType];
    },
    modalTitle() {
      return sprintf(s__('AICatalog|Make %{itemType} public?'), { itemType: this.itemTypeLabel });
    },
    modalSections() {
      return [this.$options.popoverPublicSections[0], this.$options.popoverPublicSections[1]];
    },
    modalWarning() {
      return this.$options.popoverPublicSections[2].text;
    },
    visibilityLevels() {
      return [
        {
          value: VISIBILITY_LEVEL_PRIVATE,
          label: VISIBILITY_LEVEL_LABELS[VISIBILITY_LEVEL_PRIVATE_STRING],
          text: this.texts.textPrivate,
          icon: VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PRIVATE_STRING],
        },
        {
          value: VISIBILITY_LEVEL_PUBLIC,
          label: VISIBILITY_LEVEL_LABELS[VISIBILITY_LEVEL_PUBLIC_STRING],
          text: this.texts.textPublic,
          icon: VISIBILITY_TYPE_ICON[VISIBILITY_LEVEL_PUBLIC_STRING],
        },
      ];
    },
  },
  methods: {
    handleInput(newValue) {
      this.$emit('input', newValue);
      if (newValue === VISIBILITY_LEVEL_PUBLIC && this.value !== VISIBILITY_LEVEL_PUBLIC) {
        this.showConfirmModal = true;
      }
    },
    confirmPublicVisibility() {
      this.showConfirmModal = false;
    },
    cancelPublicVisibility() {
      this.showConfirmModal = false;
      this.$emit('input', VISIBILITY_LEVEL_PRIVATE);
    },
    popoverOptions(level) {
      return { title: `${level.label} ${this.itemTypeLabel}` };
    },
    popoverSections(level) {
      if (level.value === VISIBILITY_LEVEL_PRIVATE) {
        return this.$options.popoverPrivateSections;
      }
      return this.$options.popoverPublicSections;
    },
  },
  actionPrimary: {
    text: s__('AICatalog|Make public'),
  },
  actionCancel: {
    text: __('Cancel'),
  },
  popoverPrivateSections: [
    {
      title: s__('AICatalog|A private %{itemType}:'),
      items: [
        s__(
          'AICatalog|Is visible only to users with at least the Developer role for this project, and to users with the Owner role for the top-level group.',
        ),
        s__("AICatalog|Can't be enabled in other projects."),
        s__("AICatalog|Can't be shared, even within your organization."),
      ],
    },
    {
      title: s__('AICatalog|Private %{itemTypePlural} are best for:'),
      items: [
        s__('AICatalog|Project-specific automation.'),
        s__('AICatalog|Working with sensitive data.'),
        s__('AICatalog|Creating proprietary business logic.'),
      ],
    },
  ],
  popoverPublicSections: [
    {
      title: s__('AICatalog|A public %{itemType}:'),
      items: [
        s__('AICatalog|Is visible to everyone, including users outside your organization.'),
        s__('AICatalog|Can be enabled in other projects.'),
        s__("AICatalog|Can't be made private if enabled in a project."),
      ],
    },
    {
      title: s__('AICatalog|Public %{itemTypePlural} are best for:'),
      items: [
        s__('AICatalog|Community contributions.'),
        s__('AICatalog|Open source projects.'),
        s__('AICatalog|Shared resources.'),
      ],
    },
    {
      text: s__(
        "AICatalog|Anyone can see your prompts and settings. Don't include sensitive data or reference internal systems.",
      ),
    },
  ],
};
</script>

<template>
  <div>
    <gl-form-radio-group
      :id="id"
      :checked="value"
      :state="validationState"
      class="gl-flex gl-flex-col gl-gap-3"
      @input="handleInput"
    >
      <gl-form-radio
        v-for="level in visibilityLevels"
        :key="level.value"
        :value="level.value"
        :state="validationState"
      >
        <div class="gl-flex gl-items-center gl-gap-2">
          <gl-icon :size="16" :name="level.icon" />
          <span class="gl-font-semibold">
            {{ level.label }}
          </span>
        </div>
        <template #help>
          {{ level.text }}
          <help-popover
            icon="information-o"
            trigger-class="gl-align-top"
            :options="popoverOptions(level)"
          >
            <div v-for="section in popoverSections(level)" :key="section.title">
              <strong v-if="section.title">
                <gl-sprintf :message="section.title">
                  <template #itemType>{{ itemTypeLabel }}</template>
                  <template #itemTypePlural>{{ itemTypePluralLabel }}</template>
                </gl-sprintf>
              </strong>
              <ul v-if="section.items" class="gl-pl-5">
                <li v-for="item in section.items" :key="item">
                  {{ item }}
                </li>
              </ul>
              <span v-if="section.text">
                {{ section.text }}
              </span>
            </div>
          </help-popover>
        </template>
      </gl-form-radio>
    </gl-form-radio-group>

    <gl-modal
      v-if="showConfirmModal"
      visible
      modal-id="visibility-public-confirm-modal"
      :title="modalTitle"
      :action-primary="$options.actionPrimary"
      :action-cancel="$options.actionCancel"
      @primary="confirmPublicVisibility"
      @hidden="cancelPublicVisibility"
    >
      <div v-for="section in modalSections" :key="section.title" class="gl-mb-4">
        <p class="gl-mb-2">
          <strong>
            <gl-sprintf :message="section.title">
              <template #itemType>{{ itemTypeLabel }}</template>
              <template #itemTypePlural>{{ itemTypePluralLabel }}</template>
            </gl-sprintf>
          </strong>
        </p>
        <ul class="gl-mb-0">
          <li v-for="item in section.items" :key="item">
            {{ item }}
          </li>
        </ul>
      </div>
      <gl-alert variant="warning" :dismissible="false" class="gl-mb-0">
        {{ modalWarning }}
      </gl-alert>
    </gl-modal>
  </div>
</template>
