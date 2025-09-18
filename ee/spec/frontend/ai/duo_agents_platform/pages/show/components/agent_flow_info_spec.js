import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AgentFlowInfo from 'ee/ai/duo_agents_platform/pages/show/components/agent_flow_info.vue';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';

jest.mock('~/lib/utils/datetime/locale_dateformat');

describe('AgentFlowInfo', () => {
  let wrapper;

  const mockDateTimeFormatter = {
    format: jest.fn(),
  };

  beforeEach(() => {
    localeDateFormat.asDateTime = mockDateTimeFormatter;
    mockDateTimeFormatter.format.mockImplementation((date) => {
      // Mock the locale-aware formatting to return a predictable format for testing
      if (date.toISOString() === '2023-01-01T00:00:00.000Z') {
        return 'Jan 1, 2023, 12:00 AM';
      }
      if (date.toISOString() === '2024-01-01T00:00:00.000Z') {
        return 'Jan 1, 2024, 12:00 AM';
      }
      return date.toISOString();
    });
  });

  const createComponent = (props = {}) => {
    wrapper = shallowMount(AgentFlowInfo, {
      propsData: {
        isLoading: false,
        status: 'RUNNING',
        agentFlowDefinition: 'software_development',
        executorUrl: 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123',
        createdAt: '2023-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
        project: {
          id: 'gid://gitlab/Project/1',
          name: 'Test Project',
          fullPath: 'gitlab-org/test-project',
          namespace: {
            id: 'gid://gitlab/Group/1',
            name: 'gitlab-org',
          },
        },
        ...props,
      },
      mocks: {
        $route: {
          params: {
            id: '4545',
          },
        },
      },
    });
  };

  const findListItems = () => wrapper.findAll('li');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
      });
    });

    it('renders UI copy as usual', () => {
      expect(findListItems()).toHaveLength(9);
    });

    it('displays the skeleton loaders', () => {
      expect(findSkeletonLoaders()).toHaveLength(9);
    });

    it('does not display placeholder N/A values', () => {
      expect(wrapper.text()).not.toContain('N/A');
    });
  });

  describe('info data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all expected data', () => {
      expect(findListItems().at(0).text()).toContain('RUNNING');
      expect(findListItems().at(1).text()).toContain('Test Project');
      expect(findListItems().at(2).text()).toContain('gitlab-org');
      expect(findListItems().at(3).text()).toContain('Jan 1, 2023, 12:00 AM');
      expect(findListItems().at(4).text()).toContain('Jan 1, 2024, 12:00 AM');
      expect(findListItems().at(5).text()).toContain('Flow');
      expect(findListItems().at(6).text()).toContain('software_development');
      expect(findListItems().at(7).text()).toContain('4545');
    });

    describe('when project information is missing', () => {
      beforeEach(() => {
        createComponent({
          project: {},
        });
      });

      it('displays N/A for missing project information', () => {
        expect(findListItems().at(1).text()).toContain('N/A'); // Project name
        expect(findListItems().at(2).text()).toContain('N/A'); // Group name
      });
    });

    describe('when project namespace is missing', () => {
      beforeEach(() => {
        createComponent({
          project: {
            id: 'gid://gitlab/Project/1',
            name: 'Test Project',
            fullPath: 'gitlab-org/test-project',
          },
        });
      });

      it('displays N/A for missing namespace information', () => {
        expect(findListItems().at(1).text()).toContain('Test Project'); // Project name should still show
        expect(findListItems().at(2).text()).toContain('N/A'); // Group name should be N/A
      });
    });

    it('uses locale-aware date formatting', () => {
      expect(mockDateTimeFormatter.format).toHaveBeenCalledWith(new Date('2023-01-01T00:00:00Z'));
      expect(mockDateTimeFormatter.format).toHaveBeenCalledWith(new Date('2024-01-01T00:00:00Z'));
    });

    describe('when date values are invalid', () => {
      beforeEach(() => {
        mockDateTimeFormatter.format.mockClear();
        createComponent({
          createdAt: null,
          updatedAt: 'invalid-date',
        });
      });

      it('displays N/A for invalid dates', () => {
        expect(findListItems().at(3).text()).toContain('N/A'); // Started
        expect(findListItems().at(4).text()).toContain('N/A'); // Last updated
      });

      it('does not call the date formatter for invalid dates', () => {
        expect(mockDateTimeFormatter.format).not.toHaveBeenCalled();
      });
    });
  });
});
