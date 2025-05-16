<script>
import { GlForm, GlButton } from '@gitlab/ui';
import ServerFormGroup from './server_form_group.vue';

export default {
  components: {
    GlForm,
    GlButton,
    ServerFormGroup,
  },
  data() {
    return {
      server: null,
      isValidationEnabled: false,
    };
  },
  computed: {
    isServerValid() {
      return !this.isValidationEnabled || Boolean(this.server);
    },
  },
  methods: {
    emitFormData() {
      this.isValidationEnabled = true;

      if (this.isServerValid) {
        this.$emit('submit', { server: this.server });
      }
    },
  },
};
</script>

<template>
  <gl-form>
    <server-form-group v-model="server" :state="isServerValid" />

    <div class="gl-mt-7 gl-flex gl-flex-wrap gl-gap-3">
      <gl-button @click="$emit('cancel')">{{ __('Cancel') }}</gl-button>
      <gl-button variant="confirm" @click="emitFormData">{{ __('Add') }}</gl-button>
    </div>
  </gl-form>
</template>
