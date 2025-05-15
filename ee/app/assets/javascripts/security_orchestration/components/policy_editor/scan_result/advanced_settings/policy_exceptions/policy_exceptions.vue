<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import PolicyExceptionsModal from './policy_exceptions_modal.vue';

export default {
  i18n: {
    addButtonText: s__('ScanResultPolicy|Add exception'),
    title: s__('ScanResultPolicy|Policy Exception settings'),
  },
  name: 'PolicyExceptions',
  components: {
    GlButton,
    PolicyExceptionsModal,
  },
  methods: {
    showModal() {
      this.$refs.modal.showModalWindow();
    },
  },
};
</script>

<template>
  <div>
    <h4>{{ $options.i18n.title }}</h4>

    <policy-exceptions-modal ref="modal" />

    <div class="security-policies-bg-subtle gl-w-full gl-rounded-base gl-px-2 gl-py-3">
      <gl-button icon="plus" category="tertiary" variant="confirm" size="small" @click="showModal">
        {{ $options.i18n.addButtonText }}
      </gl-button>
    </div>
  </div>
</template>
