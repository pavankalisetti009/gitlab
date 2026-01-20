import { GlAlert } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import MockAdapter from 'axios-mock-adapter';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import Cookies from '~/lib/utils/cookies';
import { visitUrl } from '~/lib/utils/url_utility';
import axios from '~/lib/utils/axios_utils';
import LearnGitlab from 'ee/pages/projects/learn_gitlab/components/learn_gitlab.vue';
import eventHub from '~/invite_members/event_hub';
import { INVITE_MODAL_OPEN_COOKIE } from 'ee/pages/projects/learn_gitlab/constants';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import { createAlert, VARIANT_INFO } from '~/alert';
import { testActions, testSections, testProject } from './mock_data';

jest.mock('~/alert', () => ({
  ...jest.requireActual('~/alert'),
  createAlert: jest.fn().mockName('createAlertMock'),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  ...jest.requireActual('~/lib/utils/url_utility'),
  visitUrl: jest.fn().mockName('visitUrlMock'),
}));

describe('Learn GitLab', () => {
  let wrapper;

  const findEndTutorialButton = () => wrapper.findByTestId('end-tutorial-button');

  const createWrapper = () => {
    wrapper = extendedWrapper(
      mount(LearnGitlab, {
        propsData: {
          actions: testActions,
          sections: testSections,
          project: testProject,
          learnGitlabEndPath: '/group/project/-/learn-gitlab/end',
        },
      }),
    );
  };

  describe('Initial rendering concerns', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders correctly', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('End tutorial button', () => {
    let axiosMock;
    const errorMessage =
      'There was a problem trying to end the Learn GitLab tutorial. Please try again.';

    beforeEach(() => {
      axiosMock = new MockAdapter(axios);
      createWrapper();
    });

    afterEach(() => {
      axiosMock.restore();
    });

    it('should disable the button when clicked', async () => {
      findEndTutorialButton().vm.$emit('click');

      await nextTick();

      expect(findEndTutorialButton().attributes('disabled')).toBeDefined();
    });

    it('should call visitUrl with the correct link when clicked', async () => {
      const redirectPath = '/group/project';
      axiosMock.onPatch('/group/project/-/learn-gitlab/end').reply(200, {
        success: true,
        redirect_path: redirectPath,
      });

      findEndTutorialButton().vm.$emit('click');
      await waitForPromises();

      expect(visitUrl).toHaveBeenCalledWith(redirectPath);
    });

    it('should show alert when post request to end tutorial fails', async () => {
      axiosMock.onPatch('/group/project/-/learn-gitlab/end').reply(422, {
        success: false,
        message: errorMessage,
      });

      findEndTutorialButton().vm.$emit('click');
      await waitForPromises();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        variant: VARIANT_INFO,
      });
      expect(findEndTutorialButton().attributes('disabled')).not.toBeDefined();
    });

    it('should show alert when post request does not return success', async () => {
      axiosMock.onPatch('/group/project/-/learn-gitlab/end').reply(200, {
        success: false,
      });

      findEndTutorialButton().vm.$emit('click');
      await waitForPromises();

      expect(visitUrl).not.toHaveBeenCalled();
      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        variant: VARIANT_INFO,
      });
      expect(findEndTutorialButton().attributes('disabled')).not.toBeDefined();
    });
  });

  describe('Invite Members Modal', () => {
    let spy;
    let cookieSpy;

    beforeEach(() => {
      spy = jest.spyOn(eventHub, '$emit');
      cookieSpy = jest.spyOn(Cookies, 'remove');
    });

    afterEach(() => {
      Cookies.remove(INVITE_MODAL_OPEN_COOKIE);
    });

    it('emits open-modal', () => {
      Cookies.set(INVITE_MODAL_OPEN_COOKIE, true);

      createWrapper();

      expect(spy).toHaveBeenCalledWith('open-modal', {
        mode: 'celebrate',
        source: ON_CELEBRATION_TRACK_LABEL,
      });
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });

    it('does not emit open-modal when cookie is not set', () => {
      createWrapper();

      expect(spy).not.toHaveBeenCalled();
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });
  });

  describe('when the showSuccessfulInvitationsAlert event is fired', () => {
    const findAlert = () => wrapper.findComponent(GlAlert);

    beforeEach(() => {
      createWrapper();
      eventHub.$emit('showSuccessfulInvitationsAlert');
    });

    it('displays the successful invitations alert', () => {
      expect(findAlert().exists()).toBe(true);
    });

    it('displays a message with the project name', () => {
      expect(findAlert().text()).toBe(
        "Your team is growing! You've successfully invited new team members to the test-project project.",
      );
    });
  });
});
