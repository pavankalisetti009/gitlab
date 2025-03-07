import { GlFilteredSearchToken } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';
import createStore from 'ee/dependencies/store';

describe('ee/dependencies/components/filtered_search/tokens/version_token.vue', () => {
  let wrapper;
  let store;

  const createVuexStore = () => {
    store = createStore();
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(VersionToken, {
      store,
      propsData: {
        config: {
          multiSelect: true,
        },
        value: {},
        active: false,
      },
      stubs: {
        GlFilteredSearchToken: stubComponent(GlFilteredSearchToken, {
          template: `<div><slot name="view"></slot><slot name="suggestions"></slot></div>`,
        }),
      },
    });
  };

  const findFilteredSearchToken = () => wrapper.findComponent(GlFilteredSearchToken);

  beforeEach(() => {
    createVuexStore();
    createComponent();
  });

  describe('when the component is initially rendered', () => {
    it('passes the correct props to the GlFilteredSearchToken', () => {
      expect(findFilteredSearchToken().props()).toMatchObject({
        config: { multiSelect: true },
        value: { data: [] },
        viewOnly: true,
        active: false,
      });
    });
  });

  describe('when no components are selected', () => {
    it('shows the correct guidance message', () => {
      expect(findFilteredSearchToken().text()).toBe(
        'To filter by version, filter by one component first',
      );
    });

    it('sets viewOnly prop to true', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(true);
    });
  });

  describe('when multiple components are selected', () => {
    beforeEach(() => {
      store.state.allDependencies.searchFilterParameters = {
        component_names: ['component-1', 'component-2'],
      };
    });

    it('shows the correct guidance message', () => {
      expect(findFilteredSearchToken().text()).toBe(
        'To filter by version, select exactly one component first',
      );
    });

    it('sets viewOnly prop to true', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(true);
    });
  });

  describe('when exactly one component is selected', () => {
    beforeEach(() => {
      store.state.allDependencies.searchFilterParameters = {
        component_names: ['component-1'],
      };
    });

    it('does not show any guidance messages', () => {
      expect(findFilteredSearchToken().text()).toBe('');
    });

    it('sets viewOnly prop to false', () => {
      expect(findFilteredSearchToken().props('viewOnly')).toBe(false);
    });
  });
});
