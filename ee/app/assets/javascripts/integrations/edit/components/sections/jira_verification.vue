<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';

import JiraVerificationFields from '../jira_verification_fields.vue';

export default {
  name: 'IntegrationSectionJiraVerification',
  components: {
    JiraVerificationFields,
  },
  computed: {
    ...mapGetters(['currentKey', 'propsSource']),
  },
};
</script>

<template>
  <div>
    <jira-verification-fields
      :key="`${currentKey}-jira-verification-fields`"
      v-bind="propsSource.jiraVerificationProps"
    />
  </div>
</template>
