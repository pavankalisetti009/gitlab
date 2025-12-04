import { shallowMount } from '@vue/test-utils';
import { GlToken, GlLink, GlSprintf } from '@gitlab/ui';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import {
  FLOW_TRIGGERS_EDIT_ROUTE,
  FLOW_TRIGGERS_NEW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import {
  mockFlow,
  mockThirdPartyFlow,
  mockFlowConfigurationForProject,
  mockThirdPartyFlowConfigurationForProject,
} from '../mock_data';

describe('AiCatalogFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
    versionData: mockFlow.latestVersion,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(AiCatalogFlowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        AiCatalogItemVisibilityField,
        GlSprintf,
      },
    });
  };

  const findAllSections = () => wrapper.findAllComponents(FormSection);
  const findSection = (index) => findAllSections().at(index);
  const findAllFieldsForSection = (index) =>
    findSection(index).findAllComponents(AiCatalogItemField);
  const findSourceProjectLink = () => wrapper.findComponent(GlLink);

  beforeEach(() => {
    createComponent();
  });

  it('renders sections', () => {
    expect(findAllSections()).toHaveLength(3);
    expect(findSection(0).attributes('title')).toBe('Basic information');
    expect(findSection(1).attributes('title')).toBe('Visibility & access');
    expect(findSection(2).attributes('title')).toBe('Configuration');
  });

  it('renders "Basic information" details', () => {
    const basicInformationDetails = findAllFieldsForSection(0);
    expect(basicInformationDetails.at(0).props()).toMatchObject({
      title: 'Display name',
      value: mockFlow.name,
    });
    expect(basicInformationDetails.at(1).props()).toMatchObject({
      title: 'Description',
      value: mockFlow.description,
    });
  });

  describe('renders "Visibility & access" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      accessRightsDetails = findAllFieldsForSection(1);
    });

    it('renders "Visibility & access" details', () => {
      expect(accessRightsDetails.at(1).props('title')).toBe('Visibility');
      expect(accessRightsDetails.at(1).text()).toContain('Public');
    });

    it('renders "Managed by" with link', () => {
      const sourceProjectField = accessRightsDetails.at(0);
      const link = findSourceProjectLink();

      expect(sourceProjectField.props('title')).toBe('Managed by');
      expect(link.attributes('href')).toBe(mockFlow.project.webUrl);
      expect(link.text()).toBe(mockFlow.project.nameWithNamespace);
    });
  });

  describe('renders "Configuration" details', () => {
    it('renders latestVersion flow definition', () => {
      const configurationField = findAllFieldsForSection(2).at(0);
      expect(configurationField.props('title')).toBe('Configuration');
      expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
        mockFlow.latestVersion.definition,
      );
    });

    it('does not render triggers field', () => {
      const configurationFields = findAllFieldsForSection(2);
      expect(configurationFields).toHaveLength(1);
      expect(configurationFields.at(0).props('title')).toBe('Configuration');
    });

    describe('when configurationForProject exists', () => {
      describe('when flowTrigger is empty', () => {
        beforeEach(() => {
          createComponent({
            props: {
              item: {
                ...mockFlow,
                configurationForProject: {
                  ...mockFlowConfigurationForProject,
                  flowTrigger: null,
                },
              },
            },
          });
        });

        it('renders triggers field as "No triggers configured"', () => {
          const triggersField = findAllFieldsForSection(2).at(0);
          const link = triggersField.findComponent(GlLink);

          expect(triggersField.text()).toBe(
            'No triggers configured. Add a trigger to make this flow available.',
          );
          expect(link.props('to')).toEqual({ name: FLOW_TRIGGERS_NEW_ROUTE });
        });
      });

      describe('when flowTrigger exists', () => {
        beforeEach(() => {
          createComponent({
            props: {
              item: {
                ...mockFlow,
                configurationForProject: mockFlowConfigurationForProject,
              },
              versionData: mockFlowConfigurationForProject.pinnedItemVersion,
            },
          });
        });

        it('renders triggers', () => {
          const triggersField = findAllFieldsForSection(2).at(0);
          expect(triggersField.props('title')).toBe('Triggers');

          const tokens = triggersField.findAllComponents(GlToken);

          expect(tokens).toHaveLength(1);
          expect(tokens.at(0).text()).toBe('Mention');
        });

        it('renders trigger edit link', () => {
          const triggersField = findAllFieldsForSection(2).at(0);
          const editLink = triggersField.findComponent(GlLink);

          expect(editLink.text()).toBe('Edit');
          expect(editLink.props('to')).toEqual({
            name: FLOW_TRIGGERS_EDIT_ROUTE,
            params: { id: 73 },
          });
        });

        it('renders pinnedItemVersion flow definition', () => {
          const configurationField = findAllFieldsForSection(2).at(1);
          expect(configurationField.props('title')).toBe('Configuration');
          expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
            mockFlowConfigurationForProject.pinnedItemVersion.definition,
          );
        });
      });
    });
  });

  describe('when the flow is third-party flow', () => {
    beforeEach(() => {
      createComponent({
        props: {
          versionData: {
            ...mockThirdPartyFlowConfigurationForProject.pinnedItemVersion,
          },
          item: {
            ...mockThirdPartyFlow,
            configurationForProject: {
              ...mockThirdPartyFlowConfigurationForProject,
              flowTrigger: null,
            },
          },
        },
      });
    });

    it('renders sections', () => {
      expect(findAllSections()).toHaveLength(3);
      expect(findSection(0).attributes('title')).toBe('Basic information');
      expect(findSection(1).attributes('title')).toBe('Visibility & access');
      expect(findSection(2).attributes('title')).toBe('Configuration');
    });

    it('renders triggers field as "No triggers configured"', () => {
      const triggersField = findAllFieldsForSection(2).at(0);

      expect(triggersField.text()).toBe(
        'No triggers configured. Add a trigger to make this flow available.',
      );
    });

    it('renders "Configuration" details', () => {
      const configurationField = findAllFieldsForSection(2).at(1);
      expect(configurationField.props('title')).toBe('Configuration');
      expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
        mockThirdPartyFlowConfigurationForProject.pinnedItemVersion.definition,
      );
    });
  });
});
