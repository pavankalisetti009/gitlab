<script>
import { GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { joinPaths } from '~/lib/utils/url_utility';
import { fromYaml } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import { humanizeActions } from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/utils';
import { SUMMARY_TITLE } from 'ee/security_orchestration/components/policy_drawer/constants';
import { PIPELINE_EXECUTION_POLICY_TYPE_HEADER } from 'ee/security_orchestration/components/constants';
import DrawerLayout from '../drawer_layout.vue';
import InfoRow from '../info_row.vue';

export default {
  i18n: {
    noActionMessage: s__('SecurityOrchestration|No actions defined - policy will not run.'),
    pipelineExecution: PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
    pipelineExecutionActionsHeader: s__(
      'SecurityOrchestration|Enforce the following pipeline execution policy:',
    ),
    summary: SUMMARY_TITLE,
  },
  name: 'PipelineExecutionDrawer',
  components: {
    InfoRow,
    DrawerLayout,
    GlLink,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    humanizedActions() {
      return humanizeActions([this.parsedYaml]);
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    parsedYaml() {
      return fromYaml({ manifest: this.policy.yaml });
    },
  },
  methods: {
    getComponent(prop) {
      return ['project'].includes(prop) ? GlLink : 'p';
    },
    getHref({ project }, type) {
      switch (type) {
        case 'project':
          return joinPaths(gon.relative_url_root || '/', project.content);
        default:
          return '';
      }
    },
  },
};
</script>

<template>
  <drawer-layout
    key="pipeline_execution_policy"
    :description="parsedYaml.description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="$options.i18n.pipelineExecution"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <template v-if="!humanizedActions.length">{{ $options.i18n.noActionMessage }}</template>
        <div v-else>
          <p data-testid="summary-header">{{ $options.i18n.pipelineExecutionActionsHeader }}</p>

          <ul
            v-for="action in humanizedActions"
            :key="action.project.value"
            class="gl-list-none gl-pl-0"
            data-testid="summary-fields"
          >
            <li v-for="{ type, label, content } in action" :key="content" class="gl-mb-2">
              <span>
                {{ label }}
              </span>
              <span>:</span>
              <component :is="getComponent(type)" :href="getHref(action, type)" class="gl-inline">
                {{ content }}
              </component>
            </li>
          </ul>
        </div>
      </info-row>
    </template>
  </drawer-layout>
</template>
