import { GlButton, GlPopover, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import PremiumPlanHeader from 'ee/groups/billing/components/premium_plan_header.vue';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { mockBillingPageAttributes } from '../../mock_data';

jest.mock('~/super_sidebar/constants', () => ({
  duoChatGlobalState: {
    isShown: false,
    activeTab: null,
  },
}));

jest.mock('ee/ai/tanuki_bot/constants', () => ({
  CHAT_MODES: { CLASSIC: 'classic' },
}));

describe('PremiumPlanHeader', () => {
  let wrapper;
  const premiumFeatureId = 'duoChat';
  const findGlButton = () => wrapper.findByTestId('upgrade-link-cta');
  const content = () => wrapper.text().replace(/\s+/g, ' ');

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(PremiumPlanHeader, {
      propsData: { ...mockBillingPageAttributes, ...props },
      stubs: { GlSprintf },
    });
  };

  it('renders component', () => {
    createComponent();

    expect(content()).toContain('Get the most out of GitLab with Ultimate');
    expect(content()).toContain('Start an Ultimate trial with GitLab Duo Enterprise');
    expect(content()).toContain('No credit card required');

    const cta = findGlButton();

    expect(cta.attributes('data-event-tracking')).toBe('click_duo_enterprise_trial_billing_page');
    expect(cta.attributes('data-event-label')).toBe('ultimate_and_duo_enterprise_trial');
    expect(cta.props('href')).toBe(mockBillingPageAttributes.startTrialPath);
    expect(cta.text()).toBe('Start free trial');
  });

  it('does not render popovers', () => {
    createComponent();

    const popoverTarget = wrapper.find(`#${premiumFeatureId}`);
    expect(popoverTarget.exists()).toBe(false);
  });

  describe('when trial is active', () => {
    beforeEach(() => {
      global.window.gon = {
        features: {
          projectStudioEnabled: false,
        },
      };

      duoChatGlobalState.isShown = false;
      duoChatGlobalState.activeTab = null;

      createComponent({ trialActive: true, canAccessDuoChat: false });
    });

    it('renders trial active messaging', () => {
      expect(content()).toContain('Get the most from your trial ');
      expect(content()).toContain(
        'Explore these Premium features to optimize your GitLab experience.',
      );
      expect(content()).toContain('GitLab Duo');

      const cta = findGlButton();

      expect(cta.attributes('data-track-action')).toBe('click_button');
      expect(cta.attributes('data-track-label')).toBe('plan_cta');
      expect(cta.attributes('data-track-property')).toBe('premium');
      expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
      expect(cta.text()).toBe('Choose Premium');
    });

    it('renders postscript', () => {
      expect(content()).toContain(
        'Upgrade before your trial ends to maintain access to these Premium features.',
      );
    });

    describe('premium features popovers', () => {
      let trackingSpy;
      const { bindInternalEventDocument } = useMockInternalEventsTracking();

      beforeEach(() => {
        trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
        trackingSpy.mockClear();
      });

      it('renders all popovers and explore buttons', () => {
        const popovers = wrapper.findAllComponents(GlPopover);
        expect(popovers).toHaveLength(6);

        const buttons = wrapper.findAllComponents(GlButton);
        expect(buttons).toHaveLength(7); // explore buttons + upgrade CTA
      });

      it('shows a popover and tracks hover', () => {
        const popoverTarget = wrapper.find(`#${premiumFeatureId}`);
        expect(popoverTarget.exists()).toBe(true);

        const popover = wrapper.findComponent(GlPopover);
        expect(popover.props('target')).toBe(premiumFeatureId);
        expect(popover.props('title')).toBe('GitLab Duo');
        expect(popover.text()).toContain(
          'AI-powered features that help you write code, understand your work, and automate tasks across your workflow.',
        );

        popover.vm.$emit('shown');
        expect(trackingSpy).toHaveBeenCalledWith(
          'render_premium_feature_popover_on_billings',
          { property: premiumFeatureId },
          undefined,
        );
      });

      it('shows learn more and explore links in popover', () => {
        const popover = wrapper.findComponent(GlPopover);
        const link = popover.findComponent(GlLink);

        expect(link.attributes('href')).toContain('/user/gitlab_duo_chat');
        expect(link.text()).toBe('Learn more.');

        const exploreButton = popover.findComponent(GlButton);
        expect(exploreButton.attributes('href')).toBe(
          mockBillingPageAttributes.exploreLinks.duoChat,
        );
        expect(exploreButton.text()).toBe('Explore GitLab Duo');

        exploreButton.vm.$emit('click');
        expect(trackingSpy).toHaveBeenCalledWith(
          'click_cta_premium_feature_popover_on_billings',
          { property: premiumFeatureId },
          undefined,
        );
      });

      it('shows duo chat drawer if user can access', () => {
        createComponent({
          trialActive: true,
          exploreLinks: {
            ...mockBillingPageAttributes.exploreLinks,
            canAccessDuoChat: true,
            duoChat: null,
          },
        });

        expect(duoChatGlobalState.isShown).toBe(false);

        const popover = wrapper.findComponent(GlPopover);
        const exploreButton = popover.findComponent(GlButton);
        expect(exploreButton.attributes('href')).toBe(undefined);
        exploreButton.vm.$emit('click');

        expect(duoChatGlobalState.isShown).toBe(true);
        expect(duoChatGlobalState.focusChatInput).toBe(true);
      });

      it('shows duo chat panel if user can access', () => {
        window.gon.features.projectStudioEnabled = true;

        createComponent({
          trialActive: true,
          exploreLinks: {
            ...mockBillingPageAttributes.exploreLinks,
            canAccessDuoChat: true,
            duoChat: null,
          },
        });

        expect(duoChatGlobalState.activeTab).toBe(null);

        const popover = wrapper.findComponent(GlPopover);
        const exploreButton = popover.findComponent(GlButton);
        expect(exploreButton.attributes('href')).toBe(undefined);

        exploreButton.vm.$emit('click');

        // active tab gets set to "new" and then converts to "chat" for the end state
        expect(duoChatGlobalState.activeTab).toBe('chat');
        expect(duoChatGlobalState.focusChatInput).toBe(true);
      });
    });

    it('does not show explore button if nil href unless feature is duochat', () => {
      createComponent({
        trialActive: true,
        exploreLinks: {
          duoChat: null,
          mergeTrains: null,
          epics: null,
          escalationPolicies: null,
        },
      });

      const buttons = wrapper.findAllComponents(GlButton);
      expect(buttons).toHaveLength(2); // duo chat + upgrade CTA
    });
  });

  describe('when trial is expired', () => {
    beforeEach(() => {
      createComponent({ trialExpired: true });
    });

    it('renders trial expired messaging', () => {
      expect(content()).toContain('Level up with Premium');
      expect(content()).toContain('Upgrade and unlock advanced features');
      expect(content()).toContain('Team Project Management');

      const cta = findGlButton();

      expect(cta.attributes('data-track-action')).toBe('click_button');
      expect(cta.attributes('data-track-label')).toBe('plan_cta');
      expect(cta.attributes('data-track-property')).toBe('premium');
      expect(cta.props('href')).toBe(mockBillingPageAttributes.upgradeToPremiumUrl);
      expect(cta.text()).toBe('Upgrade to Premium');
    });

    it('does not render popovers', () => {
      const popoverTarget = wrapper.find(`#${premiumFeatureId}`);
      expect(popoverTarget.exists()).toBe(false);
    });
  });
});
