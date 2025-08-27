<script>
import { GlAlert, GlFormRadioGroup, GlFormRadio, GlIcon } from '@gitlab/ui';
import {
  VISIBILITY_LEVEL_LABELS,
  VISIBILITY_TYPE_ICON,
  VISIBILITY_LEVEL_PUBLIC_STRING,
  VISIBILITY_LEVEL_PRIVATE_STRING,
} from '~/visibility_level/constants';
import { VISIBILITY_LEVEL_PRIVATE, VISIBILITY_LEVEL_PUBLIC } from 'ee/ai/catalog/constants';

export default {
  components: {
    GlAlert,
    GlFormRadioGroup,
    GlFormRadio,
    GlIcon,
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
      <template #help>{{ level.text }}</template>
    </gl-form-radio>
    <gl-alert v-if="visibilityLevelAlertText" :dismissible="false" class="gl-mt-3" variant="info">
      {{ visibilityLevelAlertText }}
    </gl-alert>
  </gl-form-radio-group>
</template>
