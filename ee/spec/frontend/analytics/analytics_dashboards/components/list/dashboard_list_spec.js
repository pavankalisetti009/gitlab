import { GlTable, GlAvatarLabeled } from '@gitlab/ui';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import DashboardList from 'ee/analytics/analytics_dashboards/components/list/dashboard_list.vue';

// NOTE: theres no graphql query for this yet, eventually replace with a fixture
const mockStarredDashboard = [
  {
    name: 'Built in dashboard',
    description: 'Built in dashboard description',
    slug: 'built-in',
    user: {
      id: 1337,
      name: 'GitLab',
      username: 'gitlab',
      avatarUrl: '/fake/user/avatar.jpg',
      webUrl: '/gitlab',
    },
    isCustom: false,
    isStarred: true,
    shareLink: '/fake/link/to/share',
    lastEdited: '2024-12-20',
  },
];

const mockDashboards = [
  {
    name: 'First custom dashboard',
    description: 'Default dashboard description',
    slug: 'first-custom-dashboard',
    user: {
      id: 133737,
      name: 'Fake User',
      username: 'fakeuser',
      avatarUrl: '/fake/user/avatar.jpg',
      webUrl: '/fakeuser',
    },
    isCustom: true,
    isStarred: false,
    isEditable: true,
    shareLink: '/fake/link/to/share',
    lastEdited: '2025-09-10',
  },
  {
    name: 'Cool dashboard',
    description:
      'Cool custom dashboard that has a description that is very long and will most definitely overflow',
    slug: 'cool-custom-dashboard',
    user: {
      id: 133737,
      name: 'Fake User',
      username: 'fakeuser',
      avatarUrl: '/fake/user/avatar.jpg',
      webUrl: '/fakeuser',
    },
    isCustom: true,
    isStarred: false,
    isEditable: true,
    shareLink: '/fake/link/to/share',
    lastEdited: '2025-10-28',
  },
];

describe('DashboardList', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRows = () => wrapper.findAll('tbody tr');
  const findStarIcons = () => wrapper.findAllByTestId('dashboard-star-icon');
  const findDashboardLinks = () => wrapper.findAllByTestId('dashboard-redirect-link');
  const findUserAvatars = () => wrapper.findAllComponents(GlAvatarLabeled);
  const findActionDropdowns = () => wrapper.findAllByTestId('dashboard-actions');

  const createWrapper = (props = {}, mountFn = shallowMountExtended) => {
    wrapper = mountFn(DashboardList, {
      propsData: {
        dashboards: mockDashboards,
        ...props,
      },
    });
  };

  describe('with valid dashboard data', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the table component', () => {
      expect(findTable().exists()).toBe(true);
      expect(findTable().attributes('stacked')).toBe('sm');
    });
  });

  describe('with data', () => {
    beforeEach(() => {
      createWrapper({}, mountExtended);
    });

    it('renders the correct number of table rows', () => {
      expect(findTableRows()).toHaveLength(mockDashboards.length);
    });

    it('renders dashboard names as links', () => {
      const dashboardLinks = findDashboardLinks();

      expect(dashboardLinks).toHaveLength(mockDashboards.length);

      dashboardLinks.wrappers.forEach((link, index) => {
        const dashboard = mockDashboards[index];
        expect(link.text()).toBe(dashboard.name);
        expect(link.attributes('href')).toBe(`/${dashboard.slug}`);
      });
    });

    it('renders star icons with correct states', () => {
      const starIcons = findStarIcons();

      expect(starIcons).toHaveLength(mockDashboards.length);

      starIcons.wrappers.forEach((icon, index) => {
        const dashboard = mockDashboards[index];

        expect(icon.attributes()).toMatchObject({
          'aria-label': `Add ${dashboard.name} to favorites`,
          title: 'Add to favorites',
        });

        expect(icon.props()).toMatchObject({
          icon: 'star-o',
          category: 'tertiary',
          variant: 'default',
          size: 'medium',
          type: 'button',
        });
      });
    });

    it('renders user avatars with correct props', () => {
      const avatars = findUserAvatars();

      expect(avatars).toHaveLength(mockDashboards.length);

      avatars.wrappers.forEach((avatar, index) => {
        const dashboard = mockDashboards[index];
        expect(avatar.props()).toMatchObject({
          src: dashboard.user.avatarUrl,
          size: 24,
          shape: 'circle',
          fallbackOnError: true,
          label: dashboard.user.name,
        });
      });
    });

    it('renders user names', () => {
      mockDashboards.forEach((dashboard, index) => {
        const row = findTableRows().at(index);
        expect(row.text()).toContain(dashboard.user.name);
      });
    });

    it('renders last edited dates', () => {
      mockDashboards.forEach((dashboard, index) => {
        const row = findTableRows().at(index);
        expect(row.text()).toContain(dashboard.lastEdited);
      });
    });

    it('renders action dropdowns for each dashboard', () => {
      const actionDropdowns = findActionDropdowns();

      expect(actionDropdowns).toHaveLength(mockDashboards.length);

      actionDropdowns.wrappers.forEach((dropdown) => {
        expect(dropdown.props()).toMatchObject({
          icon: 'ellipsis_v',
          category: 'tertiary',
          textSrOnly: true,
          noCaret: true,
        });
      });
    });

    it('renders the valid fields', () => {
      const expectedFields = ['Title', 'Created by', 'Last edited', 'Actions'];
      const fields = findTable()
        .props('fields')
        .map(({ label }) => label);

      expect(fields).toEqual(expectedFields);
    });
  });

  describe('with a starred dashboard', () => {
    beforeEach(() => {
      createWrapper({ dashboards: mockStarredDashboard }, mountExtended);
    });

    it('renders star icons with correct states', () => {
      const starIcons = findStarIcons();

      expect(starIcons).toHaveLength(mockStarredDashboard.length);

      starIcons.wrappers.forEach((icon, index) => {
        const dashboard = mockStarredDashboard[index];

        expect(icon.attributes()).toMatchObject({
          'aria-label': `Remove ${dashboard.name} from favorites`,
          title: 'Remove from favorites',
        });

        expect(icon.props()).toMatchObject({
          icon: 'star',
          category: 'tertiary',
          variant: 'default',
          size: 'medium',
          type: 'button',
        });
      });
    });
  });

  describe('with empty dashboard data', () => {
    beforeEach(() => {
      createWrapper({ dashboards: [] });
    });

    it('renders the table component', () => {
      expect(findTable().exists()).toBe(true);
    });

    it('renders no table rows', () => {
      expect(findTableRows()).toHaveLength(0);
    });

    it('renders no dashboard links', () => {
      expect(findDashboardLinks()).toHaveLength(0);
    });

    it('renders no star icons', () => {
      expect(findStarIcons()).toHaveLength(0);
    });

    it('renders no user avatars', () => {
      expect(findUserAvatars()).toHaveLength(0);
    });
  });
});
