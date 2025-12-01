import { GlBadge, GlLink, GlSkeletonLoader } from '@gitlab/ui';
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
        humanStatus: 'Running',
        agentFlowDefinition: 'software_development',
        executorUrl: 'https://gitlab.com/gitlab-org/gitlab/-/jobs/123',
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

  const findHeading = () => wrapper.find('h5');
  const findInfoList = () => wrapper.find('ul');
  const findListItems = () => wrapper.findAll('li');
  const findListItemTitles = () => wrapper.findAll('[data-testid="info-title"]');
  const findListItemValues = () => wrapper.findAll('[data-testid="info-value"]');
  const findSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);
  const findLinks = () => wrapper.findAllComponents(GlLink);
  const findBadge = () => wrapper.findComponent(GlBadge);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({
        isLoading: true,
      });
    });

    it('renders the heading', () => {
      expect(findHeading().text()).toBe('Session information');
    });

    it('renders the info list', () => {
      expect(findInfoList().exists()).toBe(true);
    });

    it('renders all session info items as list items', () => {
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

    it('renders all expected info values in the correct order', () => {
      const listItems = findListItemValues();
      const expectedData = [
        '4545', // Session ID
        'Running', // Status
        'Test Project', // Project
        'gitlab-org', // Group
        'Flow', // Type
        'software_development', // Flow
        '123', // Executor ID
        'Jan 1, 2023, 12:00 AM', // Started
        'Jan 1, 2024, 12:00 AM', // Last updated
      ];

      expectedData.forEach((expectedText, index) => {
        expect(listItems.at(index).text()).toContain(expectedText);
      });
    });

    it('renders the status badge with the correct props', () => {
      const badge = findBadge();

      expect(badge.exists()).toBe(true);
      expect(badge.props()).toMatchObject({
        variant: 'info',
      });
      expect(badge.text()).toBe('Running');
    });

    it('renders all the expected titles in the correct order', () => {
      const listItemTitles = findListItemTitles();
      const expectedTitles = [
        'Session ID',
        'Status',
        'Project',
        'Group',
        'Type',
        'Flow',
        'Job ID',
        'Started',
        'Last updated',
      ];

      expectedTitles.forEach((expectedTitle, index) => {
        expect(listItemTitles.at(index).text()).toContain(expectedTitle);
      });
    });

    it.each`
      index | href                                                                           | text
      ${0}  | ${'https://gitlab.com/gitlab-org/test-project/-/automate/agent-sessions/4545'} | ${'4545'}
      ${1}  | ${'https://gitlab.com/gitlab-org/test-project'}                                | ${'Test Project'}
      ${2}  | ${'https://gitlab.com/gitlab-org'}                                             | ${'gitlab-org'}
      ${3}  | ${'https://gitlab.com/gitlab-org/gitlab/-/jobs/123'}                           | ${'123'}
    `('renders links for session ID, project, group, and job ID', ({ index, href, text }) => {
      const links = findLinks();
      expect(links.at(index).attributes('href')).toBe(href);
      expect(links.at(index).text()).toBe(text);
    });

    describe('when project information is missing', () => {
      beforeEach(() => {
        createComponent({
          project: {},
        });
      });

      it('displays N/A for missing project information', () => {
        expect(findListItems().at(2).text()).toContain('N/A'); // Project name
        expect(findListItems().at(3).text()).toContain('N/A'); // Group name
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
        expect(findListItems().at(2).text()).toContain('Test Project'); // Project name should still show
        expect(findListItems().at(3).text()).toContain('N/A'); // Group name should be N/A
      });

      it('displays project, sessionId, and executor links but not group link', () => {
        const links = findLinks();

        expect(links).toHaveLength(3);
        expect(links.at(0).attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/test-project/-/automate/agent-sessions/4545',
        );
        expect(links.at(1).attributes('href')).toBe('https://gitlab.com/gitlab-org/test-project');
        expect(links.at(2).attributes('href')).toBe(
          'https://gitlab.com/gitlab-org/gitlab/-/jobs/123',
        );
      });
    });

    describe('when executor URL is invalid', () => {
      beforeEach(() => {
        createComponent({
          executorUrl: 'https://gitlab.com/invalid-url',
        });
      });

      it('displays N/A for invalid job ID', () => {
        expect(findListItems().at(6).text()).toContain('N/A');
      });
    });

    describe('when executor URL is empty', () => {
      beforeEach(() => {
        createComponent({
          executorUrl: '',
        });
      });

      it('displays N/A for empty executor URL', () => {
        expect(findListItems().at(6).text()).toContain('N/A');
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
        expect(findListItems().at(7).text()).toContain('N/A'); // Started
        expect(findListItems().at(8).text()).toContain('N/A'); // Last updated
      });

      it('does not call the date formatter for invalid dates', () => {
        expect(mockDateTimeFormatter.format).not.toHaveBeenCalled();
      });
    });
  });
});
