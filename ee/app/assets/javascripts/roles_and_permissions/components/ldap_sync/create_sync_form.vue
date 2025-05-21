<script>
import { GlForm, GlButton } from '@gitlab/ui';
import ServerFormGroup from './server_form_group.vue';
import SyncMethodFormGroup, { GROUP_CN, USER_FILTER } from './sync_method_form_group.vue';
import GroupCnFormGroup from './group_cn_form_group.vue';
import UserFilterFormGroup from './user_filter_form_group.vue';

export default {
  components: {
    GlForm,
    GlButton,
    ServerFormGroup,
    SyncMethodFormGroup,
    GroupCnFormGroup,
    UserFilterFormGroup,
  },
  data() {
    return {
      server: null,
      syncMethod: null,
      groupCn: null,
      userFilter: null,
      isValidationEnabled: false,
      isSelectedSyncMethodValidationEnabled: false,
    };
  },
  computed: {
    isServerValid() {
      return !this.isValidationEnabled || Boolean(this.server);
    },
    isSyncMethodValid() {
      return !this.isValidationEnabled || Boolean(this.syncMethod);
    },
    isGroupCnSelected() {
      return this.syncMethod === GROUP_CN;
    },
    isUserFilterSelected() {
      return this.syncMethod === USER_FILTER;
    },
    shouldRunSelectedSyncMethodValidation() {
      // Both validations must be enabled to run the validation for either group cn or user filter, depending on which
      // is selected as the sync method. This fixes an issue where toggling the sync method after submitting the form
      // with errors, will show the new field as invalid even though the user didn't interact with it yet.
      return this.isValidationEnabled && this.isSelectedSyncMethodValidationEnabled;
    },
    isGroupCnValid() {
      return this.shouldRunSelectedSyncMethodValidation && this.isGroupCnSelected
        ? Boolean(this.groupCn)
        : true;
    },
    isUserFilterValid() {
      return this.shouldRunSelectedSyncMethodValidation && this.isUserFilterSelected
        ? Boolean(this.userFilter)
        : true;
    },
  },
  watch: {
    server() {
      // Clear the selected group when the server is changed because the group may not exist on the
      // other server.
      this.groupCn = null;
    },
    syncMethod() {
      this.isSelectedSyncMethodValidationEnabled = false;
    },
  },
  methods: {
    emitFormData() {
      this.isValidationEnabled = true;
      this.isSelectedSyncMethodValidationEnabled = true;

      if (this.isServerValid && (this.isGroupCnValid || this.isUserFilterValid)) {
        this.$emit('submit', {
          server: this.server,
          ...(this.isGroupCnSelected ? { groupCn: this.groupCn } : {}),
          ...(this.isUserFilterSelected ? { userFilter: this.userFilter } : {}),
        });
      }
    },
    updateGroupCn(value) {
      this.isSelectedSyncMethodValidationEnabled = true;
      this.groupCn = value;
    },
    updateUserFilter(value) {
      this.isSelectedSyncMethodValidationEnabled = true;
      this.userFilter = value.trim();
    },
  },
};
</script>

<template>
  <gl-form>
    <server-form-group v-model="server" :state="isServerValid" />
    <sync-method-form-group v-model="syncMethod" :state="isSyncMethodValid" />

    <group-cn-form-group
      v-if="isGroupCnSelected"
      :value="groupCn"
      :state="isGroupCnValid"
      :server="server"
      @input="updateGroupCn"
    />
    <user-filter-form-group
      v-else-if="isUserFilterSelected"
      :value="userFilter"
      :state="isUserFilterValid"
      @input="updateUserFilter"
    />

    <div class="gl-mt-7 gl-flex gl-flex-wrap gl-gap-3">
      <gl-button @click="$emit('cancel')">{{ __('Cancel') }}</gl-button>
      <gl-button variant="confirm" @click="emitFormData">{{ __('Add') }}</gl-button>
    </div>
  </gl-form>
</template>
