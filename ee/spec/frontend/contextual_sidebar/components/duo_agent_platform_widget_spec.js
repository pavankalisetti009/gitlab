import { GlIcon } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformWidget from 'ee/contextual_sidebar/components/duo_agent_platform_widget.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('~/alert');

describe('DuoAgentPlatformWidget component', () => {
  let wrapper;
  let mockAxios;
  const $toast = {
    show: jest.fn(),
  };

  const findWidgetTitle = () => wrapper.findByTestId('widget-title');
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLearnMoreButton = () => wrapper.findByTestId('learn-about-features-btn');
  const findActionButton = () => wrapper.findByTestId('open-modal');
  const findBody = () => wrapper.findByTestId('widget-body');
  const findConfirmModal = () => wrapper.findComponent(ConfirmActionModal);

  const defaultProvide = {
    actionPath: '/admin/application_settings/general',
    stateProgression: ['enablePlatform', 'enabled'],
    initialState: 'disabled',
    contextualAttributes: {
      isAuthorized: true,
      featurePreviewAttribute: 'instance_level_ai_beta_features_enabled',
    },
  };

  const createComponent = (provide = {}, contextualAttributes = {}) => {
    wrapper = shallowMountExtended(DuoAgentPlatformWidget, {
      provide: {
        ...defaultProvide,
        ...provide,
        contextualAttributes: {
          ...defaultProvide.contextualAttributes,
          ...contextualAttributes,
        },
      },
      mocks: {
        $toast,
      },
    });
  };

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  describe('rendered content', () => {
    describe('when agent platform is disabled', () => {
      beforeEach(() => {
        createComponent();
      });

      it('displays the correct title', () => {
        expect(findWidgetTitle().text()).toContain('GitLab Duo Core Off');
      });

      it('displays icon with disabled variant', () => {
        expect(findIcon().props('variant')).toBe('disabled');
      });

      it('shows action buttons when user is authorized', () => {
        expect(findLearnMoreButton().exists()).toBe(true);
        expect(findActionButton().exists()).toBe(true);
      });

      it('configures learn more button correctly', () => {
        expect(findLearnMoreButton().attributes('href')).toBe(
          '/help/subscriptions/subscription-add-ons#gitlab-duo-core',
        );
      });
    });

    describe('when core is enabled', () => {
      beforeEach(() => {
        createComponent({ stateProgression: ['enabled'] });
      });

      it('displays the correct title', () => {
        expect(findWidgetTitle().text()).toContain('GitLab Duo Core On');
      });

      it('displays icon with success variant', () => {
        expect(findIcon().props('variant')).toBe('success');
      });

      it('does not show action buttons when in enabled state', () => {
        expect(findLearnMoreButton().exists()).toBe(false);
        expect(findActionButton().exists()).toBe(false);
      });
    });

    describe('when user is not authorized', () => {
      beforeEach(() => {
        createComponent({}, { isAuthorized: false });
      });

      it('does not show authorized action buttons', () => {
        expect(findLearnMoreButton().exists()).toBe(false);
        expect(findActionButton().exists()).toBe(false);
      });
    });

    describe('with different state progressions', () => {
      it('shows actions for enablePlatform state when authorized', () => {
        createComponent({
          stateProgression: ['enablePlatform', 'enabled'],
          isAuthorized: true,
        });

        expect(findIcon().props('variant')).toBe('disabled');
        expect(findActionButton().text()).toBe('Turn on');
        expect(findLearnMoreButton().exists()).toBe(true);
      });

      it('shows actions for enableFeaturePreview state when authorized', () => {
        createComponent({
          stateProgression: ['enableFeaturePreview', 'enabled'],
          isAuthorized: true,
        });

        expect(findIcon().props('variant')).toBe('success');
        expect(findActionButton().text()).toBe('Learn more');
        expect(findLearnMoreButton().exists()).toBe(false);
      });

      it('does not show actions for enabled state', () => {
        createComponent({ stateProgression: ['enabled'] });

        expect(findActionButton().exists()).toBe(false);
        expect(findLearnMoreButton().exists()).toBe(false);
      });
    });
  });

  describe('modal interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not show modal initially', () => {
      expect(findConfirmModal().exists()).toBe(false);
    });

    it('shows modal when action button is clicked', async () => {
      await findActionButton().vm.$emit('click');

      expect(findConfirmModal().exists()).toBe(true);
    });

    it('closes modal when close event is emitted', async () => {
      await findActionButton().vm.$emit('click');
      expect(findConfirmModal().exists()).toBe(true);

      await findConfirmModal().vm.$emit('close');
      expect(findConfirmModal().exists()).toBe(false);
    });
  });

  describe('modal content generation', () => {
    describe('for enablePlatform state', () => {
      beforeEach(() => {
        createComponent({ stateProgression: ['enablePlatform', 'enabled'] });
      });

      it('configures modal with correct title', async () => {
        await findActionButton().vm.$emit('click');

        expect(findConfirmModal().props('title')).toBe('Start using GitLab Duo Core');
      });

      it('generates modal body text with links', async () => {
        await findActionButton().vm.$emit('click');

        const modalHtml = findConfirmModal().html();
        expect(modalHtml).toContain('Access GitLab Duo features throughout this instance');
        expect(modalHtml).toContain('/handbook/legal/ai-functionality-terms/');
        expect(modalHtml).toContain('GitLab AI Functionality Terms');
        expect(modalHtml).toContain('eligibility requirements');
      });
    });

    describe('for enableFeaturePreview state', () => {
      beforeEach(() => {
        createComponent({ stateProgression: ['enableFeaturePreview', 'enabled'] });
      });

      it('configures modal with correct title', async () => {
        await findActionButton().vm.$emit('click');

        expect(findConfirmModal().props('title')).toBe('Turn on Feature Preview');
      });

      it('generates modal body text with testing agreement link', async () => {
        await findActionButton().vm.$emit('click');

        const modalHtml = findConfirmModal().html();
        expect(modalHtml).toContain('Get early access to new GitLab Duo features');
        expect(modalHtml).toContain('By turning on these features, you accept the');
        expect(modalHtml).toContain('/handbook/legal/testing-agreement/');
        expect(modalHtml).toContain('GitLab Testing Agreement');
      });
    });
  });

  describe('enable action', () => {
    describe('enablePlatform state', () => {
      beforeEach(() => {
        createComponent({ stateProgression: ['enablePlatform', 'enabled'] });
        mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);
      });

      it('sends correct parameters for enablePlatform', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();

        expect(mockAxios.history.put[0].data).toBe(
          JSON.stringify({
            duo_availability: 'default_on',
            duo_core_features_enabled: true,
          }),
        );
      });

      it('progresses to next state after successful action', async () => {
        expect(findBody().exists()).toBe(false);
        expect(findActionButton().exists()).toBe(true);
        expect(findIcon().props('variant')).toBe('disabled');

        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect(findBody().exists()).toBe(false);
        expect(findActionButton().exists()).toBe(false);
        expect(findWidgetTitle().text()).toContain('GitLab Duo Core On');
        expect(findIcon().props('variant')).toBe('success');
        expect($toast.show).toHaveBeenCalledWith('GitLab Duo Core is on');
      });
    });

    describe('enableFeaturePreview state', () => {
      beforeEach(() => {
        createComponent({ stateProgression: ['enableFeaturePreview', 'enabled'] });
        mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);
      });

      it('sends correct parameters for enableFeaturePreview', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();

        expect(mockAxios.history.put[0].data).toBe(
          JSON.stringify({
            instance_level_ai_beta_features_enabled: true,
          }),
        );
      });

      it('uses featurePreviewAttribute from provide', async () => {
        createComponent(
          {
            stateProgression: ['enableFeaturePreview', 'enabled'],
          },
          { featurePreviewAttribute: 'experiment_features_enabled' },
        );
        mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);

        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();

        expect(mockAxios.history.put[0].data).toBe(
          JSON.stringify({
            experiment_features_enabled: true,
          }),
        );
      });

      it('shows correct toast message', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect($toast.show).toHaveBeenCalledWith('Feature preview is on');
      });
    });

    describe('when API call succeeds', () => {
      beforeEach(() => {
        createComponent();
        mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);
      });

      it('enables core and shows success toast', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect(findWidgetTitle().text()).toContain('GitLab Duo Core On');
        expect(findConfirmModal().exists()).toBe(false);
        expect($toast.show).toHaveBeenCalled();
      });

      it('updates UI to reflect enabled state', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect(findWidgetTitle().text()).toContain('GitLab Duo Core On');
        expect(findIcon().props('variant')).toBe('success');
      });
    });

    describe('when API call fails', () => {
      beforeEach(() => {
        createComponent();
        mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_BAD_REQUEST, {
          message: 'Failed to enable',
        });
      });

      it('shows error alert and closes modal', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Failed to enable GitLab Duo Core.',
          captureError: true,
          error: expect.any(Error),
        });
        expect(findWidgetTitle().text()).toContain('GitLab Duo Core Off');
        expect(findConfirmModal().exists()).toBe(false);
      });
    });
  });

  describe('request access functionality', () => {
    describe('when user can request access', () => {
      beforeEach(() => {
        createComponent(
          { actionPath: '/-/users/callouts/request_duo_agent_platform' },
          {
            isAuthorized: false,
            showRequestAccess: true,
            hasRequested: false,
          },
        );
      });

      it('shows request access section', () => {
        const requestSection = wrapper.find('[data-testid="request-access-btn"]');
        expect(requestSection.exists()).toBe(true);
      });

      it('handles successful request access', async () => {
        mockAxios.onPost('/-/users/callouts/request_duo_agent_platform').reply(HTTP_STATUS_OK);

        const requestBtn = wrapper.findByTestId('request-access-btn');
        await requestBtn.vm.$emit('click');
        await waitForPromises();

        expect($toast.show).toHaveBeenCalledWith('Request has been sent to the instance Admin');
      });
    });

    describe('when user has already requested access', () => {
      beforeEach(() => {
        createComponent(
          {},
          {
            isAuthorized: false,
            showRequestAccess: true,
            hasRequested: true,
          },
        );
      });

      it('shows access requested state', () => {
        expect(wrapper.text()).toContain('Requested');
      });
    });
  });

  describe('request counter for admins', () => {
    beforeEach(() => {
      createComponent(
        {},
        {
          isAuthorized: true,
          requestCount: 5,
        },
      );
    });

    it('shows request counter when admin has pending requests', () => {
      const counter = wrapper.findByTestId('request-counter');
      expect(counter.exists()).toBe(true);
      expect(counter.text()).toContain('Team requests');
      expect(counter.text()).toContain('5');
    });
  });

  describe('state progression logic', () => {
    it('handles multi-step progression correctly', async () => {
      createComponent({
        stateProgression: ['enablePlatform', 'enableFeaturePreview', 'enabled'],
      });
      mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);

      expect(findBody().exists()).toBe(false);

      await findActionButton().vm.$emit('click');
      await findConfirmModal().props('actionFn')();
      await waitForPromises();

      expect(findWidgetTitle().text()).toContain('GitLab Duo Core On');
      expect(findBody().exists()).toBe(true);
      expect(findActionButton().exists()).toBe(true);

      await findActionButton().vm.$emit('click');
      await findConfirmModal().props('actionFn')();
      await waitForPromises();

      expect(findBody().exists()).toBe(false);
      expect(findActionButton().exists()).toBe(false);
    });
  });

  describe('tracking', () => {
    const { bindInternalEventDocument } = useMockInternalEventsTracking();

    it('tracks widget render on authorized mount', () => {
      const { trackEventSpy } = bindInternalEventDocument(document);

      createComponent({ initialState: 'enabled' });

      expect(trackEventSpy).toHaveBeenCalledWith(
        'render_duo_agent_platform_widget_in_sidebar',
        {
          label: 'enabled_authorized',
        },
        undefined,
      );
    });

    it('tracks widget render on unauthorized mount', () => {
      const { trackEventSpy } = bindInternalEventDocument(document);

      createComponent({ initialState: 'enabled' }, { isAuthorized: false });

      expect(trackEventSpy).toHaveBeenCalledWith(
        'render_duo_agent_platform_widget_in_sidebar',
        {
          label: 'enabled',
        },
        undefined,
      );
    });

    it('tracks learn more button click', () => {
      createComponent();
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      trackEventSpy.mockClear();

      findLearnMoreButton().vm.$emit('click', { stopPropagation: jest.fn() });

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_more_in_duo_agent_platform_widget_in_sidebar',
        {},
        undefined,
      );
    });

    it('tracks successful enable action', async () => {
      createComponent();
      mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findActionButton().vm.$emit('click');
      await findConfirmModal().props('actionFn')();
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_turn_on_duo_agent_platform_widget_confirm_modal_in_sidebar',
        {
          label: 'enablePlatform',
        },
        undefined,
      );
    });

    it('tracks with different state labels', async () => {
      createComponent({ stateProgression: ['enableFeaturePreview', 'enabled'] });
      mockAxios.onPut('/admin/application_settings/general').reply(HTTP_STATUS_OK);
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findActionButton().vm.$emit('click');
      await findConfirmModal().props('actionFn')();
      await waitForPromises();

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_turn_on_duo_agent_platform_widget_confirm_modal_in_sidebar',
        {
          label: 'enableFeaturePreview',
        },
        undefined,
      );
    });
  });
});
