import { GlModal, GlLoadingIcon, GlBadge } from '@gitlab/ui';
import { nextTick } from 'vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import DuoWorkflowSettings from 'ee/ai/settings/components/duo_workflow_settings.vue';
import axios from '~/lib/utils/axios_utils';
import { visitUrlWithAlerts } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/alert');
jest.mock('~/lib/utils/axios_utils');
jest.mock('~/lib/utils/url_utility');
jest.mock('~/helpers/help_page_helper');

describe('DuoWorkflowSettings', () => {
  let wrapper;

  const SERVICE_ACCOUNT = {
    id: 1,
    name: 'GitLab Duo',
    username: 'gitlab-duo',
    avatarUrl: '/avatar.png',
    webUrl: '/gitlab-duo',
  };

  const WORKFLOW_SETTINGS_PATH = '/admin/ai/duo_workflow_settings';
  const WORKFLOW_DISABLE_PATH = '/admin/ai/duo_workflow_settings/disconnect';
  const REDIRECT_PATH = '/admin/gitlab_duo';

  const findEnableButton = () => wrapper.findByTestId('enable-workflow-button');
  const findDisableButton = () => wrapper.findByTestId('disable-workflow-button');
  const findConfirmModal = () => wrapper.findComponent(GlModal);
  const findWorkflowStatusBadge = () => wrapper.findComponent(GlBadge);
  const findServiceAccount = () => wrapper.findByTestId('service-account');
  const findGlLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findPageHeadingTitle = () => wrapper.findByTestId('duo-settings-page-title');
  const findPageHeadingSubtitle = () => wrapper.findByTestId('duo-settings-page-subtitle');
  const findServiceAccountLink = () => wrapper.findByTestId('service-account-link');

  const createWrapper = (props = {}, provide = {}) => {
    const defaultMountOptions = {
      propsData: {
        ...props,
      },
      provide: {
        duoWorkflowEnabled: false,
        duoWorkflowServiceAccount: null,
        duoWorkflowSettingsPath: WORKFLOW_SETTINGS_PATH,
        duoWorkflowDisablePath: WORKFLOW_DISABLE_PATH,
        redirectPath: REDIRECT_PATH,
        ...provide,
      },
      stubs: {
        GlModal: true,
      },
    };

    wrapper = shallowMountExtended(DuoWorkflowSettings, defaultMountOptions);
  };

  beforeEach(() => {
    jest.clearAllMocks();

    axios.post = jest.fn().mockResolvedValue({ status: 200 });
    visitUrlWithAlerts.mockImplementation(() => {});
    helpPagePath.mockReturnValue('/help/user/duo_agent_platform/security');
  });

  describe('component rendering', () => {
    it('renders the component with default props when workflow is disabled', () => {
      createWrapper();

      expect(findEnableButton().exists()).toBe(true);
      expect(findDisableButton().exists()).toBe(false);
      expect(findWorkflowStatusBadge().text()).toBe('Off');
      expect(findWorkflowStatusBadge().props('variant')).toBe('neutral');
    });

    it('renders the component when workflow is enabled', () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: true,
          duoWorkflowServiceAccount: SERVICE_ACCOUNT,
        },
      );

      expect(findEnableButton().exists()).toBe(false);
      expect(findDisableButton().exists()).toBe(true);
      expect(findWorkflowStatusBadge().text()).toBe('On');
      expect(findWorkflowStatusBadge().props('variant')).toBe('success');
      expect(findServiceAccount().text()).toContain(SERVICE_ACCOUNT.name);
      expect(findServiceAccount().text()).toContain(SERVICE_ACCOUNT.username);
    });

    it('renders service account help link with correct href when workflow is disabled', () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: false,
        },
      );

      const link = findServiceAccountLink();
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe('/help/user/duo_agent_platform/security');
    });

    describe('displayPageHeading', () => {
      describe('when displayPageHeading is true', () => {
        it.each([
          {
            scenario: 'title and subtitle',
            props: { title: 'Test Title', subtitle: 'Test Subtitle' },
            expected: { heading: true, title: true, subtitle: true },
          },
          {
            scenario: 'title only',
            props: { title: 'Test Title' },
            expected: { heading: true, title: true, subtitle: false },
          },
          {
            scenario: 'subtitle only',
            props: { subtitle: 'Test Subtitle' },
            expected: { heading: true, title: false, subtitle: true },
          },
        ])('renders the page heading with $scenario', ({ props, expected }) => {
          createWrapper({
            displayPageHeading: true,
            ...props,
          });

          expect(findPageHeading().exists()).toBe(expected.heading);
          expect(findPageHeadingTitle().exists()).toBe(expected.title);
          expect(findPageHeadingSubtitle().exists()).toBe(expected.subtitle);
        });
      });

      describe('when displayPageHeading is false', () => {
        it.each([
          {
            scenario: 'title and subtitle provided',
            props: { title: 'Test Title', subtitle: 'Test Subtitle' },
          },
          {
            scenario: 'only title provided',
            props: { title: 'Test Title' },
          },
          {
            scenario: 'only subtitle provided',
            props: { subtitle: 'Test Subtitle' },
          },
        ])('does not render the page heading when $scenario', ({ props }) => {
          createWrapper({
            displayPageHeading: false,
            ...props,
          });

          expect(findPageHeading().exists()).toBe(false);
          expect(findPageHeadingTitle().exists()).toBe(false);
          expect(findPageHeadingSubtitle().exists()).toBe(false);
        });
      });
    });
  });

  describe('workflow operations', () => {
    describe('enabling composite identity for GitLab Duo Agent Platform', () => {
      it('shows success message with new service account when created', async () => {
        createWrapper();

        axios.post.mockResolvedValueOnce({
          status: 200,
          data: {
            service_account: SERVICE_ACCOUNT,
          },
        });

        findEnableButton().vm.$emit('click');

        expect(axios.post).toHaveBeenCalledWith(WORKFLOW_SETTINGS_PATH);

        await waitForPromises();

        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          REDIRECT_PATH,
          expect.arrayContaining([
            expect.objectContaining({
              id: 'duo-workflow-successfully-enabled',
              message: `Composite identity for GitLab Duo Agent Platform is now on for the instance and the service account (@${SERVICE_ACCOUNT.username}) was created. To use Agent Platform in your groups, you must turn on AI features for specific groups.`,
              variant: 'success',
            }),
          ]),
        );
      });

      it('shows generic success message when no service account info is available', async () => {
        createWrapper();

        axios.post.mockResolvedValueOnce({
          status: 200,
          data: {},
        });

        findEnableButton().vm.$emit('click');

        await waitForPromises();

        expect(visitUrlWithAlerts).toHaveBeenCalledWith(
          REDIRECT_PATH,
          expect.arrayContaining([
            expect.objectContaining({
              id: 'duo-workflow-successfully-enabled',
              message:
                'Composite identity for GitLab Duo Agent Platform is now on for the instance. To use Agent Platform in your groups, you must turn on AI features for specific groups.',
              variant: 'success',
            }),
          ]),
        );
      });
    });

    it('calls the disable workflow API and redirects with success alert', async () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: true,
          duoWorkflowServiceAccount: SERVICE_ACCOUNT,
        },
      );

      findConfirmModal().vm.$emit('primary');

      expect(axios.post).toHaveBeenCalledWith(WORKFLOW_DISABLE_PATH);

      await waitForPromises();

      expect(visitUrlWithAlerts).toHaveBeenCalledWith(
        REDIRECT_PATH,
        expect.arrayContaining([
          expect.objectContaining({
            id: 'duo-workflow-successfully-disabled',
            message:
              'Composite identity for GitLab Duo Agent Platform has successfully been turned off.',
            variant: 'success',
          }),
        ]),
      );
    });

    it('shows disable button when workflow is enabled', () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: true,
          duoWorkflowServiceAccount: SERVICE_ACCOUNT,
        },
      );
      expect(findDisableButton().text()).toContain(
        'Turn off composite identity for GitLab Duo Agent Platform',
      );
    });

    it('clicking disable button shows the confirmation modal', async () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: true,
          duoWorkflowServiceAccount: SERVICE_ACCOUNT,
        },
      );

      expect(findConfirmModal().props('visible')).toBe(false);

      findDisableButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmModal().props('visible')).toBe(true);
    });
  });

  describe('modal interactions', () => {
    it('shows and hides the confirmation modal', async () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: true,
          duoWorkflowServiceAccount: SERVICE_ACCOUNT,
        },
      );

      expect(findConfirmModal().props('visible')).toBe(false);

      findDisableButton().vm.$emit('click');
      await nextTick();

      expect(findConfirmModal().props('visible')).toBe(true);

      findConfirmModal().vm.$emit('cancel');
      await nextTick();

      expect(findConfirmModal().props('visible')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('handles enable workflow error', async () => {
      createWrapper();
      const error = new Error('API Error');
      axios.post.mockRejectedValueOnce(error);

      findEnableButton().vm.$emit('click');
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);

      await waitForPromises().catch(() => {});

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: expect.stringContaining(
            'Failed to enable composite identity for GitLab Duo Agent Platform',
          ),
          error,
        }),
      );
      expect(findGlLoadingIcon().exists()).toBe(false);
    });

    it('handles disable workflow error', async () => {
      createWrapper(
        {},
        {
          duoWorkflowEnabled: true,
          duoWorkflowServiceAccount: SERVICE_ACCOUNT,
        },
      );
      const error = new Error('API Error');
      axios.post.mockRejectedValueOnce(error);

      findConfirmModal().vm.$emit('primary');
      await nextTick();

      expect(findGlLoadingIcon().exists()).toBe(true);

      await waitForPromises().catch(() => {});

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: expect.stringContaining(
            'Failed to disable composite identity for GitLab Duo Agent Platform',
          ),
          error,
        }),
      );
      expect(findGlLoadingIcon().exists()).toBe(false);
    });
  });
});
