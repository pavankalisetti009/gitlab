import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import IssueIteration from 'ee/boards/components/issue_iteration.vue';
import { mockIterations } from '../mock_data';

const mockIteration = mockIterations[0];

describe('IssueIteration', () => {
  let wrapper;

  const mountIssueIteration = (iteration) => {
    wrapper = shallowMountExtended(IssueIteration, {
      propsData: {
        iteration,
      },
    });
  };

  const findBody = () => wrapper.findByTestId('issue-iteration-body');
  const findTitle = () => wrapper.findByTestId('issue-iteration-title');
  const findPeriod = () => wrapper.findByTestId('issue-iteration-period');
  const findCadenceTitle = () => wrapper.findByTestId('issue-iteration-cadence-title');

  it('shows the iteration period', () => {
    mountIssueIteration(mockIteration);

    expect(findBody().text()).toContain('Oct 5 - Oct 10, 2021');
  });

  describe('tooltip info', () => {
    it('shows the iteration title if present', () => {
      const mockIterationWithTitle = mockIterations[1];

      mountIssueIteration(mockIterationWithTitle);

      expect(findTitle().text()).toContain('Some iteration');
    });

    it('hides the iteration title if missing', () => {
      mountIssueIteration(mockIteration);

      expect(findTitle().exists()).toBe(false);
    });

    it('shows the iteration cadence title if present', () => {
      mountIssueIteration(mockIteration);

      expect(findCadenceTitle().text()).toContain('GitLab.org Iterations');
    });

    it('shows the iteration period', () => {
      mountIssueIteration(mockIteration);

      expect(findPeriod().text()).toContain('Oct 5 - Oct 10, 2021');
    });
  });
});
