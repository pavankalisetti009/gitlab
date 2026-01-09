import { GlTabs, GlTab } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';
import ContainerRegistriesAndUpstreams from 'ee/packages_and_registries/virtual_registries/pages/container/registries_and_upstreams.vue';
import {
  CONTAINER_REGISTRIES_INDEX,
  CONTAINER_UPSTREAMS_INDEX,
} from 'ee/packages_and_registries/virtual_registries/pages/container/routes';

describe('ContainerRegistriesAndUpstreams', () => {
  let wrapper;
  let mockRouter;

  const findPageHeading = () => wrapper.findComponent(PageHeading);
  const findCleanupPolicyStatus = () => wrapper.findComponent(CleanupPolicyStatus);
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);
  const findRegistriesTab = () => findAllTabs().at(0);
  const findUpstreamsTab = () => findAllTabs().at(1);

  const createComponent = (route = { name: CONTAINER_REGISTRIES_INDEX }) => {
    mockRouter = {
      push: jest.fn(),
      resolve: jest.fn().mockReturnValue({ href: '/' }),
    };

    wrapper = shallowMountExtended(ContainerRegistriesAndUpstreams, {
      mocks: {
        $router: mockRouter,
        $route: route,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('rendering', () => {
    it('renders the page heading', () => {
      expect(findPageHeading().props('heading')).toBe('Container virtual registries');
    });

    it('renders the cleanup policy status component', () => {
      expect(findCleanupPolicyStatus().exists()).toBe(true);
    });

    it('renders tabs component', () => {
      expect(findTabs().exists()).toBe(true);
    });

    it('renders registries and upstreams tabs', () => {
      expect(findAllTabs()).toHaveLength(2);
    });
  });

  describe('registries tab', () => {
    it('has correct title', () => {
      expect(findRegistriesTab().attributes('title')).toBe('Registries');
    });

    it('is active when on registries route', () => {
      expect(findRegistriesTab().attributes('active')).toBe('true');
    });

    it('is not active when on upstreams route', () => {
      createComponent({ name: CONTAINER_UPSTREAMS_INDEX });

      expect(findRegistriesTab().attributes('active')).not.toBeDefined();
    });

    it('navigates to registries index on click', async () => {
      await findRegistriesTab().vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: CONTAINER_REGISTRIES_INDEX });
    });
  });

  describe('upstreams tab', () => {
    it('has correct title', () => {
      expect(findUpstreamsTab().attributes('title')).toBe('Upstreams');
    });

    it('is not active when on registries route', () => {
      expect(findUpstreamsTab().attributes('active')).not.toBeDefined();
    });

    it('is active when on upstreams route', () => {
      createComponent({ name: CONTAINER_UPSTREAMS_INDEX });

      expect(findUpstreamsTab().attributes('active')).toBe('true');
    });

    it('navigates to upstreams index on click', async () => {
      await findUpstreamsTab().vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: CONTAINER_UPSTREAMS_INDEX });
    });
  });
});
