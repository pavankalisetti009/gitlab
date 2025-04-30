<script>
import { GlButton, GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';
import { __ } from '~/locale';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import ldapAdminRoleLinksQuery from '../../graphql/ldap_sync/ldap_admin_role_links.query.graphql';
import ldapAdminRoleLinkDestroyMutation from '../../graphql/ldap_sync/ldap_admin_role_link_destroy.mutation.graphql';

export default {
  components: {
    CrudComponent,
    GlButton,
    GlAlert,
    GlSprintf,
    GlLink,
    ConfirmActionModal,
  },
  data() {
    return {
      ldapAdminRoleLinks: [],
      linkToDelete: null,
    };
  },
  apollo: {
    ldapAdminRoleLinks: {
      query: ldapAdminRoleLinksQuery,
      update(data) {
        return data.ldapAdminRoleLinks.nodes;
      },
      error() {
        this.ldapAdminRoleLinks = null;
      },
    },
  },
  computed: {
    isRoleLinksLoading() {
      return this.$apollo.queries.ldapAdminRoleLinks.loading;
    },
    roleLinksCount() {
      return this.ldapAdminRoleLinks.length;
    },
  },
  methods: {
    getTimeAgo(timestamp) {
      return timestamp ? getTimeago().format(timestamp) : __('Never');
    },
    async deleteLink() {
      const response = await this.$apollo.mutate({
        mutation: ldapAdminRoleLinkDestroyMutation,
        variables: { id: this.linkToDelete.id },
      });

      const error = response.data.ldapAdminRoleLinkDestroy.errors[0];
      if (error) {
        return Promise.reject(error);
      }

      this.$apollo.queries.ldapAdminRoleLinks.refetch();
      return Promise.resolve();
    },
  },
};
</script>

<template>
  <gl-alert v-if="!ldapAdminRoleLinks" variant="danger" :dismissible="false">{{
    s__('MemberRole|Could not load LDAP synchronizations. Please refresh the page to try again.')
  }}</gl-alert>

  <crud-component
    v-else
    :title="s__('LDAP|Active synchronizations')"
    :description="s__('MemberRole|Automatically sync your LDAP directory to custom admin roles.')"
    :count="roleLinksCount"
    :is-loading="isRoleLinksLoading"
  >
    <template v-if="!isRoleLinksLoading" #actions>
      <div class="gl-flex gl-flex-wrap">
        <gl-link v-if="roleLinksCount" class="gl-my-3 gl-mr-4">
          {{ s__('MemberRole|View LDAP synced users') }}
        </gl-link>

        <div class="gl-flex gl-flex-wrap gl-gap-3">
          <gl-button v-if="roleLinksCount" icon="retry">{{ s__('MemberRole|Sync all') }}</gl-button>
          <gl-button variant="confirm">{{ s__('LDAP|Add synchronization') }}</gl-button>
        </div>
      </div>

      <confirm-action-modal
        v-if="linkToDelete"
        modal-id="remove-ldap-sync-modal"
        :title="s__('MemberRole|Remove LDAP synchronization')"
        :action-text="s__('MemberRole|Remove sync')"
        variant="confirm"
        :action-fn="deleteLink"
        @close="linkToDelete = null"
      >
        <gl-sprintf
          :message="
            s__(
              'MemberRole|This removes automatic syncing with your LDAP server. Users will keep their current role but future changes will require manual updates. %{confirmStart}Are you sure you want to remove LDAP synchronization?%{confirmEnd}',
            )
          "
        >
          <template #confirm="{ content }">
            <p class="gl-mb-0 gl-mt-4">{{ content }}</p>
          </template>
        </gl-sprintf>
      </confirm-action-modal>
    </template>

    <ul v-if="ldapAdminRoleLinks.length" class="content-list">
      <li v-for="link in ldapAdminRoleLinks" :key="link.id" class="!gl-py-5">
        <div class="gl-flex gl-flex-wrap gl-items-center gl-justify-end gl-gap-5">
          <dl
            class="gl-mb-0 gl-grid gl-flex-1 gl-grid-cols-[auto_1fr] gl-gap-x-5 gl-whitespace-nowrap"
          >
            <dt>{{ s__('MemberRole|Server:') }}</dt>
            <dd class="gl-text-subtle">{{ link.provider.label }}</dd>

            <template v-if="link.filter">
              <dt>{{ s__('MemberRole|User filter:') }}</dt>
              <dd class="gl-text-subtle">{{ link.filter }}</dd>
            </template>

            <template v-else-if="link.cn">
              <dt>{{ s__('MemberRole|Group cn:') }}</dt>
              <dd class="gl-text-subtle">{{ link.cn }}</dd>
            </template>

            <dt>{{ s__('MemberRole|Custom admin role:') }}</dt>
            <dd class="gl-mb-0 gl-text-subtle">{{ link.adminMemberRole.name }}</dd>
          </dl>

          <div class="gl-flex gl-flex-col gl-items-end gl-gap-3">
            <gl-button
              variant="danger"
              category="secondary"
              icon="remove"
              :aria-label="s__('MemberRole|Remove sync')"
              @click="linkToDelete = link"
            />
            <span class="gl-text-subtle">
              <gl-sprintf :message="s__('Geo|Last synced: %{timeAgo}')">
                <template #timeAgo>{{ getTimeAgo(link.lastSyncedAt) }}</template>
              </gl-sprintf>
            </span>
          </div>
        </div>
      </li>
    </ul>

    <div v-else class="gl-text-center gl-text-sm gl-text-subtle">
      {{
        s__(
          'MemberRole|No active LDAP synchronizations. Add synchronization to connect your LDAP directory with custom admin roles.',
        )
      }}
    </div>
  </crud-component>
</template>
