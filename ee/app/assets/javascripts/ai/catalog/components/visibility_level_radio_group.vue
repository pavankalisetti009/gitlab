<script>
import { GlAlert, GlFormRadioGroup, GlFormRadio, GlIcon, GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import {
  AI_CATALOG_ITEM_LABELS,
  AI_CATALOG_ITEM_PLURAL_LABELS,
  VISIBILITY_LEVEL_PRIVATE,
  VISIBILITY_LEVEL_PUBLIC,
} from 'ee/ai/catalog/constants';
import HelpPopover from '~/vue_shared/components/help_popover.vue';

export default {
  components: {
    GlAlert,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
    GlSprintf,
    HelpPopover,
  },
  props: {
    id: {
      type: String,
      required: true,
    },
    initialValue: {
      type: Boolean,
      required: true,
    },
    isEditMode: {
      type: Boolean,
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
        Object.keys(texts).every((key) =>
          ['textPrivate', 'textPublic', 'alertTextPrivate', 'alertTextPublic'].includes(key),
        ),
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

  computed: {
    itemTypeLabel() {
      return AI_CATALOG_ITEM_LABELS[this.itemType];
    },
    itemTypePluralLabel() {
      return AI_CATALOG_ITEM_PLURAL_LABELS[this.itemType];
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
    visibilityLevelAlertText() {
      if (this.isEditMode && this.initialValue && this.value === VISIBILITY_LEVEL_PRIVATE) {
        return this.texts.alertTextPublic;
      }

      if (!this.initialValue && this.value === VISIBILITY_LEVEL_PUBLIC) {
        return this.texts.alertTextPrivate;
      }

      return '';
    },
  },
  methods: {
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
  popoverPrivateSections: [
    {
      title: s__('AICatalog|A private %{itemType}:'),
      items: [
        s__('AICatalog|Is visible only to users with at least the Developer role in this project.'),
        s__("AICatalog|Can't be enabled in other projects, or used in public flows."),
        s__("AICatalog|Can't be shared, even within your organization."),
        s__("AICatalog|Can't be made public if enabled in a project."),
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
        s__('AICatalog|Is visible to all users.'),
        s__('AICatalog|Can be enabled in other projects, and used in public flows.'),
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
  <gl-form-radio-group
    :id="id"
    :state="validationState"
    :checked="value"
    @input="(value) => $emit('input', value)"
  >
    <gl-form-radio
      v-for="level in visibilityLevels"
      :key="level.value"
      :value="level.value"
      :state="validationState"
      class="gl-mb-3"
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
    <gl-alert v-if="visibilityLevelAlertText" :dismissible="false" class="gl-mt-3" variant="info">
      {{ visibilityLevelAlertText }}
    </gl-alert>
  </gl-form-radio-group>
</template>
