<script>
import {
  GlTable,
  GlButtonGroup,
  GlButton,
  GlIcon,
  GlTooltipDirective,
  GlAlert,
  GlLink,
  GlToast,
  GlLoadingIcon,
} from '@gitlab/ui';
import Vue from 'vue';
import { __ } from '~/locale';
import {
  SCAN_PROFILE_TYPE_SECRET_DETECTION,
  SCAN_PROFILE_CATEGORIES,
  SCAN_PROFILE_I18N,
} from '~/security_configuration/constants';
import availableProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import projectProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/project_security_scan_profiles.query.graphql';
import attachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import detachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import DisableScanProfileConfirmationModal from './disable_scan_profile_confirmation_modal.vue';
import ScanProfileDetailsModal from './scan_profile_details_modal.vue';
import InsufficientPermissionsPopover from './insufficient_permissions_popover.vue';
import ScanProfileLaunchModal from './scan_profile_launch_modal.vue';

Vue.use(GlToast);

export default {
  name: 'ScanProfileConfiguration',
  components: {
    GlTable,
    GlButtonGroup,
    GlButton,
    GlIcon,
    GlAlert,
    GlLink,
    GlLoadingIcon,
    DisableScanProfileConfirmationModal,
    ScanProfileDetailsModal,
    InsufficientPermissionsPopover,
    ScanProfileLaunchModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['projectFullPath', 'groupFullPath', 'canApplyProfiles'],
  SCAN_PROFILE_I18N,
  apollo: {
    availableProfiles: {
      query: availableProfilesQuery,
      variables() {
        return { fullPath: this.groupFullPath, type: SCAN_PROFILE_TYPE_SECRET_DETECTION };
      },
      update: (data) => {
        const profiles = data?.group?.availableSecurityScanProfiles || [];
        return profiles;
      },
      error() {
        this.showError(SCAN_PROFILE_I18N.errorLoadingProfiles);
      },
    },
    attachedProfiles: {
      query: projectProfilesQuery,
      variables() {
        return { fullPath: this.projectFullPath };
      },
      update: (data) => data?.project?.securityScanProfiles || [],
      result({ data, error }) {
        if (!error && data) {
          this.projectId = data?.project?.id;
        }
      },
      error() {
        this.showError(SCAN_PROFILE_I18N.errorLoadingProfiles);
      },
    },
  },
  data() {
    return {
      projectId: null,
      isSubmitting: false,
      errorMessage: null,
      previewProfileId: '',
      previewModalVisible: false,
      disableModalVisible: false,
      disablingScanType: null,
      availableProfiles: [],
      attachedProfiles: [],
      showOnlyRecommended: true,
    };
  },
  computed: {
    isLoading() {
      return (
        this.$apollo.queries.availableProfiles.loading ||
        this.$apollo.queries.attachedProfiles.loading
      );
    },
    getScannerMetadata() {
      return (scanType) => SCAN_PROFILE_CATEGORIES[scanType] || {};
    },
    isProfileAttached() {
      return (profileId) => {
        return this.attachedProfiles.some((p) => p.id === profileId);
      };
    },
    getAttachedProfileForScanType() {
      return (scanType) => {
        return this.attachedProfiles.find((p) => p.scanType === scanType);
      };
    },
    tableItems() {
      let profiles = this.availableProfiles;

      if (this.showOnlyRecommended) {
        profiles = profiles.filter((p) => p.gitlabRecommended);
      }

      return profiles.map((profile) => {
        const isConfigured = this.isProfileAttached(profile.id);
        return {
          id: profile.id,
          name: profile.name,
          description: profile.description,
          scanType: profile.scanType,
          gitlabRecommended: profile.gitlabRecommended,
          isConfigured,
          lastScan: null,
        };
      });
    },
    tableFields() {
      return [
        { key: 'scanType', label: __('Scanner') },
        { key: 'name', label: __('Profile'), tdClass: '!gl-align-middle' },
        { key: 'status', label: __('Status'), tdClass: '!gl-align-middle' },
        { key: 'lastScan', label: __('Last scan'), tdClass: '!gl-align-middle' },
        { key: 'actions', label: '' },
      ];
    },
  },
  methods: {
    showError(message) {
      this.errorMessage = message;
      setTimeout(() => {
        this.errorMessage = null;
      }, 5000);
    },
    showToast(message) {
      this.$toast.show(message);
    },
    getButtonId(item) {
      return item.isConfigured ? `disable-button-${item.id}` : `apply-button-${item.id}`;
    },
    async applyProfile(profileId) {
      if (!this.projectId || !profileId) return;

      this.isSubmitting = true;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: attachMutation,
          variables: {
            input: {
              securityScanProfileId: profileId,
              projectIds: [this.projectId],
            },
          },
          refetchQueries: [
            {
              query: projectProfilesQuery,
              variables: { fullPath: this.projectFullPath },
            },
          ],
        });

        const mutationErrors = data?.securityScanProfileAttach?.errors;
        if (mutationErrors?.length) {
          this.showError(mutationErrors.join(', '));
        } else {
          this.showToast(SCAN_PROFILE_I18N.successApplying);
          if (this.previewModalVisible) {
            this.closePreview();
          }
        }
      } catch (error) {
        this.showError(SCAN_PROFILE_I18N.errorApplying);
      } finally {
        this.isSubmitting = false;
      }
    },
    openDisableModal(scanType) {
      this.disablingScanType = scanType;
      this.disableModalVisible = true;
    },
    async detachProfile() {
      const attachedProfile = this.getAttachedProfileForScanType(this.disablingScanType);
      if (!attachedProfile || !this.projectId) return;

      this.disableModalVisible = false;
      this.isSubmitting = true;
      this.errorMessage = null;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: detachMutation,
          variables: {
            input: {
              securityScanProfileId: attachedProfile.id,
              projectIds: [this.projectId],
            },
          },
          refetchQueries: [
            {
              query: projectProfilesQuery,
              variables: { fullPath: this.projectFullPath },
            },
          ],
        });

        const mutationErrors = data?.securityScanProfileDetach?.errors;
        if (mutationErrors?.length) {
          this.showError(mutationErrors.join(', '));
        } else {
          this.showToast(SCAN_PROFILE_I18N.successDetaching);
        }
      } catch (error) {
        this.showError(SCAN_PROFILE_I18N.errorDetaching);
      } finally {
        this.isSubmitting = false;
        this.disablingScanType = null;
      }
    },
    openPreview(profileId) {
      this.previewProfileId = profileId;
      this.previewModalVisible = true;
    },
    closePreview() {
      this.previewModalVisible = false;
      this.previewProfileId = '';
    },
  },
};
</script>

