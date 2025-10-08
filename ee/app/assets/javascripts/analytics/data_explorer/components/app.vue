<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import DataExplorer from 'ee/vue_shared/components/data_explorer/data_explorer.vue';

export default {
  name: 'DataExplorerApp',
  components: {
    PageHeading,
    DataExplorer,
    GlLink,
    GlSprintf,
  },

  // TODO: Update this link once we have a Data explorer docs page
  // https://gitlab.com/gitlab-org/gitlab/-/issues/573622
  learnMoreLink: helpPagePath('user/glql/_index'),
};
</script>

<template>
  <div>
    <page-heading :heading="s__('DataExplorer|Data explorer')">
      <template #description>
        <gl-sprintf
          :message="
            s__(
              'DataExplorer|Explore GitLab data in a single place. %{linkStart}Learn more.%{linkEnd}',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.learnMoreLink">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </template>
    </page-heading>

    <data-explorer />
  </div>
</template>
