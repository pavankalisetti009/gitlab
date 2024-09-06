<script>
import { GlEmptyState, GlSprintf, GlLink } from '@gitlab/ui';
import emptyStateSvgPath from '@gitlab/svgs/dist/illustrations/empty-state/empty-secure-md.svg?url';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  components: {
    GlEmptyState,
    GlSprintf,
    GlLink,
  },
  emptyStateSvgPath,
  learnMoreLink: helpPagePath('user/application_security/secret_detection/index'),
  i18n: {
    emptyStateTitle: s__('SecretDetection|No exclusions yet'),
    emptyStateDescription: s__(
      'SecretDetection|Use secret detection exclusions to specify file paths, raw values, and regex that should be excluded by secret detection in this project. %{linkStart}Learn more.%{linkEnd}',
    ),
    primaryButtonText: s__('SecretDetection|Add exclusion'),
  },
};
</script>

<template>
  <gl-empty-state
    :title="$options.i18n.emptyStateTitle"
    :svg-path="$options.emptyStateSvgPath"
    :primary-button-text="$options.i18n.primaryButtonText"
    primary-button-link="#"
  >
    <template #description>
      <span class="gl-text-lg gl-leading-24">
        <gl-sprintf :message="$options.i18n.emptyStateDescription">
          <template #link="{ content }">
            <gl-link :href="$options.learnMoreLink">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </span>
    </template>
  </gl-empty-state>
</template>
