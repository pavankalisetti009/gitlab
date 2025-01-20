import { shallowMount } from '@vue/test-utils';
import { GlFilteredSearch } from '@gitlab/ui';
import ProjectDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/project_dependencies_filtered_search.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import createStore from 'ee/dependencies/store';

describe('ProjectDependenciesFilteredSearch', () => {
  let wrapper;
  let store;

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = () => {
    wrapper = shallowMount(ProjectDependenciesFilteredSearch, {
      store,
      provide: {
        belowGroupLimit: true,
      },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  beforeEach(createVuexStore);

  describe('search input', () => {
    beforeEach(createComponent);

    it('displays the correct placeholder', () => {
      expect(findFilteredSearch().props('placeholder')).toBe('Search or filter dependencies...');
    });

    it.each`
      tokenTitle     | tokenConfig
      ${'Component'} | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken }}
    `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
      expect(findFilteredSearch().props('availableTokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            ...tokenConfig,
          }),
        ]),
      );
    });
  });

  describe('submit', () => {
    beforeEach(createComponent);

    it('dispatches the "fetchDependencies" Vuex action and resets the pagination', () => {
      expect(store.dispatch).not.toHaveBeenCalled();

      const filterPayload = [{ type: 'license', value: { data: ['MIT'] } }];
      findFilteredSearch().vm.$emit('submit', filterPayload);

      expect(store.dispatch).toHaveBeenCalledWith('allDependencies/fetchDependencies', {
        page: 1,
      });
    });
  });
});
