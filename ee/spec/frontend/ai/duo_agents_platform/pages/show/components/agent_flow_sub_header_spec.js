import { shallowMount } from '@vue/test-utils';
import { GlSkeletonLoader, GlAvatarLink, GlAvatar } from '@gitlab/ui';
import AgentFlowSubHeader from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_sub_header.vue';
import { getUser } from '~/api/user_api';
import waitForPromises from 'helpers/wait_for_promises';
import { getBinding, createMockDirective } from 'helpers/vue_mock_directive';

jest.mock('~/api/user_api');

describe('AgentFlowSubHeader', () => {
  let wrapper;

  const mockUser = {
    id: 123,
    username: 'testuser',
    name: 'Test User',
    web_url: 'https://gitlab.com/testuser',
    avatar_url: 'https://gitlab.com/uploads/user/avatar/123/avatar.png',
  };

  const defaultProps = {
    isLoading: false,
    agentFlowDefinition: 'Software development',
    createdAt: '2024-01-01T00:00:00Z',
    userId: 'gid://gitlab/User/123',
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AgentFlowSubHeader, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findAvatarLinks = () => wrapper.findAllComponents(GlAvatarLink);
  const findUsernameLink = () => findAvatarLinks().at(1);
  const findAvatar = () => wrapper.findComponent(GlAvatar);

  beforeEach(() => {
    getUser.mockResolvedValue({ data: mockUser });
  });

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper({ isLoading: true });
    });

    it('renders skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
      expect(findSkeletonLoader().attributes('lines')).toBe('1');
      expect(findSkeletonLoader().attributes('width')).toBe('400');
    });

    it('does not render user information', () => {
      expect(findAvatarLinks()).toHaveLength(0);
      expect(findAvatar().exists()).toBe(false);
    });
  });

  describe('when session has loaded', () => {
    describe('with valid userId', () => {
      beforeEach(async () => {
        createWrapper();
        await waitForPromises();
      });

      it('does not render skeleton loader', () => {
        expect(findSkeletonLoader().exists()).toBe(false);
      });

      it('fetches user data with numeric ID', () => {
        expect(getUser).toHaveBeenCalledWith(123);
      });

      it('renders user avatar', () => {
        expect(findAvatar().exists()).toBe(true);
        expect(findAvatar().props()).toMatchObject({
          src: mockUser.avatar_url,
          entityName: mockUser.username,
          alt: mockUser.name,
          size: 32,
        });
      });

      it('renders avatar links with correct props', () => {
        const avatarLinks = findAvatarLinks();
        expect(avatarLinks).toHaveLength(2);

        avatarLinks.wrappers.forEach((link) => {
          expect(link.attributes('href')).toBe(mockUser.web_url);
          expect(link.attributes('data-user-id')).toBe('123');
          expect(link.attributes('data-username')).toBe(mockUser.username);
        });
      });

      it('renders username', () => {
        expect(wrapper.text()).toContain(`@${mockUser.username}`);
      });

      it('renders username link with tooltip', () => {
        const usernameLink = findUsernameLink();
        const tooltip = getBinding(usernameLink.element, 'gl-tooltip');

        expect(tooltip).toBeDefined();
        expect(tooltip.modifiers.bottom).toBe(true);
        expect(usernameLink.attributes('title')).toBe(mockUser.name);
      });

      it('renders agent flow definition', () => {
        expect(wrapper.text()).toContain('Software development');
      });

      it('renders formatted date', () => {
        expect(wrapper.text()).toContain('Jan 1, 2024');
      });
    });

    describe('with numeric userId', () => {
      beforeEach(async () => {
        createWrapper({ userId: '456' });
        await waitForPromises();
      });

      it('fetches user data with the numeric ID directly', () => {
        expect(getUser).toHaveBeenCalledWith('456');
      });

      it('renders user information', () => {
        expect(findAvatar().exists()).toBe(true);
      });
    });

    describe('without userId', () => {
      beforeEach(() => {
        createWrapper({ userId: '' });
      });

      it('does not fetch user data', () => {
        expect(getUser).not.toHaveBeenCalled();
      });

      it('renders the component with empty user data', () => {
        expect(wrapper.text()).toContain('Triggered');
        expect(wrapper.text()).toContain('Software development');
      });

      it('renders triggered span with lowercase class', () => {
        const triggeredSpan = wrapper.find('.gl-lowercase');
        expect(triggeredSpan.exists()).toBe(true);
        expect(triggeredSpan.text()).toBe('Triggered');
      });
    });

    describe('when user fetch fails', () => {
      beforeEach(async () => {
        getUser.mockRejectedValue(new Error('Network error'));
        createWrapper();
        await waitForPromises();
      });

      it('renders component with empty user data', () => {
        expect(findAvatar().props('src')).toBe('');
        expect(findAvatar().props('entityName')).toBe('');
      });
    });

    describe('when userId changes', () => {
      beforeEach(async () => {
        createWrapper();
        await waitForPromises();
        jest.clearAllMocks();
      });

      it('fetches new user data when userId changes', async () => {
        await wrapper.setProps({ userId: 'gid://gitlab/User/789' });
        await waitForPromises();

        expect(getUser).toHaveBeenCalledWith(789);
      });

      it('does not fetch when userId changes to empty', async () => {
        await wrapper.setProps({ userId: '' });
        await waitForPromises();

        expect(getUser).not.toHaveBeenCalled();
      });
    });
  });
});
