<script>
import {
  GlAvatarLabeled,
  GlCollapsibleListbox,
  GlFormCheckbox,
  GlDatepicker,
  GlForm,
  GlFormGroup,
  GlFormInput,
  GlModal,
} from '@gitlab/ui';
import { debounce } from 'lodash';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { createAlert } from '~/alert';
import { formatGraphQLError } from 'ee/ci/secrets/utils';
import { getDateInFuture, toISODateFormat } from '~/lib/utils/datetime_utility';
import { fetchGroupMembers, fetchUsers } from '~/vue_shared/components/list_selector/api';
import {
  ACCESS_LEVEL_NO_ACCESS_INTEGER,
  ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
  ACCESS_LEVEL_GUEST_INTEGER,
  ACCESS_LEVEL_PLANNER_INTEGER,
  ACCESS_LEVEL_OWNER_INTEGER,
  BASE_ROLES,
} from '~/access_level/constants';
import { __, s__ } from '~/locale';
import { CONFIG, GROUPS_TYPE, USERS_TYPE } from '~/vue_shared/components/list_selector/constants';
import { ENTITY_GROUP, ENTITY_PROJECT } from 'ee/ci/secrets/constants';
import { SECRETS_MANAGER_CONTEXT_CONFIG } from '../context_config';
import {
  PERMISSION_CATEGORY_GROUP,
  PERMISSION_CATEGORY_ROLE,
  PERMISSION_CATEGORY_USER,
} from '../constants';

export default {
  name: 'SecretsManagerPermissionsModal',
  components: {
    GlAvatarLabeled,
    GlCollapsibleListbox,
    GlFormCheckbox,
    GlDatepicker,
    GlForm,
    GlFormGroup,
    GlFormInput,
    GlModal,
  },
  props: {
    permissionCategory: {
      type: String,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: true,
    },
    context: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      expiration: null,
      groupPath: '',
      isListboxLoading: false,
      isSubmitting: false,
      listboxItems: [],
      principal: null,
      actions: {
        read: false,
        write: false,
        delete: false,
      },
      selectedListboxItem: '',
    };
  },
  computed: {
    contextConfig() {
      return SECRETS_MANAGER_CONTEXT_CONFIG[this.context];
    },
    isCategoryUser() {
      return this.permissionCategory === PERMISSION_CATEGORY_USER;
    },
    isCategoryGroup() {
      return this.permissionCategory === PERMISSION_CATEGORY_GROUP;
    },
    isCategoryRole() {
      return this.permissionCategory === PERMISSION_CATEGORY_ROLE;
    },
    isSubmittable() {
      const hasPrincipal = this.isCategoryGroup ? this.groupPath.trim() : this.principal !== null;
      return hasPrincipal && this.selectedActions.length > 0;
    },
    listboxTitle() {
      if (this.isCategoryUser) {
        return __('Username or name');
      }
      return __('Group');
    },
    listboxToggleText() {
      if (!this.principal) {
        return __('Select');
      }

      if (this.isCategoryUser) {
        return this.principal.name;
      }

      return this.principal.text;
    },
    minExpirationDate() {
      const today = new Date();
      return getDateInFuture(today, 1);
    },
    modalOptions() {
      return {
        actionPrimary: {
          text: __('Add'),
          attributes: {
            disabled: !this.isSubmittable,
            loading: this.isSubmitting,
            variant: 'confirm',
          },
        },
        actionSecondary: {
          text: __('Cancel'),
          attributes: {
            variant: 'default',
          },
        },
      };
    },
    modalTitle() {
      if (this.isCategoryUser) {
        return __('Add user');
      }

      if (this.isCategoryGroup) {
        return __('Add group');
      }

      return __('Add role');
    },
    rolesList() {
      const excludedRoles = [
        ACCESS_LEVEL_NO_ACCESS_INTEGER,
        ACCESS_LEVEL_MINIMAL_ACCESS_INTEGER,
        ACCESS_LEVEL_GUEST_INTEGER,
        ACCESS_LEVEL_PLANNER_INTEGER,
        ACCESS_LEVEL_OWNER_INTEGER,
      ];

      return BASE_ROLES.filter((role) => !excludedRoles.includes(role.accessLevel));
    },
    selectedActions() {
      return Object.keys(this.actions)
        .filter((action) => this.actions[action])
        .map((action) => action.toUpperCase());
    },
  },
  methods: {
    async createPermission() {
      this.isSubmitting = true;

      try {
        const principal = {
          type: this.permissionCategory,
        };

        if (this.isCategoryRole) {
          principal.id = this.principal.accessLevel;
        } else if (this.isCategoryGroup) {
          principal.groupPath = this.groupPath;
        } else {
          principal.id = this.principal.id;
        }

        const { data } = await this.$apollo.mutate({
          mutation: this.contextConfig.mutations.createPermission,
          variables: {
            fullPath: this.fullPath,
            principal,
            actions: this.selectedActions,
            expiredAt: this.expiration ? toISODateFormat(this.expiration) : null,
          },
        });

        const error = data?.secretsPermissionUpdate?.errors[0];
        if (error) {
          createAlert({ message: error });
          return;
        }

        this.$emit('refetch');
        this.$toast.show(
          s__('SecretsManagerPermissions|Secrets manager permissions were successfully updated.'),
        );
      } catch (e) {
        createAlert({
          message: formatGraphQLError(
            e.message,
            s__(
              'SecretsManagerPermissions|Failed to create secrets manager permission. Please try again.',
            ),
          ),
          captureError: true,
          error: e,
        });
      } finally {
        this.hideModal();
        this.isSubmitting = false;
      }
    },
    debouncedSearchListbox: debounce(function debouncedSearch(search) {
      this.searchListbox(search);
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS),
    async searchListbox(search) {
      try {
        this.isListboxLoading = true;
        if (this.isCategoryUser) {
          if (this.context === ENTITY_PROJECT) {
            this.listboxItems = await fetchUsers(this.fullPath, search);
          } else if (this.context === ENTITY_GROUP) {
            this.listboxItems = await fetchGroupMembers(this.fullPath, false, search);
          }
        }
      } catch (e) {
        createAlert({
          message: __('An error occurred while fetching. Please try again.'),
          captureError: true,
          error: e,
        });
      } finally {
        this.isListboxLoading = false;
      }
    },
    selectListboxItem(listboxItem) {
      this.selectedListboxItem = listboxItem;
      const sourceList = this.isCategoryRole ? this.rolesList : this.listboxItems;
      [this.principal] = sourceList.filter((item) => item.value === listboxItem);
    },
    hideModal() {
      this.listboxItems = [];
      this.principal = null;
      this.expiration = null;
      this.groupPath = '';
      this.selectedListboxItem = '';
      this.actions = {
        read: false,
        write: false,
        delete: false,
      };

      this.$emit('hide');
    },
  },
  datePlaceholder: 'YYYY-MM-DD',
  GROUP_LISTBOX: CONFIG[GROUPS_TYPE],
  USERS_LISTBOX: CONFIG[USERS_TYPE],
};
</script>

