<script>
import { GlButton, GlIcon } from '@gitlab/ui';
import { s__, __, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import axios from '~/lib/utils/axios_utils';
import { PROMO_URL } from '~/constants';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  name: 'DuoAgentPlatformWidget',
  components: {
    ConfirmActionModal,
    GlButton,
    GlIcon,
  },
  directives: {
    SafeHtml,
  },
  inject: {
    actionPath: { required: true },
    stateProgression: { required: true },
  },
  data() {
    return {
      showEnableDuoConfirmModal: false,
      currentState: this.stateProgression[0],
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
        ? s__('DuoAgentPlatform|Agent Platform On')
        : s__('DuoAgentPlatform|Agent Platform Off');
    },
    shouldShowBody() {
      return this.bodyText && this.shouldShowActions;
    },
    shouldShowActions() {
      return this.currentState !== 'enabled';
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
      return this.$options.i18n[this.currentState].modalBodyText();
    },
    actionParams() {
      if (this.currentState === 'enableFeaturePreview') {
        return { instance_level_ai_beta_features_enabled: true };
      }

      return { duo_availability: 'default_on', duo_core_features_enabled: true };
    },
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
    onEnableSuccess() {
      this.$toast.show(this.toastMessage);

      const currentIndex = this.stateProgression.indexOf(this.currentState);
      const nextIndex = (currentIndex + 1) % this.stateProgression.length;
      this.currentState = this.stateProgression[nextIndex];

      this.closeConfirmModal();
    },
    onEnableError(error) {
      this.closeConfirmModal();
      createAlert({
        message: s__('AiPowered|Failed to enable GitLab Duo Agent Platform.'),
        captureError: true,
        error,
      });
    },
  },
  learnMoreHref: helpPagePath('user/duo_agent_platform/_index'),
  i18n: {
    enabled: {
      modalBodyText() {
        return '';
      },
    },
    enablePlatform: {
      toastMessage: __('Duo Agent Platform is on'),
      modalTitle: s__('DuoAgentPlatform|Start using the Agent Platform'),
      modalBodyText() {
        const termsPath = `${PROMO_URL}/handbook/legal/ai-functionality-terms/`;
        const eligibilityPath = helpPagePath('subscriptions/subscription-add-ons', {
          anchor: 'gitlab-duo-core',
        });

        return sprintf(
          s__(
            `DuoAgentPlatform|%{pStart}Access GitLab Duo features throughout this instance by
            turning on the GitLab Duo Agent Platform.%{pEnd}
            %{pStart}When you turn it on, GitLab Duo will process your code and project data.
            Also, you accept the %{termsStart}GitLab AI Functionality Terms%{linkEnd},
            unless your organization has a separate agreement with GitLab governing AI feature usage.%{pEnd}
            %{pStart}Groups, subgroups, and projects can opt out as needed.
            Check the %{eligibilityStart}eligibility requirements%{linkEnd} for details.%{pEnd}`,
          ),
          {
            pStart: '<p>',
            pEnd: '</p>',
            termsStart: `<a href="${termsPath}" class="gl-link-inline" target="_blank" rel="noopener noreferrer">`,
            linkEnd: '</a>',
            eligibilityStart: `<a href="${eligibilityPath}" class="gl-link-inline" target="_blank" rel="noopener noreferrer">`,
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
  <div
    id="duo-agent-platform-sidebar-widget"
    class="gl-m-2 gl-bg-default gl-p-4"
    data-testid="duo-agent-platform-widget-root-element"
  >
    <div
      data-testid="duo-agent-platform-widget-menu"
      class="gl-flex gl-w-full gl-flex-col gl-items-stretch"
    >
      <div data-testid="widget-title" class="gl-text-md gl-flex gl-items-center">
        <gl-icon
          class="gl-mr-2 gl-block"
          :variant="iconVariant"
          name="status_created_borderless"
          :size="24"
        />
        <span class="gl-font-monospace">{{ title }}</span>
      </div>
      <p v-if="shouldShowBody" data-testid="widget-body" class="gl-my-3 gl-font-bold">
        {{ bodyText }}
      </p>
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
          class="gl-text-sm gl-no-underline hover:gl-no-underline"
          size="small"
          category="tertiary"
          variant="confirm"
          data-testid="learn-about-features-btn"
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
