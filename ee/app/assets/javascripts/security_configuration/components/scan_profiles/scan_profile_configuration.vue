<script>
import {
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
import { PROMO_URL } from '~/constants';
import {
  SCAN_PROFILE_TYPE_SECRET_DETECTION,
  SCAN_PROFILE_CATEGORIES,
  SCAN_PROFILE_PROMO_ITEMS,
  SCAN_PROFILE_I18N,
} from '~/security_configuration/constants';
import ScanProfileTable from '~/security_configuration/components/scan_profiles/scan_profile_table.vue';
import availableProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/group_available_security_scan_profiles.query.graphql';
import projectProfilesQuery from 'ee/security_configuration/graphql/scan_profiles/project_security_scan_profiles.query.graphql';
import attachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_attach.mutation.graphql';
import detachMutation from 'ee/security_configuration/graphql/scan_profiles/security_scan_profile_detach.mutation.graphql';
import DisableScanProfileConfirmationModal from './disable_scan_profile_confirmation_modal.vue';
import ScanProfileDetailsModal from './scan_profile_details_modal.vue';
import InsufficientPermissionsPopover from './insufficient_permissions_popover.vue';
import ScanProfileLaunchModal from './scan_profile_launch_modal.vue';

Vue.use(GlToast);

const APPLICATION_SECURITY_TESTING_PROMO_URL = `${PROMO_URL}/solutions/application-security-testing/`;

export default {
  name: 'ScanProfileConfiguration',
  components: {
    GlButtonGroup,
    GlButton,
    GlIcon,
    GlAlert,
    GlLink,
    GlLoadingIcon,
    ScanProfileTable,
    DisableScanProfileConfirmationModal,
    ScanProfileDetailsModal,
    InsufficientPermissionsPopover,
    ScanProfileLaunchModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['projectFullPath', 'groupFullPath', 'canApplyProfiles', 'securityScanProfilesLicensed'],
  SCAN_PROFILE_I18N,
  APPLICATION_SECURITY_TESTING_PROMO_URL,
  apollo: {
    availableProfiles: {
      skip() {
        return !this.securityScanProfilesLicensed;
      },
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
      skip() {
        return !this.securityScanProfilesLicensed;
      },
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
      if (!this.securityScanProfilesLicensed) return SCAN_PROFILE_PROMO_ITEMS;

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

    <scan-profile-table v-else :table-items="tableItems">
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
        <div v-if="!securityScanProfilesLicensed" class="gl-flex gl-flex-col">
          <span class="gl-font-weight-bold">
            {{ __('Available with Ultimate') }}
          </span>
          <span class="gl-mt-1 gl-text-sm gl-text-secondary">
            <gl-link :href="$options.APPLICATION_SECURITY_TESTING_PROMO_URL" target="_blank">
              {{ __('Learn more about the Ultimate security suite') }}
              <gl-icon name="external-link" :aria-label="__('(external link)')" />
            </gl-link>
          </span>
        </div>
        <div v-else class="gl-flex gl-items-center">
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

      <template #cell(actions)="{ item }">
        <div v-if="!item.isConfigured">
          <gl-button-group>
            <!-- Apply button -->
            <div :id="getButtonId(item)" class="gl-inline">
              <gl-button
                variant="confirm"
                category="secondary"
                :loading="isSubmitting"
                :disabled="!canApplyProfiles || !securityScanProfilesLicensed"
                class="!gl-rounded-r-none"
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
              :disabled="isSubmitting || !securityScanProfilesLicensed"
              @click="openPreview(item.id)"
            />
          </gl-button-group>
          <insufficient-permissions-popover
            v-if="!canApplyProfiles && securityScanProfilesLicensed"
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
            :disabled="!canApplyProfiles || !securityScanProfilesLicensed"
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
    </scan-profile-table>

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

    <scan-profile-launch-modal v-if="securityScanProfilesLicensed" />
  </div>
</template>
