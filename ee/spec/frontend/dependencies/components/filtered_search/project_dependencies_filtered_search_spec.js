import { shallowMount } from '@vue/test-utils';
import ProjectDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/project_dependencies_filtered_search.vue';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';

describe('ProjectDependenciesFilteredSearch', () => {
  let wrapper;

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(ProjectDependenciesFilteredSearch, {
      provide: {
        glFeatures: {
          versionFilteringOnProjectLevelDependencyList: true,
        },
        ...provide,
      },
    });
  };

  const findDependenciesFilteredSearch = () => wrapper.findComponent(DependenciesFilteredSearch);

  beforeEach(() => {
    createComponent();
  });

  it('sets the filtered search id', () => {
    expect(findDependenciesFilteredSearch().props('filteredSearchId')).toBe(
      'project-level-filtered-search',
    );
  });

  it.each`
    tokenTitle     | tokenConfig
    ${'Component'} | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken }}
    ${'Version'}   | ${{ title: 'Version', type: 'component_version_ids', multiSelect: true, token: VersionToken }}
  `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
    expect(findDependenciesFilteredSearch().props('tokens')).toMatchObject(
      expect.arrayContaining([
        expect.objectContaining({
          ...tokenConfig,
        }),
      ]),
    );
  });

  describe('when version_filtering_on_project_level_dependency_list feature flag is disabled', () => {
    it('does not contain a "Version" token', () => {
      createComponent({
        provide: {
          glFeatures: { versionFilteringOnProjectLevelDependencyList: false },
        },
      });

      expect(findDependenciesFilteredSearch().props('tokens')).not.toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            title: 'Version',
            type: 'version',
            multiSelect: true,
            token: VersionToken,
          }),
        ]),
      );
    });
  });
});
