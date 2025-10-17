import { shallowMount } from '@vue/test-utils';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import { mockFlow, mockFlowVersion, mockThirdPartyFlow } from '../mock_data';

describe('AiCatalogFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(AiCatalogFlowDetails, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        AiCatalogItemVisibilityField,
      },
    });
  };

  const findAllSections = () => wrapper.findAllComponents(FormSection);
  const findSection = (index) => findAllSections().at(index);
  const findAllFieldsForSection = (index) =>
    findSection(index).findAllComponents(AiCatalogItemField);

  beforeEach(() => {
    createComponent();
  });

  it('renders sections', () => {
    expect(findAllSections()).toHaveLength(3);
    expect(findSection(0).attributes('title')).toBe('Basic information');
    expect(findSection(1).attributes('title')).toBe('Visibility & access');
    expect(findSection(2).attributes('title')).toBe('Steps');
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

  it('renders "Visibility & access" details', () => {
    const accessRightsDetails = findAllFieldsForSection(1);
    expect(accessRightsDetails.at(0).props('title')).toBe('Visibility');
    expect(accessRightsDetails.at(0).text()).toContain('Public');
    expect(accessRightsDetails.at(1).props()).toMatchObject({
      title: 'Source project',
      value: mockFlow.project.nameWithNamespace,
    });
  });

  it('renders "Steps" details', () => {
    const stepsDetails = findAllFieldsForSection(2);
    expect(stepsDetails.at(0).props('title')).toBe('Steps');
    expect(stepsDetails.at(0).text()).toContain(mockFlowVersion.steps.nodes[0].agent.name);
  });

  describe('when the flow is third-party flow', () => {
    beforeEach(() => {
      createComponent({
        props: {
          item: mockThirdPartyFlow,
        },
      });
    });

    it('renders sections', () => {
      expect(findAllSections()).toHaveLength(3);
      expect(findSection(0).attributes('title')).toBe('Basic information');
      expect(findSection(1).attributes('title')).toBe('Visibility & access');
      expect(findSection(2).attributes('title')).toBe('Configuration');
    });

    it('renders "Configuration" details', () => {
      const configurationField = findAllFieldsForSection(2).at(0);
      expect(configurationField.props('title')).toBe('Configuration');
      expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
        mockThirdPartyFlow.latestVersion.definition,
      );
    });
  });
});
