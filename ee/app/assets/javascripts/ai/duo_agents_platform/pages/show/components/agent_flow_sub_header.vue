<script>
import { GlSkeletonLoader, GlAvatarLink, GlAvatar, GlTooltipDirective } from '@gitlab/ui';
import { isGid, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { getUser } from '~/api/user_api';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { formatDate } from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'AgentFlowSubHeader',
  components: {
    GlSkeletonLoader,
    GlAvatarLink,
    GlAvatar,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    isLoading: {
      required: true,
      type: Boolean,
    },
    agentFlowDefinition: {
      required: true,
      type: String,
    },
    createdAt: {
      required: true,
      type: String,
    },
    userId: {
      required: true,
      type: String,
    },
  },
  data() {
    return {
      user: {},
      isFetchingUser: false,
    };
  },
  computed: {
    numericUserId() {
      return this.userId && isGid(this.userId) ? getIdFromGraphQLId(this.userId) : this.userId;
    },
    userUsername() {
      return this.user?.username || '';
    },
    userWebUrl() {
      return this.user?.web_url || '';
    },
    userAvatarUrl() {
      return this.user?.avatar_url || '';
    },
    userName() {
      return this.user?.name || '';
    },
    isLoadingUser() {
      return this.isLoading || this.isFetchingUser;
    },
  },
  watch: {
    numericUserId: {
      immediate: true,
      handler(newUserId) {
        if (newUserId) {
          this.fetchUser();
        }
      },
    },
  },
  methods: {
    formatDate,
    async fetchUser() {
      this.isFetchingUser = true;
      try {
        const { data } = await getUser(this.numericUserId);
        this.user = data;
      } catch (error) {
        Sentry.captureException(error);
        this.user = {};
      } finally {
        this.isFetchingUser = false;
      }
    },
  },
};
</script>
<template>
  <div class="gl-border-b">
    <div v-if="isLoadingUser">
      <gl-skeleton-loader :lines="1" :width="400" class="gl-m-4" />
    </div>
    <div v-else class="gl-m-4">
      <div class="gl-flex gl-items-center gl-gap-3">
        <gl-avatar-link
          :href="userWebUrl"
          :data-user-id="numericUserId"
          :data-username="userUsername"
          class="js-user-link"
        >
          <gl-avatar :src="userAvatarUrl" :entity-name="userUsername" :alt="userName" :size="32" />
        </gl-avatar-link>
        <div>
          <gl-avatar-link
            v-gl-tooltip.bottom
            :href="userWebUrl"
            :data-user-id="numericUserId"
            :data-username="userUsername"
            :title="userName"
            class="js-user-link gl-font-bold"
          >
            @{{ userUsername }}
          </gl-avatar-link>
          <span class="gl-lowercase">{{ s__('DuoAgentPlatform|Triggered') }}</span>
          {{
            sprintf(s__('DuoAgentPlatform|%{agentName} %{date}'), {
              agentName: agentFlowDefinition,
              date: formatDate(createdAt),
            })
          }}
        </div>
      </div>
    </div>
  </div>
</template>
