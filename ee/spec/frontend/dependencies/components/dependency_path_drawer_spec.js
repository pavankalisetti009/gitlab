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

  describe('default behaviour', () => {
    const mockHeaderHeight = '50px';

    beforeEach(() => {
      getContentWrapperHeight.mockReturnValue(mockHeaderHeight);
      createComponent();
    });

    it('configures the drawer with header height and z-index', () => {
      expect(findDrawer().props()).toMatchObject({
        headerHeight: mockHeaderHeight,
        zIndex: DRAWER_Z_INDEX,
      });
    });
  });

  describe('when closed', () => {
    beforeEach(() => {
      createComponent({ showDrawer: false });
    });

    it('the drawer is not shown', () => {
      expect(findDrawer().props('open')).toBe(false);
    });
  });

  describe('when opened', () => {
    beforeEach(() => {
      createComponent({ showDrawer: true });
    });

    it('the drawer is shown', () => {
      expect(findDrawer().props('open')).toBe(true);
    });

    it('has the drawer title', () => {
      expect(findTitle().text()).toEqual('Dependency paths');
    });

    it('has the header text', () => {
      const header = findHeader();

      expect(header.text()).toContain(defaultDependency.name);
      expect(header.text()).toContain(defaultDependency.version);
    });
  });
});
