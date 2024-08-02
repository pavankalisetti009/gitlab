<script>
import { GlAccordion, GlAccordionItem, GlAlert, GlSprintf } from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import { s__, sprintf } from '~/locale';

export default {
  name: 'SbomReportsErrorsAlert',
  components: {
    GlAlert,
    GlSprintf,
    GlAccordion,
    GlAccordionItem,
    HelpPageLink,
  },
  props: {
    errors: {
      type: Array,
      required: true,
    },
  },
  computed: {
    errorsWithTitles() {
      return this.errors.map((reportErrors, index) => ({
        reportErrors,
        accordionTitle: sprintf(this.$options.i18n.ACCORDION_TITLE, {
          index: index + 1,
          length: reportErrors.length,
        }),
      }));
    },
  },
  i18n: {
    SBOM_ERROR_ALERT_TITLE: s__('Dependencies|Error parsing SBOM reports'),
    SBOM_ERROR_DESCRIPTION: s__(
      'Dependencies|The following SBOM reports could not be parsed, and the list of components may be incomplete. Please investigate the provided reports and ensure they conform to %{helpPageLinkStart}the requirements for SBOM documents%{helpPageLinkEnd}.',
    ),
    ACCORDION_TITLE: s__('Dependencies|report-%{index} (%{length})'),
  },
};
</script>

<template>
  <gl-alert variant="danger" :dismissible="false">
    <strong role="heading">
      {{ $options.i18n.SBOM_ERROR_ALERT_TITLE }}
    </strong>

    <p class="gl-mt-3">
      <gl-sprintf :message="$options.i18n.SBOM_ERROR_DESCRIPTION">
        <template #helpPageLink="{ content }">
          <help-page-link
            href="user/application_security/dependency_list/index"
            anchor="prerequisites"
            target="_blank"
            >{{ content }}</help-page-link
          >
        </template>
      </gl-sprintf>
    </p>

    <gl-accordion :header-level="3">
      <gl-accordion-item
        v-for="({ reportErrors, accordionTitle }, index) in errorsWithTitles"
        :key="index"
        :title="accordionTitle"
      >
        <ul class="gl-pl-4">
          <li v-for="error in reportErrors" :key="error">{{ error }}</li>
        </ul>
      </gl-accordion-item>
    </gl-accordion>
  </gl-alert>
</template>
