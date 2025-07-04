<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';

export default {
  name: 'AiCatalogAgentsNew',
  components: {
    PageHeading,
  },
};
</script>

<template>
  <div>
    <page-heading :heading="s__('AICatalog|Create new agent')" />
    <div class="gl-rounded-base gl-bg-subtle gl-p-4">
      <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
      <p class="gl-text-center gl-text-subtle">Agent creation form will be implemented here.</p>
    </div>
  </div>
</template>
