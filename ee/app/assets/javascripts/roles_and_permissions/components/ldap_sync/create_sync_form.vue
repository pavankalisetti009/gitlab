<script>
import { GlForm, GlFormGroup, GlButton, GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlForm,
    GlFormGroup,
    GlButton,
    GlCollapsibleListbox,
  },
  inject: ['ldapServers'],
  data() {
    return {
      server: null,
      isDirty: false,
    };
  },
  computed: {
    isServerValid() {
      return !this.isDirty || Boolean(this.server);
    },
    serverToggleText() {
      // Empty string reverts to the default behavior of showing the selected item's text property.
      return this.server ? '' : s__('LDAP|Select server');
    },
  },
  methods: {
    emitFormData() {
      this.isDirty = true;

      if (this.isServerValid) {
        this.$emit('submit', { server: this.server });
      }
    },
  },
};
</script>

<template>
  <gl-form>
    <gl-form-group
      :label="s__('LDAP|Server')"
      :state="isServerValid"
      :invalid-feedback="__('This field is required')"
    >
      <gl-collapsible-listbox
        v-model="server"
        :items="ldapServers"
        :toggle-text="serverToggleText"
        :variant="isServerValid ? 'default' : 'danger'"
        class="gl-max-w-30"
        category="secondary"
        block
      />
    </gl-form-group>

    <div class="gl-mt-7 gl-flex gl-flex-wrap gl-gap-3">
      <gl-button @click="$emit('cancel')">{{ __('Cancel') }}</gl-button>
      <gl-button variant="confirm" @click="emitFormData">{{ __('Add') }}</gl-button>
    </div>
  </gl-form>
</template>
