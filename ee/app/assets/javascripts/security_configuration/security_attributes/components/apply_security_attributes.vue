<script>
import { GlTableLite, GlLabel, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import getSecurityAttributeCategoriesQuery from '../../graphql/client/security_attribute_categories.query.graphql';
import getProjectSecurityAttributesQuery from '../../graphql/client/project_security_attributes.query.graphql';
import ProjectAttributesDrawer from './project_attributes_drawer.vue';

export default {
  components: {
    GlTableLite,
    GlLabel,
    GlButton,
    ProjectAttributesDrawer,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['groupFullPath', 'projectFullPath'],
  data() {
    return {
      group: {
        securityAttributeCategories: { nodes: [] },
      },
      project: {
        securityAttributes: { nodes: [] },
      },
      isDrawerOpen: false,
    };
  },
  apollo: {
    group: {
      query: getSecurityAttributeCategoriesQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
    },
    project: {
      query: getProjectSecurityAttributesQuery,
      variables() {
        return {
          fullPath: this.projectFullPath,
        };
      },
    },
  },
  mounted() {
    this.trackEvent('view_project_security_attributes');
  },
  methods: {
    openDrawer() {
      this.isDrawerOpen = true;
    },
    handleSave() {
      this.closeDrawer();
    },
    closeDrawer() {
      this.isDrawerOpen = false;
    },
  },
  fields: [
    { key: 'category.name', label: s__('SecurityAttributes|Category') },
    { key: 'name', label: s__('SecurityAttributes|Name') },
    { key: 'description', label: s__('SecurityAttributes|Description') },
    { key: 'actions', label: '' },
  ],
};
</script>
<template>
  <div>
    <gl-button variant="confirm" class="gl-float-right gl-mb-5 gl-ml-5" @click="openDrawer">
      {{ s__('SecurityAttributes|Edit project attributes') }}
    </gl-button>
    <project-attributes-drawer
      :open="isDrawerOpen"
      :categories="group.securityAttributeCategories.nodes"
      :selected-attributes="project.securityAttributes.nodes"
      @save="handleSave"
      @cancel="closeDrawer"
    />
    <p class="gl-my-5">
      {{
        s__(
          'SecurityAttributes|Security attributes help classify and organize your projects. Attributes are managed at the group level. You can add or remove attributes to this project as needed.',
        )
      }}
    </p>
    <gl-table-lite :fields="$options.fields" :items="project.securityAttributes.nodes">
      <template #cell(name)="{ item: { name, color } }">
        <gl-label :background-color="color" :title="name" />
      </template>
      <template #cell(actions)>
        <gl-button>{{ s__('SecurityAttributes|Remove attribute') }}</gl-button>
      </template>
    </gl-table-lite>
  </div>
</template>
