<script>
import { GlBadge, GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import axios from '~/lib/utils/axios_utils';
import { PROMO_URL } from '~/constants';
import SafeHtml from '~/vue_shared/directives/safe_html';
import { InternalEvents } from '~/tracking';

const trackingMixin = InternalEvents.mixin();

const LEARN_MORE_HREF = helpPagePath('subscriptions/subscription-add-ons', {
  anchor: 'gitlab-duo-core',
});

export default {
  name: 'DuoAgentPlatformWidget',
  components: {
    ConfirmActionModal,
    GlBadge,
    GlButton,
    GlIcon,
  },
  directives: {
    SafeHtml,
    GlTooltip: GlTooltipDirective,
  },
  mixins: [trackingMixin],
  inject: {
    actionPath: { required: true },
    stateProgression: { required: true },
    initialState: { required: true },
    contextualAttributes: { required: true },
  },
  data() {
    return {
      showEnableDuoConfirmModal: false,
      currentState: this.stateProgression[0],
      hasRequestedDuoPlatform: this.contextualAttributes.hasRequested,
      isAuthorized: this.contextualAttributes.isAuthorized,
      featurePreviewAttribute: this.contextualAttributes.featurePreviewAttribute,
      showRequestAccess: this.contextualAttributes.showRequestAccess,
      requestCount: this.contextualAttributes.requestCount,
      requestText: this.contextualAttributes.requestText,
      confirmModalFirstParagraphText: this.contextualAttributes.confirmModalFirstParagraphText,
    };
  },
  computed: {
    isEnabled() {
      return ['enabled', 'enableFeaturePreview'].includes(this.currentState);
    },
    iconVariant() {
      return this.isEnabled ? 'success' : 'disabled';
    },
    title() {
      return this.isEnabled
        ? s__('DuoAgentPlatform|GitLab Duo Core On')
        : s__('DuoAgentPlatform|GitLab Duo Core Off');
    },
    shouldShowBody() {
      return this.bodyText && this.shouldShowActions;
    },
    shouldShowActions() {
      return this.currentState !== 'enabled' && this.isAuthorized;
    },
    shouldShowSecondaryAction() {
      return this.currentState !== 'enableFeaturePreview';
    },
    openModalText() {
      if (this.currentState === 'enableFeaturePreview') {
        return __('Learn more');
      }

      return __('Turn on');
    },
    showActionsWithoutBody() {
      return this.shouldShowActions && !this.shouldShowBody;
    },
    bodyText() {
      return this.$options.i18n[this.currentState].bodyText;
    },
    toastMessage() {
      return this.$options.i18n[this.currentState].toastMessage;
    },
    modalTitle() {
      return this.$options.i18n[this.currentState].modalTitle;
    },
    modalBodyText() {
      return this.$options.i18n[this.currentState].modalBodyText(
        this.confirmModalFirstParagraphText,
      );
    },
    actionParams() {
      if (this.currentState === 'enableFeaturePreview') {
        return { [this.featurePreviewAttribute]: true };
      }

      return { duo_availability: 'default_on', duo_core_features_enabled: true };
    },
    showRequestSection() {
      return this.showRequestAccess && !this.isEnabled && !this.isAuthorized;
    },
    showRequestCounter() {
      return this.isAuthorized && this.requestCount > 0 && !this.isEnabled;
    },
  },
  mounted() {
    const label = this.isAuthorized ? `${this.initialState}_authorized` : this.initialState;

    this.trackEvent('render_duo_agent_platform_widget_in_sidebar', { label });
  },
  methods: {
    openConfirmModal() {
      this.showEnableDuoConfirmModal = true;
    },
    closeConfirmModal() {
      this.showEnableDuoConfirmModal = false;
    },
    async handleEnableAction() {
      try {
        await axios.put(this.actionPath, this.actionParams);
        this.onEnableSuccess();
      } catch (error) {
        this.onEnableError(error);
      }
    },
    async handleRequestAccess() {
      try {
        await axios.post(this.actionPath);
        this.onRequestSuccess();
      } catch (error) {
        createAlert({
          message: __('Failed to submit access request'),
          captureError: true,
          error,
        });
      }
    },
    onRequestSuccess() {
      this.hasRequestedDuoPlatform = true;
      this.$toast.show(this.requestText);
      this.trackEvent('click_request_in_duo_agent_platform_widget_in_sidebar');
    },
    onEnableSuccess() {
      this.$toast.show(this.toastMessage);
      this.trackEvent('click_turn_on_duo_agent_platform_widget_confirm_modal_in_sidebar', {
        label: this.currentState,
        value: this.requestCount,
      });

      const currentIndex = this.stateProgression.indexOf(this.currentState);
      const nextIndex = (currentIndex + 1) % this.stateProgression.length;
      this.currentState = this.stateProgression[nextIndex];

      this.closeConfirmModal();
    },
    onEnableError(error) {
      this.closeConfirmModal();
      createAlert({
        message: s__('AiPowered|Failed to enable GitLab Duo Core.'),
        captureError: true,
        error,
      });
    },
    trackLearnMoreClick(label) {
      this.trackEvent('click_learn_more_in_duo_agent_platform_widget_in_sidebar', {
        label,
      });
    },
    handleLearnMoreClick() {
      this.trackLearnMoreClick('authorized');
    },
    handleRequestLearnMoreClick() {
      this.trackLearnMoreClick('request');
    },
    handleRequestedLearnMoreClick() {
      this.trackLearnMoreClick('requested');
    },
    handleTeamRequestsHover() {
      this.trackEvent('hover_team_requests_in_duo_agent_platform_widget_in_sidebar');
    },
  },
  learnMoreHref: LEARN_MORE_HREF,
  i18n: {
    enabled: {
      modalBodyText() {
        return '';
      },
    },
    enablePlatform: {
      toastMessage: __('GitLab Duo Core is on'),
      modalTitle: s__('DuoAgentPlatform|Start using GitLab Duo Core'),
      modalBodyText(firstLine) {
        const termsPath = `${PROMO_URL}/handbook/legal/ai-functionality-terms/`;

        return sprintf(
          s__(
            `DuoAgentPlatform|%{pStart}%{firstLine}%{pEnd}
            %{pStart}When you turn it on, GitLab Duo will process your code and project data.
            Also, you accept the %{termsStart}GitLab AI Functionality Terms%{linkEnd},
            unless your organization has a separate agreement with GitLab governing AI feature usage.%{pEnd}
            %{pStart}Groups, subgroups, and projects can opt out as needed.
            Check the %{eligibilityStart}eligibility requirements%{linkEnd} for details.%{pEnd}`,
          ),
          {
            firstLine,
            pStart: '<p>',
            pEnd: '</p>',
            termsStart: `<a href="${termsPath}" class="gl-link-inline" target="_blank" rel="noopener noreferrer">`,
            linkEnd: '</a>',
            eligibilityStart: `<a href="${LEARN_MORE_HREF}" class="gl-link-inline" target="_blank" rel="noopener noreferrer">`,
          },
          false,
        );
      },
    },
    enableFeaturePreview: {
      bodyText: s__('DuoAgentPlatform|Access the latest GitLab Duo features'),
      toastMessage: __('Feature preview is on'),
      modalTitle: s__('DuoAgentPlatform|Turn on Feature Preview'),
      modalBodyText() {
        const testingTermsPath = `${PROMO_URL}/handbook/legal/testing-agreement/`;

        return sprintf(
          s__(
            `DuoAgentPlatform|%{pStart}Get early access to new GitLab Duo features before they're generally
            available. Help improve your development workflow and get started now.%{pEnd}
            By turning on these features, you accept the %{termsStart}GitLab Testing Agreement%{linkEnd}.`,
          ),
          {
            pStart: '<p>',
            pEnd: '</p>',
            termsStart: `<a href="${testingTermsPath}" class="gl-link-inline" target="_blank" rel="noopener noreferrer">`,
            linkEnd: '</a>',
          },
          false,
        );
      },
    },
  },
};
</script>

<template>
  <div id="duo-agent-platform-sidebar-widget" class="duo-agent-platform-sidebar-widget">
    <div data-testid="duo-agent-platform-widget-menu">
      <div data-testid="widget-title" class="-gl-ml-2 gl-flex gl-items-center gl-gap-2 gl-text-md">
        <gl-icon :variant="iconVariant" name="status_created_borderless" :size="24" />
        <span class="gl-font-monospace">{{ title }}</span>
      </div>
      <p v-if="shouldShowBody" data-testid="widget-body" class="gl-my-2 gl-font-bold">
        {{ bodyText }}
      </p>
      <div
        v-if="showRequestCounter"
        class="gl-my-2 gl-flex gl-items-center gl-justify-between gl-gap-3"
        data-testid="request-counter"
      >
        <span class="gl-text-secondary">
          {{ __('Team requests') }}
          <button
            v-gl-tooltip
            class="gl-border-0 gl-bg-transparent gl-p-0 gl-leading-0 gl-text-secondary"
            :title="requestText"
            :aria-label="requestText"
            data-testid="request-icon"
            @mouseenter="handleTeamRequestsHover"
          >
            <gl-icon name="question" />
          </button>
        </span>

        <span class="gl-text-secondary">
          {{ requestCount }}
        </span>
      </div>
      <div
        v-if="shouldShowActions"
        :class="[
          'gl-flex gl-w-full',
          shouldShowSecondaryAction ? 'gl-justify-between' : 'gl-justify-end',
          { 'gl-mt-3': showActionsWithoutBody },
        ]"
      >
        <gl-button
          v-if="shouldShowSecondaryAction"
          :href="$options.learnMoreHref"
          class="-gl-ml-3 gl-text-sm gl-no-underline hover:gl-no-underline"
          size="small"
          category="tertiary"
          variant="confirm"
          data-testid="learn-about-features-btn"
          @click.stop="handleLearnMoreClick"
        >
          {{ __('Learn more') }}
        </gl-button>

        <gl-button
          size="small"
          variant="confirm"
          data-testid="open-modal"
          @click="openConfirmModal"
        >
          {{ openModalText }}
        </gl-button>
      </div>

      <div
        v-if="showRequestSection"
        :class="['gl-flex gl-w-full gl-justify-between', { 'gl-mt-3': !shouldShowBody }]"
      >
        <template v-if="!hasRequestedDuoPlatform">
          <gl-button
            :href="$options.learnMoreHref"
            class="gl-text-sm"
            size="small"
            category="tertiary"
            variant="confirm"
            data-testid="learn-about-features-btn"
            @click.stop="handleRequestLearnMoreClick"
          >
            {{ __('Learn more') }}
          </gl-button>

          <gl-button
            size="small"
            variant="confirm"
            data-testid="request-access-btn"
            @click="handleRequestAccess"
          >
            {{ __('Request') }}
          </gl-button>
        </template>
        <div v-else class="gl-flex gl-w-full gl-justify-between">
          <gl-badge variant="neutral" class="gl-text-sm gl-text-secondary">
            {{ __('Requested') }}
          </gl-badge>

          <gl-button
            :href="$options.learnMoreHref"
            class="gl-text-sm gl-no-underline hover:gl-no-underline"
            size="small"
            variant="confirm"
            data-testid="learn-about-features-btn"
            @click.stop="handleRequestedLearnMoreClick"
          >
            {{ __('Learn more') }}
          </gl-button>
        </div>
      </div>
    </div>

    <confirm-action-modal
      v-if="showEnableDuoConfirmModal && shouldShowActions"
      modal-id="enable-duo-agentic-platform-modal"
      :title="modalTitle"
      :action-fn="handleEnableAction"
      :action-text="__('Turn on')"
      variant="confirm"
      @close="closeConfirmModal"
    >
      <div v-safe-html="modalBodyText"></div>
    </confirm-action-modal>
  </div>
</template>
