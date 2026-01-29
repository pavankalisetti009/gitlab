import { GlModal, GlSprintf, GlPopover, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import { makeMockUserGroupCalloutDismisser } from 'helpers/mock_user_group_callout_dismisser';
import EndOfTrialModal from 'ee/end_of_trial/components/end_of_trial_modal.vue';
import UserGroupCalloutDismisser from '~/vue_shared/components/user_group_callout_dismisser.vue';

describe('EndOfTrialModal', () => {
  let wrapper;
  let userGroupCalloutDismissSpy;
  const premiumFeatureId = 'duoChat';

  const propsData = {
    featureName: 'test-feature',
    groupId: 1,
    groupName: 'Test group',
    explorePlansPath: '/explore',
    upgradeUrl: '/upgrade',
    isNewTrialType: false,
  };

  const createComponent = () => {
    userGroupCalloutDismissSpy = jest.fn();

    wrapper = shallowMountExtended(EndOfTrialModal, {
      propsData,
      stubs: {
        GlModal,
        GlSprintf,
        UserGroupCalloutDismisser: makeMockUserGroupCalloutDismisser({
          dismiss: userGroupCalloutDismissSpy,
        }),
      },
    });
  };

  const findGlModal = () => wrapper.findComponent(GlModal);
  const findUserGroupCalloutDismisser = () => wrapper.findComponent(UserGroupCalloutDismisser);
  const findUpgradeButton = () => wrapper.findByText('Upgrade to Premium');
  const findExplorePlansButton = () => wrapper.findByText('Explore plans');

  afterEach(() => {
    sessionStorage.clear();
  });

  it('passes correct attributes to UserGroupCalloutDismisser', () => {
    createComponent();

    expect(findUserGroupCalloutDismisser().props()).toMatchObject({
      featureName: 'test-feature',
      groupId: 1,
      skipQuery: true,
    });
  });

  it('renders component', () => {
    createComponent();

    const content = wrapper.text();

    expect(content).toContain('Your trial has ended');

    expect(content).toContain(
      'Upgrade Test group to Premium to maintain access to advanced features and keep your workflow running smoothly.',
    );

    expect(content).toContain('Source Code Management & CI/CD');
    expect(findUpgradeButton().attributes('href')).toBe('/upgrade');
    expect(findExplorePlansButton().attributes('href')).toBe('/explore');
  });

  describe('premium features popovers', () => {
    describe('with isNewTrialType false', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders all popovers and learn more buttons', () => {
        const popovers = wrapper.findAllComponents(GlPopover);
        expect(popovers).toHaveLength(6);

        const buttons = wrapper.findAllByText('Learn more');
        expect(buttons).toHaveLength(6);
      });

      it('renders correct popover with DUE copy', () => {
        const popover = wrapper.findComponent(GlPopover);

        expect(popover.props('target')).toBe(`${premiumFeatureId}EndOfTrialModal`);
        expect(popover.props('title')).toBe('GitLab Duo');

        expect(popover.text()).toContain(
          'AI-powered features that help you write code, understand your work, and automate tasks across your workflow.',
        );
      });
    });

    describe('with isNewTrialType true', () => {
      beforeEach(() => {
        wrapper = shallowMountExtended(EndOfTrialModal, {
          propsData: { ...propsData, isNewTrialType: true },
          stubs: {
            GlModal,
            GlSprintf,
            UserGroupCalloutDismisser: makeMockUserGroupCalloutDismisser({
              dismiss: jest.fn(),
            }),
          },
        });
      });

      it('renders correct popover with DAP copy', () => {
        const popover = wrapper.findComponent(GlPopover);

        expect(popover.props('target')).toBe(`${premiumFeatureId}EndOfTrialModal`);
        expect(popover.props('title')).toBe('GitLab Duo Agent Platform');

        expect(popover.text()).toContain(
          'AI agents and automated flows that work alongside you to answer complex questions, automate tasks, and streamline development. Use pre-built options or create custom agents and flows for your team.',
        );

        expect(wrapper.findByText('Learn more').attributes('href')).toContain(
          '/user/duo_agent_platform',
        );
      });
    });
  });

  describe('with tracking', () => {
    let trackingSpy;
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    beforeEach(() => {
      createComponent();
      trackingSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
      trackingSpy.mockClear();
    });

    it('tracks render event', () => {
      findGlModal().vm.$emit('show');

      expect(trackingSpy).toHaveBeenCalledWith('render_end_of_trial_modal', {}, undefined);
    });

    it('tracks click upgrade event', () => {
      findGlModal().vm.$emit('primary');

      expect(trackingSpy).toHaveBeenCalledWith('click_upgrade_end_of_trial_modal', {}, undefined);
    });

    it('tracks click explore plans event', () => {
      findGlModal().vm.$emit('cancel');

      expect(trackingSpy).toHaveBeenCalledWith('click_explore_end_of_trial_modal', {}, undefined);
    });

    it('tracks dismiss event', () => {
      findGlModal().vm.$emit('close');

      expect(trackingSpy).toHaveBeenCalledWith('dismiss_end_of_trial_modal', {}, undefined);
    });

    it('tracks click outside modal event', () => {
      findGlModal().vm.$emit('hide', { trigger: 'backdrop' });

      expect(trackingSpy).toHaveBeenCalledWith('dismiss_outside_end_of_trial_modal', {}, undefined);
    });

    it('tracks esc event', () => {
      findGlModal().vm.$emit('hide', { trigger: 'esc' });

      expect(trackingSpy).toHaveBeenCalledWith('dismiss_esc_end_of_trial_modal', {}, undefined);
    });

    it('tracks popover hover event', () => {
      wrapper.findComponent(GlPopover).vm.$emit('shown');

      expect(trackingSpy).toHaveBeenCalledWith(
        'render_premium_feature_popover_end_of_trial_modal',
        { property: premiumFeatureId },
        undefined,
      );
    });

    it('tracks click learn more event', () => {
      wrapper.findComponent(GlPopover).findComponent(GlButton).vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledWith(
        'click_cta_premium_feature_popover_end_of_trial_modal',
        { property: premiumFeatureId },
        undefined,
      );
    });
  });
});
