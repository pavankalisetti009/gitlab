<script>
import { GlFormRadioGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';

export default {
  name: 'FormFlowType',
  components: {
    GlFormRadioGroup,
  },
  props: {
    id: {
      type: String,
      required: false,
      default: null,
    },
    value: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  flowTypes: [
    {
      value: AI_CATALOG_TYPE_FLOW,
      text: s__('AICatalog|Flow'),
    },
    {
      value: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
      text: s__('AICatalog|External'),
    },
  ],
};
</script>

<template>
  <gl-form-radio-group
    :id="id"
    :checked="value"
    :options="$options.flowTypes"
    :disabled="disabled"
    @input="$emit('input', $event)"
  />
</template>
