<script>
import { GlLink, GlButton, GlIcon } from '@gitlab/ui';
import Tracking from '~/tracking';
import UserGroupCalloutDismisser from '~/vue_shared/components/user_group_callout_dismisser.vue';
import { PREMIUM_MESSAGES_DURING_TRIAL } from '../constants';

export default {
  name: 'PremiumMessageDuringTrial',
  components: {
    GlLink,
    GlButton,
    GlIcon,
    UserGroupCalloutDismisser,
  },
  mixins: [Tracking.mixin({ experiment: 'premium_message_during_trial' })],
  props: {
    featureId: {
      type: String,
      required: true,
    },
    groupId: {
      type: String,
      required: true,
    },
    page: {
      type: String,
      required: true,
    },
    upgradeUrl: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      messages: PREMIUM_MESSAGES_DURING_TRIAL[this.page],
    };
  },
  mounted() {
    this.track('render_project_card');
  },
  methods: {
    handleDismiss(dismissFn) {
      dismissFn();
      this.track('click_dismiss_button_on_project_card');
    },
  },
};
</script>

<template>
  <user-group-callout-dismisser :feature-name="featureId" :group-id="groupId" skip-query>
    <template #default="{ dismiss, shouldShowCallout }">
      <div v-if="shouldShowCallout" class="info-well gl-mt-5" data-testid="premium-trial-callout">
        <div class="well-segment gl-flex !gl-py-4">
          <div class="gl-grow gl-items-center gl-justify-between gl-gap-6 @sm/panel:gl-flex">
            <div class="gl-flex gl-flex-col gl-gap-2">
              <div class="gl-font-bold">{{ messages.title }}</div>
              <div>{{ messages.content }}</div>
            </div>

            <div class="gl-mt-3 gl-flex gl-gap-3 sm:gl-mt-0">
              <gl-link
                :href="messages.learnMoreLink"
                target="_blank"
                class="gl-my-auto gl-mr-2 gl-min-w-12 !gl-text-current !gl-no-underline"
                data-testid="learn-more-link"
                @click="() => track('click_learn_more_link_on_project_card')"
              >
                {{ __('Learn more') }}
              </gl-link>

              <gl-button
                data-testid="upgrade-button"
                :href="upgradeUrl"
                @click="() => track('click_upgrade_button_on_project_card')"
              >
                <span>{{ __('Upgrade to Premium') }}</span>
              </gl-button>

              <div class="gl-flex gl-items-center">
                <gl-button
                  size="small"
                  category="tertiary"
                  class="!gl-p-0"
                  data-testid="dismiss-button"
                  @click="handleDismiss(dismiss)"
                >
                  <gl-icon name="close" />
                </gl-button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </template>
  </user-group-callout-dismisser>
</template>
