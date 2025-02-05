import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DependencyExportDropdown from 'ee/dependencies/components/dependency_export_dropdown.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import {
  EXPORT_FORMATS,
  NAMESPACE_GROUP,
  NAMESPACE_ORGANIZATION,
  NAMESPACE_PROJECT,
} from 'ee/dependencies/constants';

describe('DependencyExportDropdown component', () => {
  let store;
  let wrapper;

  const { namespace: allNamespace } = DEPENDENCY_LIST_TYPES.all;

  const factory = ({ provide, props } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    wrapper = shallowMountExtended(DependencyExportDropdown, {
      store,
      propsData: props,
      provide,
    });
  };

  const findDisclosure = () => wrapper.findByTestId('export-disclosure');
  const findDependencyListItem = () => wrapper.findByTestId('dependency-list-item');
  const findCsvItem = () => wrapper.findByTestId('csv-item');
  const findButton = () => wrapper.findComponent(GlButton);

  const itHasCorrectLoadingLogic = (selector) => {
    it('shows export icon in default state', () => {
      const attributes = selector().attributes();
      expect(attributes).toHaveProperty('icon', 'export');
      expect(attributes).not.toHaveProperty('loading', true);
    });

    describe('when request is pending', () => {
      beforeEach(() => {
        store.state[allNamespace].fetchingInProgress = true;
      });

      it('shows loading spinner', () => {
        expect(selector().attributes()).toMatchObject({
          icon: '',
          loading: 'true',
        });
      });
    });
  };

  describe('when container is a project', () => {
    beforeEach(() => {
      factory({ props: { container: NAMESPACE_PROJECT } });
    });

    itHasCorrectLoadingLogic(() => findDisclosure());

    it('shows disclosure with expected items', () => {
      expect(findDisclosure().exists()).toBe(true);
      expect(findDependencyListItem().exists()).toBe(true);
      expect(findCsvItem().exists()).toBe(true);
    });

    it('dispatches dependency list export when item is clicked', () => {
      findDependencyListItem().vm.$emit('action');
      expect(store.dispatch).toHaveBeenCalledWith(`${allNamespace}/fetchExport`, {
        export_type: EXPORT_FORMATS.dependencyList,
      });
    });

    it('dispatches CSV export when item is clicked', () => {
      findCsvItem().vm.$emit('action');
      expect(store.dispatch).toHaveBeenCalledWith(`${allNamespace}/fetchExport`, {
        export_type: EXPORT_FORMATS.csv,
      });
    });
  });

  describe('when container is a group', () => {
    beforeEach(() => {
      factory({ props: { container: NAMESPACE_GROUP } });
    });

    itHasCorrectLoadingLogic(() => findButton());

    it('shows button that dispatches JSON export', () => {
      const button = findButton();

      expect(button.exists()).toBe(true);

      button.vm.$emit('click');

      expect(store.dispatch).toHaveBeenCalledWith(`${allNamespace}/fetchExport`, {
        export_type: EXPORT_FORMATS.jsonArray,
      });
    });
  });

  describe('when container is an organization', () => {
    beforeEach(() => {
      factory({ props: { container: NAMESPACE_ORGANIZATION } });
    });

    itHasCorrectLoadingLogic(() => findButton());

    it('shows button that dispatches CSV export', () => {
      const button = findButton();

      expect(button.exists()).toBe(true);

      button.vm.$emit('click');

      expect(store.dispatch).toHaveBeenCalledWith(`${allNamespace}/fetchExport`, {
        export_type: EXPORT_FORMATS.csv,
      });
    });
  });
});
