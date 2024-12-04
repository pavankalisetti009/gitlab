<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  EXCEPTION_KEY,
  EXCEPTION_TYPE_ITEMS,
  NO_EXCEPTION_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';

export default {
  EXCEPTION_TYPE_ITEMS: [
    {
      value: EXCEPTION_KEY,
      text: s__('SecurityOrchestration|Except'),
    },
    {
      value: NO_EXCEPTION_KEY,
      text: s__('SecurityOrchestration|No exceptions'),
    },
  ],
  name: 'DenyAllowListExceptions',
  components: {
    GlCollapsibleListbox,
  },
  props: {
    exceptionType: {
      type: String,
      required: false,
      default: NO_EXCEPTION_KEY,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    toggleText() {
      return EXCEPTION_TYPE_ITEMS.find(({ value }) => value === this.exceptionType).text;
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      size="small"
      :items="$options.EXCEPTION_TYPE_ITEMS"
      :toggle-text="toggleText"
      :selected="exceptionType"
      @select="$emit('select-exception-type', $event)"
    />
  </div>
</template>
