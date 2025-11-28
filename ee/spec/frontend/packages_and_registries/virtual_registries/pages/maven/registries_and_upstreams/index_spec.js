import { GlTab } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import MavenRegistriesAndUpstreamsApp from 'ee/packages_and_registries/virtual_registries/pages/maven/registries_and_upstreams/index.vue';
import RegistriesList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/registries_list.vue';
import UpstreamsList from 'ee/packages_and_registries/virtual_registries/components/maven/registries_and_upstreams/upstreams_list.vue';
import CleanupPolicyStatus from 'ee/packages_and_registries/virtual_registries/components/cleanup_policy_status.vue';

describe('MavenRegistriesAndUpstreamsApp', () => {
  let wrapper;
  const fullPath = 'testFullPath';

  const createComponent = () => {
    wrapper = shallowMountExtended(MavenRegistriesAndUpstreamsApp, {
      provide: {
        fullPath,
      },
      stubs: {
        GlTabs: true,
        GlTab,
        UpstreamsList: stubComponent(UpstreamsList),
      },
    });
  };

  const findRegistriesTabTitle = () => wrapper.findByTestId('registries-tab-title');
  const findRegistriesCount = () => wrapper.findByTestId('registries-tab-counter-badge');
  const findRegistriesList = () => wrapper.findComponent(RegistriesList);
  const findUpstreamsTabTitle = () => wrapper.findByTestId('upstreams-tab-title');
  const findUpstreamsCount = () => wrapper.findByTestId('upstreams-tab-counter-badge');
  const findUpstreamsList = () => wrapper.findComponent(UpstreamsList);
  const findCleanupPolicyStatus = () => wrapper.findComponent(CleanupPolicyStatus);

  beforeEach(() => {
    createComponent();
  });

  it('renders registries tab', () => {
    expect(findRegistriesTabTitle().text()).toBe('Registries');
  });

  it('renders upstreams tab', () => {
    expect(findUpstreamsTabTitle().text()).toBe('Upstreams');
  });

  it('renders MavenRegistriesList component', () => {
    expect(findRegistriesList().exists()).toBe(true);
  });

  it('renders MavenUpstreamsList component', () => {
    expect(findUpstreamsList().exists()).toBe(true);
  });

  it('initially does not render registries count', () => {
    expect(findRegistriesCount().exists()).toBe(false);
  });

  it('initially does not render upstreams count', () => {
    expect(findUpstreamsCount().exists()).toBe(false);
  });

  it('renders CleanupPolicyStatus component', () => {
    expect(findCleanupPolicyStatus().exists()).toBe(true);
  });

  describe('when MavenRegistriesList emits `updateCount` event', () => {
    beforeEach(() => {
      findRegistriesList().vm.$emit('updateCount', 5);
    });

    it('renders registries count', () => {
      expect(findRegistriesCount().text()).toBe('5');
    });
  });

  describe('when MavenUpstreamsList emits `updateCount` event', () => {
    beforeEach(() => {
      findUpstreamsList().vm.$emit('updateCount', 5);
    });

    it('renders registries count', () => {
      expect(findUpstreamsCount().text()).toBe('5');
    });
  });
});
