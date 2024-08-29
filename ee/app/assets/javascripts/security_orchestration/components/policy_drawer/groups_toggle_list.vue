<script>
import { GlAccordion, GlAccordionItem } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { s__, n__, sprintf } from '~/locale';

export default {
  i18n: {
    groupsHeader: s__('SecurityOrchestration|Linked groups'),
    groupsInlineListHeader: s__('SecurityOrchestration|All projects in linked groups'),
    groupsInlineListSubHeader: s__('SecurityOrchestration|(%{groups})'),
    projectsHeader: s__('SecurityOrchestration|Excluded projects'),
  },
  name: 'GroupsToggleList',
  components: {
    GlAccordion,
    GlAccordionItem,
  },
  props: {
    inlineList: {
      type: Boolean,
      required: false,
      default: false,
    },
    groups: {
      type: Array,
      required: false,
      default: () => [],
    },
    projects: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    hasProjects() {
      return this.projectsLength > 0;
    },
    hasGroups() {
      return this.groupsLength > 0;
    },
    groupsLabel() {
      return n__('group', 'groups', this.groupsLength);
    },
    groupsLength() {
      return this.groups.length;
    },
    projectsLength() {
      return this.projects.length;
    },
    groupsHeader() {
      const template = this.hasProjects
        ? n__(
            'All projects in %{groupsLength} group, with exclusions:',
            'All projects in %{groupsLength} groups, with exclusions:',
            this.groupsLength,
          )
        : n__(
            'All projects in %{groupsLength} group:',
            'All projects in %{groupsLength} groups:',
            this.groupsLength,
          );

      return sprintf(template, { groupsLength: this.groupsLength });
    },
    groupsInlineListSubHeader() {
      const groupsMessage = sprintf(
        n__('%{groupsLength} group', '%{groupsLength} groups', this.groupsLength),
        {
          groupsLength: this.groupsLength,
        },
      );

      return sprintf(this.$options.i18n.groupsInlineListSubHeader, {
        groups: groupsMessage,
      });
    },
    groupsNames() {
      return this.groups.map(({ name }) => name);
    },
    projectNames() {
      return this.projects.map(({ name }) => name);
    },
  },
  methods: {
    uniqueId(name) {
      return uniqueId(name);
    },
  },
};
</script>

<template>
  <div>
    <div v-if="inlineList" data-testid="groups-list-inline-header">
      <p class="gl-mb-2">{{ $options.i18n.groupsInlineListHeader }}</p>
      <p v-if="hasGroups" class="gl-m-0">{{ groupsInlineListSubHeader }}</p>
    </div>

    <template v-else>
      <p class="gl-mb-3" data-testid="groups-list-header">{{ groupsHeader }}</p>

      <gl-accordion :header-level="3" :class="{ 'gl-mb-2': hasProjects }">
        <gl-accordion-item :title="$options.i18n.groupsHeader" data-testid="groups-list">
          <ul>
            <li v-for="name of groupsNames" :key="uniqueId(name)" data-testid="group-item">
              {{ name }}
            </li>
          </ul>
        </gl-accordion-item>
      </gl-accordion>

      <gl-accordion v-if="hasProjects" :header-level="3">
        <gl-accordion-item :title="$options.i18n.projectsHeader" data-testid="projects-list">
          <ul>
            <li v-for="name of projectNames" :key="uniqueId(name)" data-testid="project-item">
              {{ name }}
            </li>
          </ul>
        </gl-accordion-item>
      </gl-accordion>
    </template>
  </div>
</template>
