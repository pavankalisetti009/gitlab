<script>
import { GlSprintf } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import {
  BOT_MESSAGE_TYPE,
  fromYaml,
  REQUIRE_APPROVAL_TYPE,
} from '../../policy_editor/scan_result/lib';
import { SUMMARY_TITLE } from '../constants';
import InfoRow from '../info_row.vue';
import DrawerLayout from '../drawer_layout.vue';
import ToggleList from '../toggle_list.vue';
import Approvals from './policy_approvals.vue';
import Settings from './policy_settings.vue';
import { humanizeRules } from './utils';

export default {
  i18n: {
    approvalsSubheader: s__('SecurityOrchestration|If any of the following occur:'),
    fallbackTitle: s__('SecurityOrchestration|Fallback behavior in case of policy failure'),
    summary: SUMMARY_TITLE,
    scanResult: s__('SecurityOrchestration|Merge request approval'),
  },
  components: {
    GlSprintf,
    ToggleList,
    DrawerLayout,
    InfoRow,
    Approvals,
    Settings,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    actions() {
      return this.parsedYaml?.actions;
    },
    description() {
      return this.parsedYaml?.description || '';
    },
    fallbackBehaviorText() {
      switch (this.parsedYaml?.fallback_behavior?.fail) {
        case 'open':
          return s__(
            'ScanResultPolicy|Fail open: Allow the merge request to proceed, even if not all criteria are met',
          );
        case 'closed':
          return s__(
            'ScanResultPolicy|Fail closed: Block the merge request until all criteria are met',
          );
        default:
          return null;
      }
    },
    humanizedRules() {
      return humanizeRules(this.parsedYaml?.rules);
    },
    parsedYaml() {
      return fromYaml({ manifest: this.policy.yaml });
    },
    hasRequireApprovals() {
      return this.requireApprovals.length > 0;
    },
    requireApprovals() {
      return this.actions?.filter((action) => action.type === REQUIRE_APPROVAL_TYPE) || [];
    },
    policyScope() {
      return this.policy?.policyScope;
    },
    actionApprovers() {
      return this.policy?.actionApprovers || [];
    },
    settings() {
      return this.parsedYaml?.approval_settings || {};
    },
    shouldRenderBotMessage() {
      return !this.actions?.some(({ type, enabled }) => type === BOT_MESSAGE_TYPE && !enabled);
    },
  },
  methods: {
    capitalizedCriteriaMessage(message) {
      return capitalizeFirstCharacter(message.trim());
    },
    showBranchExceptions(exceptions) {
      return exceptions?.length > 0;
    },
    isLastApproverItem(index) {
      return this.actionApprovers.length - 1 === index;
    },
    mapApproversToArray(index) {
      const approvers = this.actionApprovers[index];

      if (approvers === undefined) {
        return [];
      }

      return [
        ...approvers.allGroups,
        ...approvers.roles.map((role) => {
          return {
            GUEST: __('Guest'),
            REPORTER: __('Reporter'),
            DEVELOPER: __('Developer'),
            MAINTAINER: __('Maintainer'),
            OWNER: __('Owner'),
          }[role];
        }),
        ...approvers.users,
      ];
    },
  },
};
</script>

<template>
  <drawer-layout
    key="scan_result_policy"
    :description="description"
    :policy="policy"
    :policy-scope="policyScope"
    :type="$options.i18n.scanResult"
  >
    <template v-if="parsedYaml" #summary>
      <info-row data-testid="policy-summary" :label="$options.i18n.summary">
        <approvals
          v-for="(action, index) in requireApprovals"
          :key="action.id"
          class="gl-mb-2 gl-block"
          :action="action"
          :is-last-item="!shouldRenderBotMessage"
          :approvers="mapApproversToArray(index)"
        />

        <div v-if="shouldRenderBotMessage" class="gl-mt-2" data-testid="policy-bot-message">
          {{ s__('SecurityOrchestration|Send a bot message when the conditions match.') }}
        </div>

        <p
          v-if="hasRequireApprovals"
          data-testid="approvals-subheader"
          class="gl-mb-0 gl-mt-6 gl-block"
        >
          {{ $options.i18n.approvalsSubheader }}
        </p>

        <div
          v-for="(
            { summary, branchExceptions, licenses, criteriaMessage, criteriaList }, idx
          ) in humanizedRules"
          :key="idx"
          class="gl-pt-5"
        >
          <gl-sprintf :message="summary">
            <template #licenses>
              <toggle-list data-testid="licences-list" class="gl-mb-2" :items="licenses" />
            </template>
          </gl-sprintf>
          <toggle-list
            v-if="showBranchExceptions(branchExceptions)"
            class="gl-mb-2"
            :items="branchExceptions"
          />
          <p v-if="criteriaMessage" class="gl-mb-3">
            {{ capitalizedCriteriaMessage(criteriaMessage) }}
          </p>
          <ul class="gl-m-0">
            <li v-for="(criteria, criteriaIdx) in criteriaList" :key="criteriaIdx" class="gl-mt-2">
              {{ criteria }}
            </li>
          </ul>
          <settings :settings="settings" />
        </div>
      </info-row>
    </template>

    <template #additional-details>
      <info-row
        v-show="fallbackBehaviorText"
        :label="$options.i18n.fallbackTitle"
        data-testid="additional-details"
      >
        {{ fallbackBehaviorText }}
      </info-row>
    </template>
  </drawer-layout>
</template>
