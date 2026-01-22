import { GlDrawer } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import ProjectSecurityConfigurationDrawer from 'ee/security_inventory/components/project_security_configuration_drawer.vue';
import SecurityConfigurationProvider from '~/security_configuration/components/security_configuration_provider.vue';

describe('ProjectSecurityConfigurationDrawer', () => {
  let wrapper;

  const projectId = '123';
  const projectFullPath = 'test/project';
  const projectName = 'Test Project';

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(ProjectSecurityConfigurationDrawer, {
      propsData: {
        projectId,
        projectFullPath,
        projectName,
        ...props,
      },
    });
  };

  const findDrawer = () => wrapper.findComponent(GlDrawer);
  const findSecurityConfigurationProvider = () =>
    wrapper.findComponent(SecurityConfigurationProvider);

  describe('when drawer is closed', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlDrawer with correct props', () => {
      const drawer = findDrawer();

      expect(drawer.exists()).toBe(true);
      expect(drawer.props()).toMatchObject({
        open: false,
        zIndex: DRAWER_Z_INDEX,
      });
    });

    it('does not render SecurityConfigurationProvider', () => {
      expect(findSecurityConfigurationProvider().exists()).toBe(false);
    });

    it('displays project name in title', () => {
      expect(wrapper.text()).toContain('Security configuration: Test Project');
    });
  });

  describe('when drawer is opened', () => {
    beforeEach(() => {
      createComponent();
      wrapper.vm.openDrawer();
    });

    it('sets drawer open state to true', () => {
      expect(findDrawer().props('open')).toBe(true);
    });

    it('renders SecurityConfigurationProvider', () => {
      expect(findSecurityConfigurationProvider().exists()).toBe(true);
    });

    it('provides projectId and projectFullPath', () => {
      const provider = findSecurityConfigurationProvider();
      expect(provider.exists()).toBe(true);
    });
  });

  describe('when drawer is closed via close event', () => {
    beforeEach(() => {
      createComponent();
      wrapper.vm.openDrawer();
      findDrawer().vm.$emit('close');
    });

    it('sets drawer open state to false', () => {
      expect(wrapper.vm.isDrawerOpen).toBe(false);
    });
  });

  describe('without project name', () => {
    beforeEach(() => {
      createComponent({ projectName: '' });
    });

    it('displays generic title', () => {
      expect(wrapper.text()).toContain('Security configuration');
      expect(wrapper.text()).not.toContain(':');
    });
  });
});
