import { nextTick } from 'vue';
import { GlAlert, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getCookie, setCookie } from '~/lib/utils/common_utils';
import { DUO_AGENTIC_CHAT_LOGGING_ALERT } from 'ee/ai/constants';
import DuoChatLoggingAlert from 'ee/ai/components/duo_chat_logging_alert.vue';

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
  setCookie: jest.fn(),
}));

describe('DuoChatLoggingAlert', () => {
  let wrapper;

  const defaultProps = {
    metadata: { isTeamMember: true, extendedLogging: true },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoChatLoggingAlert, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    jest.clearAllMocks();
    getCookie.mockReturnValue(null);
  });

  describe('Alert visibility', () => {
    it('renders alert when user is team member, extended_logging is true, and alert is not dismissed', async () => {
      createComponent();
      await nextTick();

      expect(findAlert().exists()).toBe(true);
    });

    it('does not render alert when user is not a team member', () => {
      createComponent({
        metadata: { is_team_member: false, extended_logging: true },
      });

      expect(findAlert().exists()).toBe(false);
    });

    it('does not render alert when extended_logging is false', () => {
      createComponent({
        metadata: { is_team_member: true, extended_logging: false },
      });

      expect(findAlert().exists()).toBe(false);
    });

    it('does not render alert when extended_logging is undefined', () => {
      createComponent({
        metadata: { is_team_member: true },
      });

      expect(findAlert().exists()).toBe(false);
    });

    it('does not render alert when user is team member but alert was dismissed', () => {
      getCookie.mockReturnValue('true');
      createComponent();

      expect(findAlert().exists()).toBe(false);
    });

    it('does not render alert when metadata is undefined', () => {
      createComponent({ metadata: undefined });

      expect(findAlert().exists()).toBe(false);
    });

    it('does not render alert when metadata is null', () => {
      createComponent({ metadata: null });

      expect(findAlert().exists()).toBe(false);
    });

    it('does not render alert when metadata.is_team_member is undefined', () => {
      createComponent({
        metadata: { extended_logging: true },
      });

      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('Alert properties', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders alert with correct props', () => {
      const alert = findAlert();

      expect(alert.props()).toMatchObject({
        dismissible: true,
        variant: 'warning',
        title: 'GitLab Team Member Notice: Chat Logging Active',
        primaryButtonLink:
          'https://internal.gitlab.com/handbook/product/ai-strategy/duo-logging/#logging-duo-chat-usage-by-gitlab-team-members-without-logging-their-names-or-user-id',
        primaryButtonText: 'Learn more',
      });
    });

    it('renders alert with correct test attributes', () => {
      const alert = findAlert();

      expect(alert.attributes('role')).toBe('alert');
      expect(alert.attributes('data-testid')).toBe('duo-alert-logging');
    });

    it('renders alert content with all list items', () => {
      const alertText = findAlert().html();

      expect(alertText).toContain("What's logged:");
      expect(alertText).toContain('Which interfaces are affected:');
      expect(alertText).toContain('Privacy safeguards:');
      expect(alertText).toContain('Purpose:');
      expect(alertText).toContain('Customers are not affected:');
    });

    it('renders all GlSprintf components', () => {
      const sprintfComponents = wrapper.findAllComponents(GlSprintf);
      expect(sprintfComponents).toHaveLength(5);
    });
  });

  describe('Cookie initialization on mount', () => {
    it('reads cookie and sets isDismissed to true when cookie is "true"', () => {
      getCookie.mockReturnValue('true');
      createComponent();

      expect(getCookie).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_LOGGING_ALERT);
      expect(wrapper.vm.isDismissed).toBe(true);
      expect(findAlert().exists()).toBe(false);
    });

    it('reads cookie and sets isDismissed to false when cookie is null', async () => {
      createComponent();
      await nextTick();

      expect(getCookie).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_LOGGING_ALERT);
      expect(wrapper.vm.isDismissed).toBe(false);
      expect(findAlert().exists()).toBe(true);
    });

    it('reads cookie and sets isDismissed to false when cookie is not "true"', async () => {
      getCookie.mockReturnValue('false');
      createComponent();
      await nextTick();

      expect(getCookie).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_LOGGING_ALERT);
      expect(wrapper.vm.isDismissed).toBe(false);
      expect(findAlert().exists()).toBe(true);
    });
  });

  describe('Alert dismissal', () => {
    beforeEach(() => {
      createComponent();
    });

    it('sets cookie and updates isDismissed when alert is dismissed', async () => {
      const alert = findAlert();
      expect(alert.exists()).toBe(true);

      alert.vm.$emit('dismiss');
      await nextTick();

      expect(setCookie).toHaveBeenCalledWith(DUO_AGENTIC_CHAT_LOGGING_ALERT, true);
      expect(wrapper.vm.isDismissed).toBe(true);
      expect(findAlert().exists()).toBe(false);
    });

    it('calls onDismiss method when dismiss event is emitted', async () => {
      const onDismissSpy = jest.spyOn(DuoChatLoggingAlert.methods, 'onDismiss');
      createComponent();
      await nextTick();
      findAlert().vm.$emit('dismiss');
      await nextTick();

      expect(onDismissSpy).toHaveBeenCalled();

      onDismissSpy.mockRestore();
    });
  });

  describe('hasAlert computed property', () => {
    it.each`
      isTeamMember | extendedLogging | isDismissed | expected | scenario
      ${true}      | ${true}         | ${false}    | ${true}  | ${'shows when all conditions are met'}
      ${false}     | ${true}         | ${false}    | ${false} | ${'hides when not team member'}
      ${true}      | ${false}        | ${false}    | ${false} | ${'hides when extended_logging is false'}
      ${true}      | ${undefined}    | ${false}    | ${false} | ${'hides when extended_logging is undefined'}
      ${true}      | ${true}         | ${true}     | ${false} | ${'hides when dismissed'}
      ${undefined} | ${true}         | ${false}    | ${false} | ${'hides when is_team_member is undefined'}
    `('$scenario', async ({ isTeamMember, extendedLogging, isDismissed, expected }) => {
      getCookie.mockReturnValue(isDismissed ? 'true' : null);
      createComponent({
        metadata: {
          isTeamMember,
          extendedLogging,
        },
      });
      await nextTick();

      expect(findAlert().exists()).toBe(expected);
    });
  });

  describe('Props validation', () => {
    it('handles null metadata prop', () => {
      createComponent({ metadata: null });

      expect(() => wrapper.vm).not.toThrow();
      expect(findAlert().exists()).toBe(false);
    });

    it('handles undefined metadata prop', () => {
      createComponent({ metadata: undefined });

      expect(() => wrapper.vm).not.toThrow();
      expect(findAlert().exists()).toBe(false);
    });
  });
});
