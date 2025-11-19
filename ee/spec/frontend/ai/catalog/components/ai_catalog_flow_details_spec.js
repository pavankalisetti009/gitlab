import { shallowMount } from '@vue/test-utils';
import { GlBadge, GlLink } from '@gitlab/ui';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import { FLOW_TRIGGERS_EDIT_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import { mockFlow, mockThirdPartyFlow, mockFlowConfigurationForProject } from '../mock_data';

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
      expect(accessRightsDetails.at(0).props('title')).toBe('Visibility');
      expect(accessRightsDetails.at(0).text()).toContain('Public');
    });

    it('renders source project with link', () => {
      const sourceProjectField = accessRightsDetails.at(1);
      const link = findSourceProjectLink();

      expect(sourceProjectField.props('title')).toBe('Source project');
      expect(link.attributes('href')).toBe(mockFlow.project.webUrl);
      expect(link.text()).toBe(mockFlow.project.nameWithNamespace);
    });
  });

  describe('renders "Configuration" details', () => {
    it('renders flow definition', () => {
      const configurationField = findAllFieldsForSection(2).at(0);
      expect(configurationField.props('title')).toBe('Configuration');
      expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
        mockFlow.latestVersion.definition,
      );
    });

    describe('when configurationForProject.flowTrigger exists', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: mockFlowConfigurationForProject,
            },
          },
        });
      });

      it('renders triggers', () => {
        const triggersField = findAllFieldsForSection(2).at(0);
        expect(triggersField.props('title')).toBe('Triggers');

        const badges = triggersField.findAllComponents(GlBadge);

        expect(badges).toHaveLength(1);
        expect(badges.at(0).text()).toBe('Mention');
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

      it('renders flow definition', () => {
        const configurationField = findAllFieldsForSection(2).at(1);
        expect(configurationField.props('title')).toBe('Configuration');
        expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
          mockFlow.latestVersion.definition,
        );
      });
    });
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
