import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TestMavenUpstreamButton from 'ee/packages_and_registries/virtual_registries/components/maven/shared/test_maven_upstream_button.vue';
import {
  testMavenUpstream,
  testExistingMavenUpstreamWithOverrides,
} from 'ee/api/virtual_registries_api';
import waitForPromises from 'helpers/wait_for_promises';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';

jest.mock('ee/api/virtual_registries_api');
jest.mock('ee/packages_and_registries/virtual_registries/sentry_utils');

describe('TestMavenUpstreamButton', () => {
  let wrapper;

  const defaultProps = {
    url: 'https://gitlab.com',
  };

  const findTestUpstreamButton = () => wrapper.findComponent(GlButton);

  const showToastSpy = jest.fn();

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(TestMavenUpstreamButton, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: {
        ...provide,
      },
      mocks: {
        $toast: {
          show: showToastSpy,
        },
      },
    });
  };

  const testSuccessResponse = { data: { success: true } };
  const testErrorResponse = { response: { status: 400, data: { message: { url: 'is blocked' } } } };
  const testFailureResponse = { data: { success: false, result: 'message' } };

  describe('default', () => {
    beforeEach(() => {
      testMavenUpstream.mockResolvedValue(testSuccessResponse);
      createComponent({
        provide: {
          groupPath: 'full-path',
        },
      });
    });

    it('renders GlButton', () => {
      expect(findTestUpstreamButton().props('disabled')).toBe(false);
      expect(findTestUpstreamButton().props('loading')).toBe(false);
      expect(findTestUpstreamButton().text()).toBe('Test upstream');
    });

    it('on click calls testMavenUpstream API', async () => {
      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testMavenUpstream).toHaveBeenCalledWith({
        id: 'full-path',
        url: defaultProps.url,
        username: '',
        password: '',
      });

      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    describe('when testMavenUpstream fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        testMavenUpstream.mockRejectedValue(mockError);
        createComponent();

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect.');
        expect(captureException).toHaveBeenCalledWith({
          error: mockError,
          name: 'TestMavenUpstreamButton',
        });
      });

      it('shows toast with message from API and does not report error to Sentry', async () => {
        testMavenUpstream.mockResolvedValue(testFailureResponse);
        createComponent();

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect message');
        expect(captureException).not.toHaveBeenCalled();
      });

      it('shows toast with error message from API & does not report error to Sentry', async () => {
        testMavenUpstream.mockRejectedValue(testErrorResponse);
        createComponent();

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect url is blocked');
        expect(captureException).not.toHaveBeenCalled();
      });
    });
  });

  describe('when upstreamId is provided', () => {
    beforeEach(() => {
      testExistingMavenUpstreamWithOverrides.mockResolvedValue(testSuccessResponse);
      createComponent({
        props: { upstreamId: 1 },
      });
    });

    it('on click calls testExistingMavenUpstreamWithOverrides API with overrides', async () => {
      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testExistingMavenUpstreamWithOverrides).toHaveBeenCalledWith({
        id: 1,
        url: defaultProps.url,
        username: '',
        password: '',
      });
      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    it('passes username and password overrides when provided', async () => {
      createComponent({
        props: {
          upstreamId: 1,
          url: defaultProps.url,
          username: 'test-user',
          password: 'test-password',
        },
      });

      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testExistingMavenUpstreamWithOverrides).toHaveBeenCalledWith({
        id: 1,
        url: defaultProps.url,
        username: 'test-user',
        password: 'test-password',
      });
    });

    it('calls API with only upstreamId when no overrides are provided (link existing upstream modal)', async () => {
      createComponent({
        props: {
          upstreamId: 1,
          url: '',
          username: '',
          password: '',
        },
      });

      findTestUpstreamButton().vm.$emit('click');

      await waitForPromises();

      expect(testExistingMavenUpstreamWithOverrides).toHaveBeenCalledWith({
        id: 1,
        url: '',
        username: '',
        password: '',
      });
      expect(showToastSpy).toHaveBeenCalledWith('Connection successful.');
    });

    describe('when testExistingMavenUpstreamWithOverrides fails', () => {
      it('shows toast with default message & reports error to Sentry', async () => {
        const mockError = new Error();
        testExistingMavenUpstreamWithOverrides.mockRejectedValue(mockError);
        createComponent({
          props: { upstreamId: 1 },
        });

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect.');
        expect(captureException).toHaveBeenCalledWith({
          error: mockError,
          name: 'TestMavenUpstreamButton',
        });
      });

      it('shows toast with message from API and does not report error to Sentry', async () => {
        testExistingMavenUpstreamWithOverrides.mockResolvedValue(testFailureResponse);
        createComponent({
          props: { upstreamId: 1 },
        });

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect message');
        expect(captureException).not.toHaveBeenCalled();
      });

      it('shows toast with error message from API and does not report error to Sentry', async () => {
        testExistingMavenUpstreamWithOverrides.mockRejectedValue(testErrorResponse);
        createComponent({
          props: { upstreamId: 1 },
        });

        findTestUpstreamButton().vm.$emit('click');

        await waitForPromises();

        expect(showToastSpy).toHaveBeenCalledWith('Failed to connect url is blocked');
        expect(captureException).not.toHaveBeenCalled();
      });
    });
  });
});