<template>
  <div>
    <gl-alert
      v-if="errorMessage"
      variant="danger"
      class="gl-mb-5"
      dismissible
      @dismiss="errorMessage = null"
    >
      {{ errorMessage }}
    </gl-alert>

    <div v-if="isLoading" class="gl-py-5 gl-text-center">
      <gl-loading-icon size="lg" />
    </div>

    <gl-table v-else :items="tableItems" :fields="tableFields" stacked="sm">
      <template #head(name)="data">
        <div class="gl-flex gl-items-center">
          <span>{{ data.label }}</span>
          <gl-icon
            v-gl-tooltip
            name="information-o"
            :title="$options.SCAN_PROFILE_I18N.profilesDefine"
            class="gl-ml-2 gl-text-secondary"
          />
        </div>
      </template>

      <template #cell(scanType)="{ item }">
        <div class="gl-flex gl-items-center">
          <div
            class="gl-border gl-mr-3 gl-flex gl-items-center gl-justify-center gl-rounded-base gl-p-2"
            :class="
              item.isConfigured
                ? 'gl-border-feedback-success gl-bg-feedback-success gl-text-feedback-success'
                : 'gl-border-dashed gl-bg-white gl-text-feedback-neutral'
            "
            style="width: 32px; height: 32px"
          >
            <span class="gl-font-weight-bold gl-font-sm">{{
              getScannerMetadata(item.scanType).label
            }}</span>
          </div>
          <span class="gl-font-bold">{{ getScannerMetadata(item.scanType).name }}</span>
          <gl-icon
            v-gl-tooltip
            name="information-o"
            variant="info"
            :title="getScannerMetadata(item.scanType).tooltip"
            class="gl-ml-2"
          />
        </div>
      </template>

      <template #cell(name)="{ item }">
        <div class="gl-flex gl-items-center">
          <template v-if="item.isConfigured">
            <gl-link @click="openPreview(item.id)">
              {{ item.name }}
            </gl-link>
          </template>
          <span v-else class="gl-text-secondary">
            {{ $options.SCAN_PROFILE_I18N.noProfile }}
          </span>
        </div>
      </template>

      <template #cell(status)="{ item }">
        <div class="gl-flex gl-items-center">
          <gl-icon
            :name="item.isConfigured ? 'check-circle-filled' : 'close'"
            :class="item.isConfigured ? 'gl-text-green-500' : 'gl-text-secondary'"
            class="gl-mr-3 gl-self-start"
          />
          <div class="gl-flex gl-flex-col">
            <span class="gl-font-weight-bold">
              {{
                item.isConfigured
                  ? $options.SCAN_PROFILE_I18N.active
                  : $options.SCAN_PROFILE_I18N.notConfigured
              }}
            </span>
            <span v-if="!item.isConfigured" class="gl-mt-1 gl-text-sm gl-text-secondary">
              {{ $options.SCAN_PROFILE_I18N.applyToEnable }}
            </span>
          </div>
        </div>
      </template>

      <template #cell(lastScan)="{ item }">
        <span>{{ item.lastScan || '—' }}</span>
      </template>

      <template #cell(actions)="{ item }">
        <div v-if="!item.isConfigured">
          <gl-button-group>
            <!-- Apply button -->
            <div :id="getButtonId(item)" class="gl-inline">
              <gl-button
                variant="confirm"
                category="secondary"
                :loading="isSubmitting"
                :disabled="!canApplyProfiles"
                @click="applyProfile(item.id)"
              >
                {{ $options.SCAN_PROFILE_I18N.applyDefault }}
                <gl-icon v-if="!canApplyProfiles" name="lock" class="gl-ml-2" />
              </gl-button>
            </div>
            <!-- Preview button -->
            <gl-button
              v-gl-tooltip
              variant="confirm"
              category="secondary"
              icon="eye"
              :title="$options.SCAN_PROFILE_I18N.previewDefault"
              :disabled="isSubmitting"
              @click="openPreview(item.id)"
            />
          </gl-button-group>
          <insufficient-permissions-popover
            v-if="!canApplyProfiles"
            :target="getButtonId(item)"
            placement="top"
          />
        </div>

        <div v-else :id="getButtonId(item)">
          <!-- Disable button -->
          <gl-button
            variant="danger"
            category="secondary"
            :loading="isSubmitting"
            :disabled="!canApplyProfiles"
            @click="openDisableModal(item.scanType)"
          >
            {{ $options.SCAN_PROFILE_I18N.disable }}
            <gl-icon v-if="!canApplyProfiles" name="lock" class="gl-ml-2" />
          </gl-button>
          <insufficient-permissions-popover
            v-if="!canApplyProfiles"
            :target="getButtonId(item)"
            placement="top"
          />
        </div>
      </template>
    </gl-table>

    <scan-profile-details-modal
      :profile-id="previewProfileId"
      :visible="previewModalVisible"
      :is-attached="isProfileAttached(previewProfileId)"
      @apply="applyProfile"
      @close="closePreview"
    />

    <disable-scan-profile-confirmation-modal
      :visible="disableModalVisible"
      :scanner-name="disablingScanType ? getScannerMetadata(disablingScanType).name : ''"
      @confirm="detachProfile"
      @cancel="disableModalVisible = false"
    />

    <scan-profile-launch-modal />
  </div>
</template>
