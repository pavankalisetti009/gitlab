<script>
import { GlAvatar, GlAvatarLink, GlIcon, GlLabel, GlLink, GlTooltipDirective } from '@gitlab/ui';
import { __, n__, sprintf } from '~/locale';
import { getTimeago, localeDateFormat } from '~/lib/utils/datetime_utility';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import { joinPaths, mergeUrlParams } from '~/lib/utils/url_utility';
import { SCOPED_LABEL_COLOR } from '../../constants';
import { convertRotationPeriod } from '../../utils';

export default {
  name: 'SecretDetails',
  components: {
    GlAvatar,
    GlAvatarLink,
    GlIcon,
    GlLabel,
    GlLink,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    secret: {
      type: Object,
      required: true,
    },
  },
  computed: {
    branchMatchesPath() {
      // TODO: workaround while backend API is not yet available. for now, frontend uses mock data
      // branchMatchesPath should be provided by backend in full; frontend only needs to provide the URL params
      const url = joinPaths('/', this.fullPath, '-', this.secret.branchMatchesPath);
      return mergeUrlParams(
        {
          state: 'all',
          search: this.secret.branch,
        },
        url,
      );
    },
    createdAtText() {
      return localeDateFormat.asDate.format(new Date(this.secret.createdAt));
    },
    descriptionText() {
      return this.secret.description || __('None');
    },
    environmentMatchesPath() {
      // TODO: workaround while backend API is not yet available. for now, frontend uses mock data
      // environmentMatchesPath should be provided by backend in full; frontend only needs to provide the URL params
      const url = joinPaths('/', this.fullPath, '-', this.secret.envMatchesPath);
      return mergeUrlParams(
        {
          scope: 'active',
          search: this.secret.environment,
        },
        url,
      );
    },
    environmentLabelText() {
      const { environment } = this.secret;
      const environmentText = convertEnvironmentScope(environment).toLowerCase();
      return `${__('env')}::${environmentText}`;
    },
    expirationText() {
      return localeDateFormat.asDate.format(new Date(this.secret.expiration));
    },
    lastUsedText() {
      if (!this.secret.lastAccessed) {
        return __('Never');
      }

      const lastUsed = capitalizeFirstCharacter(getTimeago().format(this.secret.lastAccessed));
      return sprintf(__('%{lastUsed} by'), { lastUsed });
    },
    matchingBranchesText() {
      return n__('%d matching branch', '%d matching branches', this.secret.envMatchesCount);
    },
    matchingEnvsText() {
      return n__(
        '%d matching environment',
        '%d matching environments',
        this.secret.envMatchesCount,
      );
    },
    rotationPeriodText() {
      if (!this.secret.rotationPeriod) {
        return __('None');
      }

      const rotationPeriod = convertRotationPeriod(this.secret.rotationPeriod);
      const rotationDate = localeDateFormat.asDate.format(new Date(this.secret.nextRotation));

      return sprintf(__('%{rotationDate} (%{rotationPeriod})'), { rotationDate, rotationPeriod });
    },
  },
  SCOPED_LABEL_COLOR,
};
</script>
<template>
  <div class="gl-mt-4">
    <div class="gl-flex">
      <b class="gl-basis-1/4">{{ __('Description') }}</b>
      <p
        :class="{ 'gl-text-secondary': !secret.description }"
        data-testid="secret-details-description"
      >
        {{ descriptionText }}
      </p>
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ __('Environments') }}</b>
      <gl-label
        :title="environmentLabelText"
        :background-color="$options.SCOPED_LABEL_COLOR"
        data-testid="secret-details-environments"
        scoped
      />
      <gl-link
        v-if="secret.envMatchesCount"
        :href="environmentMatchesPath"
        class="gl-ml-3 gl-pt-1"
        data-testid="secret-details-matching-envs"
        >{{ matchingEnvsText }}
      </gl-link>
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ __('Branches') }}</b>
      <code data-testid="secret-details-branches">
        <gl-icon name="branch" :size="12" class="gl-mr-1" />
        {{ secret.branch }}
      </code>
      <gl-link
        v-if="secret.branchMatchesCount"
        :href="branchMatchesPath"
        class="gl-ml-3 gl-pt-1"
        data-testid="secret-details-matching-branches"
        >{{ matchingBranchesText }}
      </gl-link>
    </div>
    <div class="gl-flex">
      <b class="gl-basis-1/4">{{ __('Last used') }}</b>
      <p
        :class="{ 'gl-text-secondary': !secret.lastAccessed }"
        data-testid="secret-details-last-used"
      >
        {{ lastUsedText }}
      </p>
      <gl-avatar-link
        v-if="secret.lastAccessedUser"
        v-gl-tooltip
        class="gl-ml-3"
        :href="secret.lastAccessedUser.webUrl"
        :data-user-id="secret.lastAccessedUser.userId"
        :data-username="secret.lastAccessedUser.username"
        :title="secret.lastAccessedUser.name"
      >
        <gl-avatar
          :src="secret.lastAccessedUser.avatarUrl"
          :entity-name="secret.lastAccessedUser.name"
          :size="24"
          :alt="secret.lastAccessedUser.name"
        />
      </gl-avatar-link>
    </div>
    <div class="gl-flex">
      <b class="gl-basis-1/4">{{ __('Expiration date') }}</b>
      <p data-testid="secret-details-expiration-date">{{ expirationText }}</p>
    </div>
    <div class="gl-flex">
      <b class="gl-basis-1/4">{{ __('Rotation reminder') }}</b>
      <p
        :class="{ 'gl-text-secondary': !secret.rotationPeriod }"
        data-testid="secret-details-rotation-reminder"
      >
        {{ rotationPeriodText }}
      </p>
    </div>
  </div>
</template>
