<script>
import { GlEmptyState } from '@gitlab/ui';
import { s__ } from '~/locale';
import { DOC_PATH_SECURITY_CONFIGURATION } from 'ee/security_dashboard/constants';

export default {
  components: {
    GlEmptyState,
  },
  inject: ['emptyStateSvgPath'],
  i18n: {
    title: s__('SecurityReports|No vulnerabilities found'),
    primaryButtonText: s__('SecurityReports|Learn more about security configuration'),
    description: s__(
      `SecurityReports|Although it's rare to have no vulnerabilities, it can happen. Check your project's security configuration to make sure you've set up your security scans correctly.`,
    ),
  },
  DOC_PATH_SECURITY_CONFIGURATION,
};
</script>

<template>
  <gl-empty-state
    :title="$options.i18n.title"
    :svg-path="emptyStateSvgPath"
    :svg-height="null"
    :primary-button-link="$options.DOC_PATH_SECURITY_CONFIGURATION"
    :primary-button-text="$options.i18n.primaryButtonText"
    :description="$options.i18n.description"
  />
</template>
