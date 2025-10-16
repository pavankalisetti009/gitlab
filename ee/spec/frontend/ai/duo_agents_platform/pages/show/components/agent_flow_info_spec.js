import { GlLink, GlSkeletonLoader } from '@gitlab/ui';
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
          webUrl: 'https://gitlab.com/gitlab-org/test-project',
          namespace: {
            id: 'gid://gitlab/Group/1',
            name: 'gitlab-org',
            webUrl: 'https://gitlab.com/gitlab-org',
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

  const findListItems = () => wrapper.findAll('dd');
  const findListItemTitles = () => wrapper.findAll('dt');
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

    it('renders all expected list data', () => {
      const listItems = findListItems();
      const expectedData = [
        'RUNNING',
        'Test Project',
        'gitlab-org',
        'Jan 1, 2023, 12:00 AM',
        'Jan 1, 2024, 12:00 AM',
        'Flow',
        'software_development',
        '4545',
        '123',
      ];

      expectedData.forEach((expectedText, index) => {
        expect(listItems.at(index).text()).toContain(expectedText);
      });
    });

    it('renders all the expected titles', () => {
      const listItemTitles = findListItemTitles();
      const expectedTitles = [
        'Status',
        'Project',
        'Group',
        'Started',
        'Last updated',
        'Type',
        'Flow',
        'Session ID',
        'Executor ID',
      ];

      expectedTitles.forEach((expectedTitle, index) => {
        expect(listItemTitles.at(index).text()).toContain(expectedTitle);
      });
    });

    it.each`
      index | href                                                                           | text
      ${1}  | ${'https://gitlab.com/gitlab-org/test-project'}                                | ${'Test Project'}
      ${2}  | ${'https://gitlab.com/gitlab-org'}                                             | ${'gitlab-org'}
      ${7}  | ${'https://gitlab.com/gitlab-org/test-project/-/automate/agent-sessions/4545'} | ${'4545'}
      ${8}  | ${'https://gitlab.com/gitlab-org/gitlab/-/pipelines/123'}                      | ${'123'}
    `('renders links for project, group, session ID, and executor ID', ({ index, href, text }) => {
      const link = findListItems().at(index).findComponent(GlLink);
      expect(link.attributes('href')).toBe(href);
      expect(link.text()).toBe(text);
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

      it('does not display links for project, group, and sessionId', () => {
        expect(findListItems().at(1).findComponent(GlLink).exists()).toBe(false); // Project link
        expect(findListItems().at(2).findComponent(GlLink).exists()).toBe(false); // Group link
        expect(findListItems().at(7).findComponent(GlLink).exists()).toBe(false); // SessionId link
      });
    });

    describe('when project namespace is missing', () => {
      beforeEach(() => {
        createComponent({
          project: {
            id: 'gid://gitlab/Project/1',
            name: 'Test Project',
            fullPath: 'gitlab-org/test-project',
            webUrl: 'https://gitlab.com/gitlab-org/test-project',
          },
        });
      });

      it('displays N/A for missing namespace information', () => {
        expect(findListItems().at(1).text()).toContain('Test Project'); // Project name should still show
        expect(findListItems().at(2).text()).toContain('N/A'); // Group name should be N/A
      });

      it('does not display group link', () => {
        expect(findListItems().at(2).findComponent(GlLink).exists()).toBe(false); // Group link
      });

      it('displays project and sessionId links', () => {
        expect(findListItems().at(1).findComponent(GlLink).exists()).toBe(true); // Project link
        expect(findListItems().at(7).findComponent(GlLink).exists()).toBe(true); // SessionId link
      });
    });

    describe('when executor URL is invalid', () => {
      beforeEach(() => {
        createComponent({
          executorUrl: 'https://gitlab.com/invalid-url',
        });
      });

      it('displays N/A for invalid executor ID', () => {
        expect(findListItems().at(8).text()).toContain('N/A'); // Executor ID
      });
    });

    describe('when executor URL is empty', () => {
      beforeEach(() => {
        createComponent({
          executorUrl: '',
        });
      });

      it('displays N/A for empty executor URL', () => {
        expect(findListItems().at(8).text()).toContain('N/A'); // Executor ID
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
