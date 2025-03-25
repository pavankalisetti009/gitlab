<script>
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import Dashboard from './inventory_dashboard.vue';

export default {
  components: {
    PageHeading,
    Dashboard,
  },
  i18n: {
    title: s__('SecurityInventory|Security inventory'),
    description: s__(
      'SecurityInventory|View security coverage and vulnerabilities for all the projects in this group.',
    ),
  },
};
</script>

<template>
  <div>
    <page-heading :heading="$options.i18n.title" data-testid="vulnerability-report-header">
      <template #description>{{ $options.i18n.description }}</template></page-heading
    >
    <dashboard />
  </div>
</template>
