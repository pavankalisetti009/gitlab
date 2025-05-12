import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RightSidebar from 'ee/pages/projects/get_started/components/right_sidebar.vue';
import {
  GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK,
  LEARN_MORE_LINKS,
} from 'ee/pages/projects/get_started/constants';

describe('RightSidebar', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(RightSidebar);
  };

  const findTitle = () => wrapper.findAll('h2');
  const findEnrollLink = () => wrapper.findByText('Enroll');

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the correct titles', () => {
      expect(findTitle().at(0).text()).toBe('GitLab University');
      expect(findTitle().at(1).text()).toBe('Learn more');
    });

    it('renders the gitlab university enroll link', () => {
      expect(findEnrollLink().exists()).toBe(true);
      expect(findEnrollLink().attributes('href')).toBe(GITLAB_UNIVERSITY_DUO_COURSE_ENROLL_LINK);
    });

    it.each(LEARN_MORE_LINKS.map((link, i) => [link.text, i]))(
      'renders the correct link for %s',
      (text, index) => {
        expect(wrapper.findByText(text).attributes('href')).toBe(LEARN_MORE_LINKS[index].url);
      },
    );
  });
});
