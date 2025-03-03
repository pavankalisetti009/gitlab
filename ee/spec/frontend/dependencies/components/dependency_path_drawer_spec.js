import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';

jest.mock('~/lib/utils/dom_utils', () => ({ getContentWrapperHeight: jest.fn() }));

describe('DependencyPathDrawer component', () => {
  let wrapper;

  const defaultDependency = {
    name: 'activerecord',
    version: '5.0.0',
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(DependencyPathDrawer, {
      propsData: {
        dependency: defaultDependency,
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

      const header = findHeader();
      expect(header.text()).toContain(defaultDependency.name);
      expect(header.text()).toContain(defaultDependency.version);
    });

    it('does not show header text when component does not exist', () => {
      createComponent({ showDrawer: true, dependency: {} });
      expect(findHeader().exists()).toBe(false);
    });
  });

  describe('with project section', () => {
    it('shows project info when project exists', () => {
      const projectName = 'Project Foo';

      createComponent({
        showDrawer: true,
        dependency: { ...defaultDependency, project: { name: projectName } },
      });

      expect(findProject().text()).toContain(`Project: ${projectName}`);
    });

    it('does not show project info when project does not exist', () => {
      createComponent({ showDrawer: true });
      expect(findProject().exists()).toBe(false);
    });
  });
});
