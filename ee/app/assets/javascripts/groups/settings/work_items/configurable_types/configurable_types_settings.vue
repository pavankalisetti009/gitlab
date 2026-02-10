<script>
import WorkItemTypesList from 'ee/work_items/components/work_item_types_list.vue';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';

export default {
  name: 'ConfigurableTypesSettings',
  components: {
    WorkItemTypesList,
    SettingsBlock,
    HelpPageLink,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: '',
    },
    id: {
      type: String,
      required: true,
    },
    expanded: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
  },
  emits: ['toggle-expand'],
};
</script>

<template>
  <settings-block
    :id="id"
    :title="s__('WorkItem|Work item types')"
    :expanded="expanded"
    @toggle-expand="$emit('toggle-expand', $event)"
  >
    <template #description>
      <p class="gl-mb-3 gl-text-subtle">
        {{
          s__(
            'WorkItem|Work item types are used to track different kinds of work. Each work item type can have different lifecycles and fields.',
          )
        }}
        <help-page-link href="user/work_items/_index.md" target="_blank">
          {{ s__('WorkItem|How do I use or configure work item types?') }}
        </help-page-link>
      </p>
    </template>
    <template #default>
      <work-item-types-list :full-path="fullPath" :config="config" />
    </template>
  </settings-block>
</template>
