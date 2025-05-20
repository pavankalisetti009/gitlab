<script>
import { GlForm, GlButton } from '@gitlab/ui';
import ServerFormGroup from './server_form_group.vue';
import SyncMethodFormGroup, { USER_FILTER } from './sync_method_form_group.vue';
import UserFilterFormGroup from './user_filter_form_group.vue';

export default {
  components: {
    GlForm,
    GlButton,
    ServerFormGroup,
    SyncMethodFormGroup,
    UserFilterFormGroup,
  },
  data() {
    return {
      server: null,
      syncMethod: null,
      userFilter: null,
      isValidationEnabled: false,
    };
  },
  computed: {
    isServerValid() {
      return !this.isValidationEnabled || Boolean(this.server);
    },
    isSyncMethodValid() {
      return !this.isValidationEnabled || Boolean(this.syncMethod);
    },
    isUserFilterValid() {
      return !this.isValidationEnabled || Boolean(this.userFilter);
    },
  },
  methods: {
    emitFormData() {
      this.isValidationEnabled = true;

      if (this.isServerValid && this.isUserFilterValid) {
        this.$emit('submit', {
          server: this.server,
          userFilter: this.userFilter,
        });
      }
    },
  },
  USER_FILTER,
};
</script>

<template>
  <gl-form>
    <server-form-group v-model="server" :state="isServerValid" />
    <sync-method-form-group v-model="syncMethod" :state="isSyncMethodValid" />

    <user-filter-form-group
      v-if="syncMethod === $options.USER_FILTER"
      v-model.trim="userFilter"
      :state="isUserFilterValid"
    />

    <div class="gl-mt-7 gl-flex gl-flex-wrap gl-gap-3">
      <gl-button @click="$emit('cancel')">{{ __('Cancel') }}</gl-button>
      <gl-button variant="confirm" @click="emitFormData">{{ __('Add') }}</gl-button>
    </div>
  </gl-form>
</template>
