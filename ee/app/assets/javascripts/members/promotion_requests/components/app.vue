<script>
import { GlTable, GlKeysetPagination, GlAlert } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import UserDate from '~/vue_shared/components/user_date.vue';
import { CONTEXT_TYPE } from '~/members/constants';
import { DEFAULT_PER_PAGE } from '~/api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ProjectPendingMemberApprovalsQuery from '../graphql/project_pending_member_approvals.query.graphql';
import GroupPendingMemberApprovalsQuery from '../graphql/group_pending_member_approvals.query.graphql';
import { subscribe } from '../services/promotion_request_list_invalidation_service';

const FIELDS = [
  {
    key: 'user',
    label: __('User'),
  },
  {
    key: 'requested_role',
    label: s__('Members|Requested Role'),
    tdClass: '!gl-align-middle',
  },
  {
    key: 'requested_by',
    label: s__('Members|Requested By'),
    tdClass: '!gl-align-middle',
  },
  {
    key: 'requested_on',
    label: s__('Members|Requested On'),
    tdClass: '!gl-align-middle',
  },
];

export default {
  name: 'PromotionRequestsTabApp',
  components: {
    GlTable,
    GlKeysetPagination,
    GlAlert,
    UserDate,
  },
  inject: ['context', 'group', 'project'],
  data() {
    return {
      unsubscribe: null,
      isLoading: true,
      error: null,
      pendingMemberApprovals: {},
      cursor: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
    };
  },
  mounted() {
    this.unsubscribe = subscribe(() => {
      this.first = DEFAULT_PER_PAGE;
      this.last = null;
      this.after = null;
      this.before = null;
      this.$apollo.queries.pendingMemberApprovals.refetch();
    });
  },
  destroyed() {
    this.unsubscribe?.();
  },
  apollo: {
    // NOTE: Promotion requests may exist in two different contexts: group and project member
    // management pages. Pending promotions data interface is the same for both contexts, but the
    // queries are different.
    pendingMemberApprovals: {
      query() {
        return this.context === CONTEXT_TYPE.GROUP
          ? GroupPendingMemberApprovalsQuery
          : ProjectPendingMemberApprovalsQuery;
      },
      variables() {
        const fullPath = this.context === CONTEXT_TYPE.GROUP ? this.group.path : this.project.path;
        return {
          ...this.cursor,
          fullPath,
        };
      },
      update(data) {
        return this.context === CONTEXT_TYPE.GROUP
          ? data.group.pendingMemberApprovals
          : data.project.pendingMemberApprovals;
      },
      error(error) {
        this.isLoading = false;
        this.error = s__(
          'PromotionRequests|An error occurred while loading promotion requests. Reload the page to try again.',
        );
        Sentry.captureException({ error, component: this.$options.name });
      },
      result() {
        this.isLoading = false;
      },
    },
  },
  methods: {
    onPrev(before) {
      this.isLoading = true;
      this.cursor = {
        first: DEFAULT_PER_PAGE,
        last: null,
        before,
      };
    },
    onNext(after) {
      this.isLoading = true;
      this.cursor = {
        first: null,
        last: DEFAULT_PER_PAGE,
        after,
      };
    },
  },
  FIELDS,
};
</script>
<template>
  <div>
    <gl-alert
      v-if="error"
      variant="danger"
      sticky
      :dismissible="false"
      class="gl-top-10 gl-z-1 gl-my-4"
      >{{ error }}</gl-alert
    >
    <gl-table :busy="isLoading" :items="pendingMemberApprovals.nodes" :fields="$options.FIELDS">
      <template #cell(user)="{ item }">
        <span v-if="item.user">{{ item.user.name }}</span>
        <span v-else>{{ __('Orphaned member') }}</span>
      </template>
      <template #cell(requested_role)="{ item }">
        {{ item.newAccessLevel.stringValue }}
      </template>
      <template #cell(requested_by)="{ item }">
        <a :href="item.requestedBy.webUrl">{{ item.requestedBy.name }}</a>
      </template>
      <template #cell(requested_on)="{ item }">
        <user-date :date="item.createdAt" />
      </template>
    </gl-table>
    <div class="gl-mt-4 gl-flex gl-flex-col gl-items-center">
      <gl-keyset-pagination
        v-bind="pendingMemberApprovals.pageInfo"
        :disabled="isLoading"
        @prev="onPrev"
        @next="onNext"
      />
    </div>
  </div>
</template>
