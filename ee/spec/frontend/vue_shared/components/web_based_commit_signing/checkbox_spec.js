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
import updateGroupWebBasedCommitSigningMutation from 'ee/graphql_shared/mutations/update_group_web_based_commit_signing.mutation.graphql';

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

  const createComponent = (props = {}, queryHandler, mutationHandler) => {
    const defaultQueryHandler =
      queryHandler ||
      jest
        .fn()
        .mockResolvedValue(
          webBasedCommitSigningSuccessResponse(props.isGroupLevel || false, false),
        );
    const defaultMutationHandler =
      mutationHandler ||
      jest.fn().mockResolvedValue({
        data: {
          groupUpdate: {
            group: {
              id: 'gid://gitlab/Group/1',
              webBasedCommitSigningEnabled: true,
            },
            errors: [],
          },
        },
      });
    fakeApollo = createMockApollo([
      [getWebBasedCommitSigningQuery, defaultQueryHandler],
      [updateGroupWebBasedCommitSigningMutation, defaultMutationHandler],
    ]);

    wrapper = shallowMount(WebBasedCommitSigningCheckbox, {
      apolloProvider: fakeApollo,
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlFormCheckbox,
      },
      mocks: {
        $toast: {
          show: jest.fn(),
        },
      },
    });
  };

  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findPopover = () => wrapper.findComponent(GroupInheritancePopover);
  const findAlert = () => wrapper.findComponent(GlAlert);

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
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
    describe('loading state', () => {
      it('is disabled while query is loading', async () => {
        createComponent(
          { isGroupLevel: true },
          jest.fn().mockResolvedValue(webBasedCommitSigningSuccessResponse(true, false)),
        );

        expect(findCheckbox().props('disabled')).toBe(true);

        await waitForPromises();

        expect(findCheckbox().props('disabled')).toBe(false);
      });
    });

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

      it('does not render popover', () => {
        expect(findPopover().exists()).toBe(false);
      });

      describe('mutation', () => {
        it('updates the checkbox value when succeeds', async () => {
          expect(findCheckbox().props('checked')).toBe(false);

          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(findCheckbox().props('checked')).toBe(true);
        });

        it('shows "enabled" toast when enabling', async () => {
          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Web-based commit signing enabled');
        });

        it('shows "disabled" toast when disabling', async () => {
          // First enable it
          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();
          wrapper.vm.$toast.show.mockClear();

          // Then disable it
          await findCheckbox().vm.$emit('change', false);
          await waitForPromises();

          expect(wrapper.vm.$toast.show).toHaveBeenCalledWith('Web-based commit signing disabled');
        });
      });
    });

    describe('mutation failures', () => {
      describe('when mutation fails', () => {
        beforeEach(async () => {
          const mutationHandler = jest.fn().mockRejectedValue('error');

          createComponent(
            { isGroupLevel: true, fullPath: 'flightjs' },
            jest.fn().mockResolvedValue(webBasedCommitSigningSuccessResponse(true, false)),
            mutationHandler,
          );
          await waitForPromises();
        });

        it('reverts the checkbox value and shows error', async () => {
          expect(findCheckbox().props('checked')).toBe(false);

          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(findCheckbox().props('checked')).toBe(false);
          expect(findAlert().exists()).toBe(true);
          expect(findAlert().text()).toBe('An error occurred while updating the settings.');
        });

        it('calls Sentry for mutation failures', async () => {
          captureException.mockClear();

          await findCheckbox().vm.$emit('change', true);
          await waitForPromises();

          expect(captureException).toHaveBeenCalledWith({
            error: expect.any(Error),
            component: 'WebBasedCommitSigningCheckbox',
          });
        });
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
      expect(findAlert().text()).toBe('An error occurred while loading the settings.');
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
