import { shallowMount } from '@vue/test-utils';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlFormCheckbox, GlAlert } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { captureException } from '~/sentry/sentry_browser_wrapper';
import WebBasedCommitSigningCheckbox from 'ee/vue_shared/components/web_based_commit_signing/checkbox.vue';
import GroupInheritancePopover from '~/vue_shared/components/settings/group_inheritance_popover.vue';
import getWebBasedCommitSigningQuery from 'ee/graphql_shared/queries/web_based_commit_signing.query.graphql';

jest.mock('~/sentry/sentry_browser_wrapper', () => ({
  captureException: jest.fn(),
}));

Vue.use(VueApollo);

describe('WebBasedCommitSigningCheckbox', () => {
  let wrapper;
  let fakeApollo;

  const defaultProps = {
    hasGroupPermissions: false,
    groupSettingsRepositoryPath: '/groups/my-group/-/settings/repository',
    isGroupLevel: false,
    fullPath: 'gitlab-org/gitlab-test',
  };

  const webBasedCommitSigningSuccessResponse = (
    isGroupLevel,
    webBasedCommitSigningEnabled = false,
  ) => {
    if (isGroupLevel) {
      return {
        data: {
          group: {
            id: 'gid://gitlab/Group/1',
            webBasedCommitSigningEnabled,
          },
        },
      };
    }

    return {
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          group: {
            id: 'gid://gitlab/Group/1',
            webBasedCommitSigningEnabled,
          },
        },
      },
    };
  };

  const createComponent = (props = {}, queryHandler) => {
    const defaultQueryHandler =
      queryHandler ||
      jest
        .fn()
        .mockResolvedValue(
          webBasedCommitSigningSuccessResponse(props.isGroupLevel || false, false),
        );
    fakeApollo = createMockApollo([[getWebBasedCommitSigningQuery, defaultQueryHandler]]);

    wrapper = shallowMount(WebBasedCommitSigningCheckbox, {
      apolloProvider: fakeApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
      },
    });
  };

  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GroupInheritancePopover);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    fakeApollo = null;
  });

  describe('basic rendering', () => {
    it('renders the checkbox component', () => {
      expect(findCheckbox().exists()).toBe(true);
      expect(findCheckbox().text()).toContain('Sign web-based commits');
      expect(findCheckbox().text()).toContain(
        'Automatically sign commits made through the web interface.',
      );
      expect(findCheckbox().props('id')).toBe('web-based-commit-signing-checkbox');
    });

    it('renders popover with correct props', () => {
      expect(findPopover().exists()).toBe(true);
      expect(findPopover().props('hasGroupPermissions')).toBe(false);
      expect(findPopover().props('groupSettingsRepositoryPath')).toBe(
        '/groups/my-group/-/settings/repository',
      );
    });

    it('does not render alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
  });

  describe('when used on project level', () => {
    // TODO: Once projectSettings field is added to Project type, add tests for project-level setting
    describe('when group setting is false', () => {
      it('is unchecked', () => {
        expect(findCheckbox().props('checked')).toBe(false);
        expect(findCheckbox().props('disabled')).toBe(true);
      });
    });

    describe('when group setting is true (inheritance)', () => {
      it('is checked', async () => {
        createComponent(
          {},
          jest.fn().mockResolvedValue(webBasedCommitSigningSuccessResponse(false, true)),
        );
        await waitForPromises();
        expect(findCheckbox().props('checked')).toBe(true);
        expect(findCheckbox().props('disabled')).toBe(true);
      });
    });
  });

  describe('when used on group level', () => {
    describe('when group setting is false', () => {
      beforeEach(async () => {
        createComponent(
          { isGroupLevel: true },
          jest.fn().mockResolvedValue(webBasedCommitSigningSuccessResponse(true, false)),
        );
        await waitForPromises();
      });

      it('is unchecked', () => {
        expect(findCheckbox().props('checked')).toBe(false);
      });

      it('updates internal state when checkbox changes', async () => {
        await findCheckbox().vm.$emit('change', true);
        expect(findCheckbox().props('checked')).toBe(true);
      });
    });

    describe('when group setting is true', () => {
      beforeEach(async () => {
        createComponent(
          { isGroupLevel: true },
          jest.fn().mockResolvedValue(webBasedCommitSigningSuccessResponse(true, true)),
        );
        await waitForPromises();
      });

      it('is checked', () => {
        expect(findCheckbox().props('checked')).toBe(true);
      });
    });

    describe('GroupInheritancePopover', () => {
      beforeEach(async () => {
        createComponent(
          { isGroupLevel: true },
          jest.fn().mockResolvedValue(webBasedCommitSigningSuccessResponse(true, false)),
        );
        await waitForPromises();
      });

      it('does not render popover', () => {
        expect(findPopover().exists()).toBe(false);
      });
    });
  });

  describe('when query fails to load', () => {
    beforeEach(async () => {
      createComponent({ isGroupLevel: true }, jest.fn().mockRejectedValue('error'));
      await waitForPromises();
    });

    it('renders alert with error message', () => {
      expect(findAlert().exists()).toBe(true);
      expect(findAlert().props('variant')).toBe('danger');
      expect(findAlert().text()).toBe('An error occurred while updating the settings.');
    });

    it('should capture exceptions in Sentry', () => {
      expect(captureException).toHaveBeenCalledWith({
        error: expect.any(Error),
        component: 'WebBasedCommitSigningCheckbox',
      });
    });

    it('dismisses error when alert is dismissed', async () => {
      await findAlert().vm.$emit('dismiss');
      expect(wrapper.vm.errorMessage).toBe('');
    });
  });
});
