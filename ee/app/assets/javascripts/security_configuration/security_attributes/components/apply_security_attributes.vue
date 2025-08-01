<script>
import { GlTableLite, GlLabel, GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';
import getProjectSecurityAttributesQuery from '../../graphql/client/project_security_attributes.query.graphql';

export default {
  components: {
    GlTableLite,
    GlLabel,
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  inject: ['projectFullPath'],
  data() {
    return {
      project: {
        securityAttributes: { nodes: [] },
      },
    };
  },
  apollo: {
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
