import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import CustomFieldsList from 'ee/groups/settings/work_items/custom_fields/custom_fields_list.vue';
import CustomStatusSettings from 'ee/groups/settings/work_items/custom_status/custom_status_settings.vue';
import ConfigurableTypesSettings from 'ee/groups/settings/work_items/configurable_types/configurable_types_settings.vue';
import SearchSettings from '~/search_settings/components/search_settings.vue';
import WorkItemSettingsHome from 'ee/groups/settings/work_items/work_item_settings_home.vue';
import { DEFAULT_SETTINGS_CONFIG } from 'ee/work_items/constants';

describe('WorkItemSettingsHome', () => {
  let wrapper;
  const fullPath = 'group/project';

  const createComponent = ({
    mocks = {},
    glFeatures = { workItemConfigurableTypes: true },
    props = {
      config: {
        ...DEFAULT_SETTINGS_CONFIG,
      },
    },
  } = {}) => {
    wrapper = shallowMount(WorkItemSettingsHome, {
      propsData: {
        fullPath,
        ...props,
      },
      mocks: {
        $route: { hash: '' },
        ...mocks,
      },
      provide: {
        glFeatures,
      },
    });
  };

  const findCustomFieldsList = () => wrapper.findComponent(CustomFieldsList);
  const findCustomStatusSettings = () => wrapper.findComponent(CustomStatusSettings);
  const findConfigurableTypesSettings = () => wrapper.findComponent(ConfigurableTypesSettings);
  const findSearchSettings = () => wrapper.findComponent(SearchSettings);

  describe('Component Rendering', () => {
    it('renders ConfigurableTypesSettings component with correct props when FF is switched on', () => {
      createComponent();

      expect(findConfigurableTypesSettings().exists()).toBe(true);
      expect(findConfigurableTypesSettings().props('fullPath')).toBe(fullPath);
    });

    it('does not render ConfigurableTypesSettings when `workItemConfigurableTypes` FF is off', () => {
      createComponent({
        glFeatures: { workItemConfigurableTypes: false },
      });

      expect(findConfigurableTypesSettings().exists()).toBe(false);
    });

    it('always renders CustomFieldsList component with correct props', () => {
      createComponent();

      expect(findCustomFieldsList().exists()).toBe(true);
      expect(findCustomFieldsList().props('fullPath')).toBe(fullPath);
    });

    it('renders CustomStatusSettings component with correct props', () => {
      createComponent();

      expect(findCustomStatusSettings().exists()).toBe(true);
    });
  });

  describe('SearchSettings', () => {
    it('renders SearchSettings component when searchRoot is available', async () => {
      createComponent();

      await nextTick();

      expect(findSearchSettings().exists()).toBe(true);
    });

    it('passes correct props to SearchSettings', async () => {
      createComponent();

      await nextTick();

      const searchSettings = findSearchSettings();
      expect(searchSettings.props('sectionSelector')).toBe('.vue-settings-block');
    });
  });

  describe('Toggle Expand', () => {
    let mockRouter;

    beforeEach(() => {
      mockRouter = {
        push: jest.fn(),
      };
    });

    it.each`
      component                      | componentFinder                  | sectionId
      ${'CustomStatusSettings'}      | ${findCustomStatusSettings}      | ${'js-custom-status-settings'}
      ${'CustomFieldsList'}          | ${findCustomFieldsList}          | ${'js-custom-fields-settings'}
      ${'ConfigurableTypesSettings'} | ${findConfigurableTypesSettings} | ${'js-work-item-types-settings'}
    `(
      'navigates to hash when $component toggle-expand emits true',
      async ({ componentFinder, sectionId }) => {
        createComponent({ mocks: { $router: mockRouter } });

        await componentFinder().vm.$emit('toggle-expand', true);

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: 'workItemSettingsHome',
          hash: `#${sectionId}`,
        });
      },
    );

    it('clears hash when toggling to false without existing hash', async () => {
      createComponent({ mocks: { $router: mockRouter, $route: { hash: '' } } });

      await findCustomStatusSettings().vm.$emit('toggle-expand', false);

      expect(mockRouter.push).not.toHaveBeenCalled();
    });

    it('clears hash when toggling to false with existing hash', async () => {
      createComponent({
        mocks: {
          $router: mockRouter,
          $route: { hash: '#js-custom-status-settings' },
        },
      });

      await findCustomStatusSettings().vm.$emit('toggle-expand', false);

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: 'workItemSettingsHome',
        hash: '',
      });
    });
  });

  describe('Expanded State from Route Hash', () => {
    it.each`
      component                      | componentFinder                  | sectionId
      ${'CustomStatusSettings'}      | ${findCustomStatusSettings}      | ${'js-custom-status-settings'}
      ${'CustomFieldsList'}          | ${findCustomFieldsList}          | ${'js-custom-fields-settings'}
      ${'ConfigurableTypesSettings'} | ${findConfigurableTypesSettings} | ${'js-work-item-types-settings'}
    `('expands $component when route hash matches section id', ({ componentFinder, sectionId }) => {
      createComponent({ mocks: { $route: { hash: `#${sectionId}` } } });

      expect(componentFinder().props('expanded')).toBe(true);
    });

    it('does not expand sections when hash does not match', () => {
      createComponent({ mocks: { $route: { hash: '#other-section' } } });

      expect(findCustomStatusSettings().props('expanded')).toBe(false);
      expect(findCustomFieldsList().props('expanded')).toBe(false);
      expect(findConfigurableTypesSettings().props('expanded')).toBe(false);
    });
  });

  describe('Multiple sections visibility', () => {
    it.each`
      showWorkItemTypes | showCustomStatus | showCustomFields | expectedTypes | expectedStatus | expectedFields
      ${false}          | ${false}         | ${true}          | ${false}      | ${false}       | ${true}
      ${true}           | ${true}          | ${true}          | ${true}       | ${true}        | ${true}
      ${false}          | ${false}         | ${false}         | ${false}      | ${false}       | ${false}
      ${true}           | ${false}         | ${true}          | ${true}       | ${false}       | ${true}
    `(
      'renders correct components with configuration: types=$showWorkItemTypes, status=$showCustomStatus, fields=$showCustomFields',
      ({
        showWorkItemTypes,
        showCustomStatus,
        showCustomFields,
        expectedTypes,
        expectedStatus,
        expectedFields,
      }) => {
        createComponent({
          props: {
            config: {
              showWorkItemTypesSettings: showWorkItemTypes,
              showCustomStatusSettings: showCustomStatus,
              showCustomFieldsSettings: showCustomFields,
              layout: 'list',
            },
          },
        });

        expect(findConfigurableTypesSettings().exists()).toBe(expectedTypes);
        expect(findCustomStatusSettings().exists()).toBe(expectedStatus);
        expect(findCustomFieldsList().exists()).toBe(expectedFields);
      },
    );
  });
});