<template>
  <gl-modal
    :visible="permissionCategory !== null"
    :title="modalTitle"
    :action-primary="modalOptions.actionPrimary"
    :action-secondary="modalOptions.actionSecondary"
    modal-id="secrets-manager-permissions-modal"
    @primary.prevent="createPermission"
    @secondary="hideModal"
    @canceled="hideModal"
    @hidden="hideModal"
  >
    <gl-form>
      <gl-form-group
        v-if="isCategoryUser"
        label-for="secret-permission-principal"
        :label="listboxTitle"
      >
        <gl-collapsible-listbox
          id="secret-permission-principal"
          :items="listboxItems"
          :selected="selectedListboxItem"
          :toggle-text="listboxToggleText"
          :search-placeholder="__('Search users...')"
          :searching="isListboxLoading"
          searchable
          block
          fluid-width
          is-check-centered
          @select="selectListboxItem"
          @search="debouncedSearchListbox"
          @shown="searchListbox"
        >
          <template #list-item="{ item }">
            <gl-avatar-labeled
              :label="item.name"
              :sub-label="item.username"
              :src="item.avatarUrl"
              :entity-name="item.name"
              :size="32"
            />
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
      <gl-form-group
        v-else-if="isCategoryGroup"
        label-for="secret-permission-group-path"
        :label="__('Group path')"
      >
        <gl-form-input
          id="secret-permission-group-path"
          v-model="groupPath"
          :placeholder="
            s__('SecretsManagerPermissions|For example, my-group or my-group/sub-group')
          "
        />
      </gl-form-group>
      <gl-form-group
        v-else-if="isCategoryRole"
        label-for="secret-permission-principal"
        :label="__('Role')"
      >
        <gl-collapsible-listbox
          id="secret-permission-principal"
          :items="rolesList"
          :selected="selectedListboxItem"
          :toggle-text="listboxToggleText"
          block
          fluid-width
          is-check-centered
          @select="selectListboxItem"
        />
      </gl-form-group>
      <gl-form-group label-for="secret-permission-expiration" :label="__('Access expiration date')">
        <gl-datepicker
          id="secret-expiration"
          v-model="expiration"
          optional
          :placeholder="$options.datePlaceholder"
          :min-date="minExpirationDate"
        />
      </gl-form-group>
      <gl-form-group
        :label="__('Scopes')"
        :label-description="
          s__(
            'SecretsManagerPermissions|Select the access scopes to grant to this user for the secrets manager and related API endpoints.',
          )
        "
      >
        <gl-form-checkbox v-model="actions.read" class="-gl-mb-4">
          {{ __('Read') }}
          <p class="gl-text-subtle">
            {{
              s__(
                'SecretsManagerPermissions|Can authenticate with the secrets manager and related API endpoints.',
              )
            }}
            {{
              s__('SecretsManagerPermissions|Can read secret metadata but not the secret value.')
            }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="actions.write" class="-gl-mb-4" :disabled="!actions.read">
          {{ __('Write') }}
          <p class="gl-text-subtle">
            {{ s__('SecretsManagerPermissions|Can create and update secrets.') }}
          </p>
        </gl-form-checkbox>
        <gl-form-checkbox v-model="actions.delete" class="-gl-mb-4" :disabled="!actions.read">
          {{ __('Delete') }}
          <p class="gl-text-subtle">
            {{ s__('SecretsManagerPermissions|Can permanently delete secrets.') }}
          </p>
        </gl-form-checkbox>
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
