<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import { TYPENAME_VULNERABILITY } from '~/graphql_shared/constants';
import TokenValidityBadge from 'ee/vue_shared/security_reports/components/token_validity_badge.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import refreshFindingTokenStatusMutation from '../graphql/mutations/refresh_finding_token_status.mutation.graphql';

export default {
  name: 'ValidityCheck',
  components: {
    GlButton,
    TimeAgoTooltip,
    TokenValidityBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    findingTokenStatus: {
      type: Object,
      required: false,
      default: null,
    },
    vulnerabilityId: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      isLoading: false,
      latestUpdatedAt: null,
      latestStatus: null,
    };
  },
  computed: {
    lastCheckedAt() {
      return this.latestUpdatedAt || this.findingTokenStatus?.updatedAt;
    },
    tokenValidityStatus() {
      return this.latestStatus || this.findingTokenStatus?.status || 'unknown';
    },
  },
  methods: {
    async refreshValidityCheck() {
      this.isLoading = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: refreshFindingTokenStatusMutation,
          variables: {
            vulnerabilityId: convertToGraphQLId(TYPENAME_VULNERABILITY, this.vulnerabilityId),
          },
        });

        const { errors, findingTokenStatus } = data?.refreshFindingTokenStatus || {};

        if (errors?.length) {
          this.createErrorAlert(new Error(errors.join('. ')));
        } else if (findingTokenStatus) {
          const { updatedAt, status } = findingTokenStatus;

          this.latestUpdatedAt = updatedAt;
          this.latestStatus = status;
        }
      } catch (error) {
        this.createErrorAlert(error);
      } finally {
        this.isLoading = false;
      }
    },
    createErrorAlert(error) {
      createAlert({
        message: s__(
          'VulnerabilityManagement|Could not refresh the validity check. Please try again.',
        ),
        captureError: true,
        error,
      });
    },
  },
};
</script>

<template>
  <span>
    <token-validity-badge :status="tokenValidityStatus" />
    <div v-if="glFeatures.validityRefresh" class="gl-mt-4">
      <span class="gl-font-sm gl-ml-2 gl-mr-2" data-testid="validity-last-checked">
        {{ s__('VulnerabilityManagement|Last checked:') }}
        <template v-if="lastCheckedAt">
          <time-ago-tooltip :time="lastCheckedAt" />
        </template>
        <template v-else>
          <span>{{ s__('VulnerabilityManagement|not available') }}</span>
        </template>
      </span>
      <gl-button
        v-gl-tooltip
        :loading="isLoading"
        category="tertiary"
        size="small"
        icon="retry"
        :title="s__('VulnerabilityManagement|Retry')"
        :aria-label="s__('VulnerabilityManagement|Retry')"
        @click="refreshValidityCheck"
      />
    </div>
  </span>
</template>
