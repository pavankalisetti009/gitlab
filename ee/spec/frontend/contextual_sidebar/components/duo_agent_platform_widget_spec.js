import { GlIcon } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoAgentPlatformWidget from 'ee/contextual_sidebar/components/duo_agent_platform_widget.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_BAD_REQUEST } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';

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
  };

  const createComponent = (provide = {}) => {
    wrapper = shallowMountExtended(DuoAgentPlatformWidget, {
      provide: {
        ...defaultProvide,
        ...provide,
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
        expect(findWidgetTitle().text()).toContain('Agent Platform Off');
      });

      it('displays icon with disabled variant', () => {
        expect(findIcon().props('variant')).toBe('disabled');
      });

      it('shows action buttons', () => {
        expect(findLearnMoreButton().exists()).toBe(true);
        expect(findActionButton().exists()).toBe(true);
      });

      it('configures learn more button correctly', () => {
        expect(findLearnMoreButton().attributes('href')).toBe(
          '/help/user/duo_agent_platform/_index',
        );
      });
    });

    describe('when agent platform is enabled', () => {
      beforeEach(() => {
        createComponent({ stateProgression: ['enabled'] });
      });

      it('displays the correct title', () => {
        expect(findWidgetTitle().text()).toContain('Agent Platform On');
      });

      it('displays icon with success variant', () => {
        expect(findIcon().props('variant')).toBe('success');
      });

      it('does not show action buttons when in enabled state', () => {
        expect(findLearnMoreButton().exists()).toBe(false);
        expect(findActionButton().exists()).toBe(false);
      });
    });

    describe('with different state progressions', () => {
      it('shows actions for enablePlatform state', () => {
        createComponent({ stateProgression: ['enablePlatform', 'enabled'] });

        expect(findIcon().props('variant')).toBe('disabled');
        expect(findActionButton().exists()).toBe(true);
        expect(findLearnMoreButton().exists()).toBe(true);
      });

      it('shows actions for enableFeaturePreview state', () => {
        createComponent({ stateProgression: ['enableFeaturePreview', 'enabled'] });

        expect(findIcon().props('variant')).toBe('success');
        expect(findActionButton().exists()).toBe(true);
        expect(findLearnMoreButton().exists()).toBe(true);
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

        expect(findConfirmModal().props('title')).toBe('Start using the Agent Platform');
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
        expect(findWidgetTitle().text()).toContain('Agent Platform On');
        expect(findIcon().props('variant')).toBe('success');
        expect($toast.show).toHaveBeenCalledWith('Duo Agent Platform is on');
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

      it('enables agent platform and shows success toast', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect(findWidgetTitle().text()).toContain('Agent Platform On');
        expect(findConfirmModal().exists()).toBe(false);
        expect($toast.show).toHaveBeenCalled();
      });

      it('updates UI to reflect enabled state', async () => {
        await findActionButton().vm.$emit('click');
        await findConfirmModal().props('actionFn')();
        await waitForPromises();

        expect(findWidgetTitle().text()).toContain('Agent Platform On');
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
          message: 'Failed to enable GitLab Duo Agent Platform.',
          captureError: true,
          error: expect.any(Error),
        });
        expect(findWidgetTitle().text()).toContain('Agent Platform Off');
        expect(findConfirmModal().exists()).toBe(false);
      });
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

      expect(findWidgetTitle().text()).toContain('Agent Platform On');
      expect(findBody().exists()).toBe(true);
      expect(findActionButton().exists()).toBe(true);

      await findActionButton().vm.$emit('click');
      await findConfirmModal().props('actionFn')();
      await waitForPromises();

      expect(findBody().exists()).toBe(false);
      expect(findActionButton().exists()).toBe(false);
    });
  });
});
