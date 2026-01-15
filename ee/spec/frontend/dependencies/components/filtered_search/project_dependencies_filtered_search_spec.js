import { shallowMount } from '@vue/test-utils';
import {
  OPERATORS_IS,
  OPERATORS_IS_NOT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import ProjectDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/project_dependencies_filtered_search.vue';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import VersionToken from 'ee/dependencies/components/filtered_search/tokens/version_token.vue';
import ActivityToken from 'ee/dependencies/components/filtered_search/tokens/activity_token.vue';

describe('ProjectDependenciesFilteredSearch', () => {
  let wrapper;

  const createComponent = ({ provide = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMount(ProjectDependenciesFilteredSearch, {
      provide: {
        glFeatures,
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
    ${'Component'} | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken, operators: OPERATORS_IS }}
    ${'Version'}   | ${{ title: 'Version', type: 'component_versions', multiSelect: true, token: VersionToken, operators: OPERATORS_IS_NOT }}
  `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
    expect(findDependenciesFilteredSearch().props('tokens')).toMatchObject(
      expect.arrayContaining([
        expect.objectContaining({
          ...tokenConfig,
        }),
      ]),
    );
  });

  describe('Activity token', () => {
    it('does not include Activity token when feature flag is disabled', () => {
      createComponent({ glFeatures: { securityPolicyWarnModeLicenseScanning: false } });

      const tokens = findDependenciesFilteredSearch().props('tokens');
      expect(tokens).not.toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            type: 'component_activity',
          }),
        ]),
      );
    });

    it('includes Activity token when feature flag is enabled', () => {
      createComponent({ glFeatures: { securityPolicyWarnModeLicenseScanning: true } });

      const tokens = findDependenciesFilteredSearch().props('tokens');
      expect(tokens).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            title: 'Activity',
            type: 'component_activity',
            multiSelect: false,
            unique: true,
            token: ActivityToken,
            operators: OPERATORS_IS,
          }),
        ]),
      );
    });
  });
});
