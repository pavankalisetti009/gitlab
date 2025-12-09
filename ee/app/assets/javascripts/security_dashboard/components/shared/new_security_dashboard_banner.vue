<script>
import { GlBanner, GlSprintf, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'NewSecurityDashboardBanner',
  components: { GlBanner, GlSprintf, GlLink },
  advancedSearchLink: helpPagePath('/user/search/advanced_search.md', {
    anchor: 'use-advanced-search',
  }),
  newSecurityDashboardLink: helpPagePath(
    '/user/application_security/security_dashboard/_index.md',
    {
      anchor: 'new-security-dashboards',
    },
  ),
};
</script>

<template>
  <gl-banner
    :title="s__('SecurityReports|Enhanced dashboard available')"
    :button-text="s__('SecurityReports|Read more about the new dashboards')"
    :button-link="$options.newSecurityDashboardLink"
    illustration-name="chart-bar-sm"
  >
    <p>
      <gl-sprintf
        :message="
          s__(
            'SecurityReports|The new security dashboards offer additional insights including risk scores for projects and groups, the median age of open vulnerabilities, vulnerability report integration, and more. You do not have advanced search enabled, which is required to access all of the new features. %{linkStart}How do I enable advanced search?%{linkEnd}',
          )
        "
      >
        <template #link="{ content }">
          <gl-link :href="$options.advancedSearchLink">{{ content }}</gl-link>
        </template></gl-sprintf
      >
    </p>
  </gl-banner>
</template>
