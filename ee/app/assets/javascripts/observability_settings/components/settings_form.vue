<script>
import { GlSprintf, GlLink } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';

export default {
  components: {
    GlSprintf,
    GlLink,
    SettingsBlock,
  },
  docsLink: `${DOCS_URL_IN_EE_DIR}/operations`,
  i18n: {
    headerText: s__('Observability|Tracing, Metrics & Logs'),
    expandBtnLabel: __('Expand'),
    subHeaderText: s__('Observability|Enable tracing, metrics, or logs on your project.'),
    introText: s__(
      'Observability|View our %{docsLink} for further instructions on how to use these features.',
    ),
    introLinkText: s__('Observability|documentation'),
  },
};
</script>

<template>
  <settings-block>
    <template #title>
      <span ref="sectionHeader">{{ $options.i18n.headerText }}</span>
    </template>

    <template #description>
      <span ref="sectionSubHeader">{{ $options.i18n.subHeaderText }}</span>
    </template>

    <template #default>
      <p>
        <gl-sprintf :message="$options.i18n.introText">
          <template #docsLink>
            <gl-link :href="$options.docsLink">
              <span>{{ $options.i18n.introLinkText }}</span>
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
    </template>
  </settings-block>
</template>
