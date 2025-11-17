<script>
import { GlBadge, GlIcon, GlLabel, GlTooltipDirective } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import {
  SECRET_STATUS,
  SECRET_STATUS_ICONS_OPTICALLY_ALIGNED,
  SCOPED_LABEL_COLOR,
} from '../../constants';

export default {
  name: 'SecretDetails',
  components: {
    GlBadge,
    GlIcon,
    GlLabel,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    secret: {
      type: Object,
      required: true,
    },
  },
  computed: {
    descriptionText() {
      return this.secret.description || __('None');
    },
    environmentLabelText() {
      const { environment } = this.secret;
      const environmentText = convertEnvironmentScope(environment).toLowerCase();
      return `${__('env')}::${environmentText}`;
    },
    rotationReminderText() {
      const nextReminderAt = this.secret.rotationInfo?.nextReminderAt;
      if (nextReminderAt) {
        const formattedDate = localeDateFormat.asDate.format(new Date(nextReminderAt));
        return sprintf(s__('SecretRotation|%{date} (Every %{days} days)'), {
          date: formattedDate,
          days: this.secret.rotationInfo?.rotationIntervalDays,
        });
      }

      return __('None');
    },
  },
  SECRET_STATUS,
  SECRET_STATUS_ICONS_OPTICALLY_ALIGNED,
  SCOPED_LABEL_COLOR,
};
</script>
<template>
  <div class="gl-mt-4">
    <div class="gl-flex">
      <b class="gl-basis-1/4">{{ __('Description') }}</b>
      <p
        :class="{ 'gl-text-subtle': !secret.description }"
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
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ __('Branches') }}</b>
      <code data-testid="secret-details-branches">
        <gl-icon name="branch" :size="12" class="gl-mr-1" />
        {{ secret.branch }}
      </code>
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ s__('SecretRotation|Rotation reminder') }}</b>
      <p
        class="gl-m-0"
        :class="{ 'gl-text-subtle': !secret.rotationInfo }"
        data-testid="secret-details-rotation-reminder"
      >
        {{ rotationReminderText }}
      </p>
    </div>
    <div class="gl-mb-4 gl-flex">
      <b class="gl-basis-1/4">{{ __('Status') }}</b>
      <gl-badge
        v-gl-tooltip.right
        :title="$options.SECRET_STATUS[secret.status].description"
        :icon="$options.SECRET_STATUS[secret.status].icon"
        :variant="$options.SECRET_STATUS[secret.status].variant"
        :icon-optically-aligned="
          $options.SECRET_STATUS_ICONS_OPTICALLY_ALIGNED.includes(secret.status)
        "
        data-testid="secret-details-health-status"
      >
        {{ $options.SECRET_STATUS[secret.status].text }}
      </gl-badge>
    </div>
  </div>
</template>
