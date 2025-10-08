<script>
import { GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { s__ } from '~/locale';
import { AI_CATALOG_TYPE_FLOW, AI_CATALOG_TYPE_THIRD_PARTY_FLOW } from 'ee/ai/catalog/constants';

export default {
  name: 'FormFlowType',
  components: {
    GlFormRadio,
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
  },
  computed: {
    flowTypes() {
      return [
        {
          value: AI_CATALOG_TYPE_FLOW,
          text: s__('AICatalog|Flow'),
        },
        {
          value: AI_CATALOG_TYPE_THIRD_PARTY_FLOW,
          text: s__('AICatalog|Third-party flow'),
        },
      ];
    },
  },
};
</script>

<template>
  <div>
    <gl-form-radio-group :id="id" :checked="value" @input="$emit('input', $event)">
      <gl-form-radio v-for="flowType in flowTypes" :key="flowType.value" :value="flowType.value">
        {{ flowType.text }}
      </gl-form-radio>
    </gl-form-radio-group>
  </div>
</template>
