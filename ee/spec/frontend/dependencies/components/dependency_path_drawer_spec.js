import { GlDrawer, GlTruncateText, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

jest.mock('~/lib/utils/dom_utils', () => ({ getContentWrapperHeight: jest.fn() }));

describe('DependencyPathDrawer component', () => {
  let wrapper;

  const defaultProps = {
    component: {
      name: 'activerecord',
      version: '5.0.0',
    },
    dependencyPaths: [{ isCyclic: true, path: [{ name: 'jest', version: '29.7.0' }] }],
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(DependencyPathDrawer, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlDrawer: stubComponent(GlDrawer, { template: RENDER_ALL_SLOTS_TEMPLATE }),
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findTitle = () => wrapper.findByTestId('dependency-path-drawer-title');
  const findHeader = () => wrapper.findByTestId('dependency-path-drawer-header');
  const findProject = () => wrapper.findByTestId('dependency-path-drawer-project');
  const findAllListItem = () => wrapper.findAll('li');
  const getTruncateText = (index) => findAllListItem().at(index).findComponent(GlTruncateText);
  const getBadge = (index) => findAllListItem().at(index).findComponent(GlBadge);

  describe('default', () => {
    it('configures the drawer with header height and z-index', () => {
      const mockHeaderHeight = '50px';

      getContentWrapperHeight.mockReturnValue(mockHeaderHeight);
      createComponent();

      expect(findDrawer().props()).toMatchObject({
        headerHeight: mockHeaderHeight,
        zIndex: DRAWER_Z_INDEX,
      });
    });

    it('the drawer is not shown', () => {
      createComponent({ showDrawer: false });
      expect(findDrawer().props('open')).toBe(false);
    });

    it('the drawer is shown', () => {
      createComponent({ showDrawer: true });
      expect(findDrawer().props('open')).toBe(true);
    });

    it('has the drawer title', () => {
      createComponent({ showDrawer: false });
      expect(findTitle().text()).toEqual('Dependency paths');
    });
  });

  describe('with header section', () => {
    it('shows header text when component exists', () => {
      createComponent({ showDrawer: true });

      const { name, version } = defaultProps.component;
      expect(findHeader().text()).toBe(`Component: ${name} ${version}`);
    });
  });

  describe('with project section', () => {
    it('shows project info when project exists', () => {
      const projectName = 'Project Foo';

      createComponent({
        showDrawer: true,
        project: { name: projectName },
      });

      expect(findProject().text()).toContain(`Project: ${projectName}`);
    });

    it('does not show project info when project does not exist', () => {
      createComponent({ showDrawer: true, project: undefined });
      expect(findProject().exists()).toBe(false);
    });
  });

  describe('with dependency paths section', () => {
    it('renders the correct length of dependency path items', () => {
      createComponent();

      const { dependencyPaths } = defaultProps;
      expect(findAllListItem()).toHaveLength(dependencyPaths.length);
    });

    it('renders the truncate text with the correct props', () => {
      createComponent();

      expect(getTruncateText(0).props()).toMatchObject({
        mobileLines: 3,
        toggleButtonProps: {
          class: 'gl-text-subtle gl-mt-3',
        },
      });
    });

    it('renders the paths text in the correct format', () => {
      createComponent();

      const index = 0;
      const { name, version } = defaultProps.dependencyPaths[index].path[index];
      expect(getTruncateText(index).text()).toBe(`${name} @${version}`);
    });
  });

  describe('with circular dependency badge', () => {
    it('renders the badge with the correct prop and text', () => {
      createComponent();

      expect(getBadge(0).props('variant')).toBe('warning');
      expect(getBadge(0).text()).toBe('circular dependency');
    });

    it('does not render the badge', () => {
      createComponent({
        dependencyPaths: [{ isCyclic: false, path: [{ name: 'jest', version: '29.7.0' }] }],
      });

      expect(getBadge(0).exists()).toBe(false);
    });
  });
});
