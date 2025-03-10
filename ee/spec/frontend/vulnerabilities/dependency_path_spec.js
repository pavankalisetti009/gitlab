import { GlButton } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyPath from 'ee/vulnerabilities/components/dependency_path.vue';
import DependencyPathDrawer from 'ee/dependencies/components/dependency_path_drawer.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';

jest.mock('~/lib/utils/dom_utils', () => ({ getContentWrapperHeight: jest.fn() }));

describe('Dependency paths drawer component', () => {
  let wrapper;

  const defaultProps = {
    dependency: {
      component: {
        name: 'uri',
        version: '13.3',
      },
      dependencyPaths: [{ path: [{ name: 'jest', version: '29.7.0' }] }],
    },
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DependencyPath, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlDrawer: stubComponent(DependencyPathDrawer, { template: RENDER_ALL_SLOTS_TEMPLATE }),
        MountingPortal: stubComponent(MountingPortal),
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(DependencyPathDrawer);
  const findButton = () => wrapper.findComponent(GlButton);
  const findMountingPortal = () => wrapper.findComponent(MountingPortal);

  const clicksButton = async () => {
    findButton().vm.$emit('click');
    await nextTick();
  };

  it('renders into the mounting portal', () => {
    createComponent();

    expect(findMountingPortal().attributes()).toMatchObject({
      'mount-to': '#js-dependency-paths-drawer-portal',
    });
  });

  describe('button', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the button', () => {
      createComponent();

      expect(findButton().props()).toMatchObject({ size: 'small' });
      expect(findButton().text()).toBe('View dependency paths');
    });

    it('opens the drawer on click', async () => {
      expect(findDrawer().props('showDrawer')).toBe(false);

      await clicksButton();

      expect(findDrawer().props('showDrawer')).toBe(true);
    });

    it('closes the drawer on click when it is opened', async () => {
      await clicksButton(); // First, click to open drawer
      expect(findDrawer().props('showDrawer')).toBe(true);

      await clicksButton(); // Second, click to close drawer
      expect(findDrawer().props('showDrawer')).toBe(false);
    });
  });

  describe('drawer', () => {
    beforeEach(() => {
      createComponent();
      clicksButton();
    });

    it('renders the drawer on and passes the correct props', () => {
      const { component, dependencyPaths } = defaultProps.dependency;

      expect(findDrawer().props()).toMatchObject({
        showDrawer: true,
        dependencyPaths,
        component,
      });
    });

    it('closes the drawer on click', async () => {
      findDrawer().vm.$emit('close');
      await nextTick();
      expect(findDrawer().props('showDrawer')).toBe(false);
    });
  });
});
