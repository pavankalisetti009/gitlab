import { GlDrawer, GlButton } from '@gitlab/ui';
import { MountingPortal } from 'portal-vue';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyPathDrawer from 'ee/vulnerabilities/components/dependency_path_drawer.vue';
import { RENDER_ALL_SLOTS_TEMPLATE, stubComponent } from 'helpers/stub_component';

jest.mock('~/lib/utils/dom_utils', () => ({ getContentWrapperHeight: jest.fn() }));

describe('Dependency paths drawer component', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(DependencyPathDrawer, {
      stubs: {
        GlDrawer: stubComponent(GlDrawer, { template: RENDER_ALL_SLOTS_TEMPLATE }),
        MountingPortal: stubComponent(MountingPortal),
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findButton = () => wrapper.findComponent(GlButton);
  const findMountingPortal = () => wrapper.findComponent(MountingPortal);

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
      expect(findDrawer().props('open')).toBe(false);

      findButton().vm.$emit('click');
      await nextTick();

      expect(findDrawer().props('open')).toBe(true);
    });
  });

  describe('drawer', () => {
    beforeEach(() => {
      createComponent();
      findButton().vm.$emit('click');
    });

    it('renders the drawer on', () => {
      expect(findDrawer().props()).toMatchObject(
        expect.objectContaining({ open: true, zIndex: 252 }),
      );
    });

    it('renders the drawer title', () => {
      expect(wrapper.findByTestId('dependency-path-drawer-title').text()).toBe('Dependency paths');
    });

    it('closes the drawer on click', async () => {
      expect(findDrawer().props('open')).toBe(true);

      findDrawer().vm.$emit('close');
      await nextTick();

      expect(findDrawer().props('open')).toBe(false);
    });
  });
});
