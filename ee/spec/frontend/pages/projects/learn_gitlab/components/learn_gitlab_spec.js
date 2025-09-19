import { GlAlert } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import Cookies from '~/lib/utils/cookies';
import { visitUrl } from '~/lib/utils/url_utility';
import LearnGitlab from 'ee/pages/projects/learn_gitlab/components/learn_gitlab.vue';
import eventHub from '~/invite_members/event_hub';
import { INVITE_MODAL_OPEN_COOKIE } from 'ee/pages/projects/learn_gitlab/constants';
import { ON_CELEBRATION_TRACK_LABEL } from '~/invite_members/constants';
import { testActions, testSections, testProject } from './mock_data';

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
    beforeEach(() => {
      createWrapper();
    });

    it('should disable the button when clicked', async () => {
      findEndTutorialButton().vm.$emit('click');

      await nextTick();

      expect(findEndTutorialButton().attributes('disabled')).toBeDefined();
    });

    it('should call visitUrl with the correct link when clicked', () => {
      findEndTutorialButton().vm.$emit('click');

      expect(visitUrl).toHaveBeenCalledWith('/group/project/-/learn-gitlab/end');
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

    it('emits openModal', () => {
      Cookies.set(INVITE_MODAL_OPEN_COOKIE, true);

      createWrapper();

      expect(spy).toHaveBeenCalledWith('openModal', {
        mode: 'celebrate',
        source: ON_CELEBRATION_TRACK_LABEL,
      });
      expect(cookieSpy).toHaveBeenCalledWith(INVITE_MODAL_OPEN_COOKIE);
    });

    it('does not emit openModal when cookie is not set', () => {
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
