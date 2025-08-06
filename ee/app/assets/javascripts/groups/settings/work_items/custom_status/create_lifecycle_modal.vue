<script>
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'CreateLifecycle',
  components: {
    GlModal,
  },
  i18n: {
    createLifecycle: s__('WorkItem|Create lifecycle'),
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
  },
  methods: {
    closeModal() {
      this.$emit('close');
    },
  },
};
</script>

<template>
  <gl-modal
    :visible="visible"
    :title="$options.i18n.createLifecycle"
    scrollable
    modal-id="create-lifecycle-modal"
    @hide="closeModal"
  >
    <!-- TODO: Add lifecycle creation form -->
    {{ $options.i18n.createLifecycle }}
  </gl-modal>
</template>
