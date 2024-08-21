<script>
import ProjectList from './project_list.vue';
import PagesDeploymentStats from './stats.vue';

export default {
  name: 'PagesDeployments',
  components: { ProjectList, PagesDeploymentStats },
};
</script>

<template>
  <div class="gl-py-6">
    <h2 class="gl-heading-2 gl-mb-6">{{ s__('Pages|Pages deployments') }}</h2>
    <div class="gl-mb-8">
      <pages-deployment-stats />
    </div>
    <project-list />
  </div>
</template>
