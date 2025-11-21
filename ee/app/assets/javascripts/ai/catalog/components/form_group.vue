<script>
import { GlFormGroup } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';

export default {
  name: 'FormGroup',
  components: {
    GlFormGroup,
  },
  props: {
    field: {
      type: Object,
      required: true,
    },
    fieldValue: {
      type: [String, Number, Array],
      required: false,
      default: null,
    },
  },
  data() {
    return {
      state: true,
      invalidFeedback: null,
    };
  },
  methods: {
    validate() {
      const { requiredLabel, maxLength } = this.field.validations;
      if (requiredLabel) {
        this.state = Boolean(this.fieldValue);
        this.invalidFeedback = requiredLabel;
      }
      if (maxLength && this.fieldValue?.length > maxLength) {
        this.state = this.fieldValue?.length <= maxLength;
        this.invalidFeedback = sprintf(s__('AICatalog|Input cannot exceed %{value} characters.'), {
          value: maxLength,
        });
      }
      return this.state;
    },
    onBlur() {
      this.validate();
    },
  },
};
</script>

<template>
  <gl-form-group
    v-bind="field.groupAttrs"
    :label="field.label"
    :label-for="field.id"
    :invalid-feedback="invalidFeedback"
    :state="state"
    class="gl-mb-0"
  >
    <slot :state="state" :blur="onBlur"></slot>
  </gl-form-group>
</template>
