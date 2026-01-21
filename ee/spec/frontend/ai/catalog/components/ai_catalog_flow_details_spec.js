import { GlAvatarLabeled, GlAvatarLink, GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogFlowDetails from 'ee/ai/catalog/components/ai_catalog_flow_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import TriggerField from 'ee/ai/catalog/components/trigger_field.vue';
import { VERSION_LATEST, VERSION_PINNED } from 'ee/ai/catalog/constants';
import { mockFlow, mockFlowConfigurationForProject, mockServiceAccount } from '../mock_data';

describe('AiCatalogFlowDetails', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
    versionKey: VERSION_LATEST,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AiCatalogFlowDetails, {
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
  const findTriggerField = () => wrapper.findComponent(TriggerField);
  const findServiceAccountAvatar = () => wrapper.findComponent(GlAvatarLabeled);
  const findServiceAccountLink = () => wrapper.findComponent(GlAvatarLink);
  const findServiceAccountField = () => wrapper.findByTestId('service-account-field');
  const findConfigurationField = () => wrapper.findByTestId('configuration-field');

  beforeEach(() => {
    createComponent();
  });

  it('renders sections', () => {
    expect(findAllSections()).toHaveLength(2);
    expect(findSection(0).attributes('title')).toBe('Visibility & access');
    expect(findSection(1).attributes('title')).toBe('Configuration');
  });

  describe('renders "Visibility & access" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      accessRightsDetails = findAllFieldsForSection(0);
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
      expect(findConfigurationField().props('title')).toBe('YAML configuration');
      expect(findConfigurationField().findComponent(FormFlowDefinition).props('value')).toBe(
        mockFlow.latestVersion.definition,
      );
    });

    it('does not render triggers field', () => {
      const configurationFields = findAllFieldsForSection(1);
      expect(configurationFields).toHaveLength(1);
    });

    describe('when configurationForProject exists', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForProject: {
                ...mockFlowConfigurationForProject,
              },
            },
            versionKey: VERSION_PINNED,
          },
        });
      });

      it('renders the trigger field', () => {
        expect(findTriggerField().exists()).toBe(true);
      });

      it('renders pinnedItemVersion flow definition', () => {
        expect(findConfigurationField().findComponent(FormFlowDefinition).props('value')).toBe(
          mockFlowConfigurationForProject.pinnedItemVersion.definition,
        );
      });
    });

    describe('when configurationForGroup.serviceAccount exists', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockFlow,
              configurationForGroup: {
                serviceAccount: mockServiceAccount,
              },
            },
          },
        });
      });

      it('renders service account avatar', () => {
        expect(findServiceAccountAvatar().props()).toMatchObject({
          size: 32,
          src: mockServiceAccount.avatarUrl,
          label: mockServiceAccount.name,
          subLabel: `@${mockServiceAccount.username}`,
        });
      });

      it('renders service account link', () => {
        expect(findServiceAccountLink().attributes()).toMatchObject({
          href: mockServiceAccount.webPath,
          title: mockServiceAccount.name,
        });
      });

      describe('renders service account help text', () => {
        it('renders help text with full phrase', () => {
          const helpText = findServiceAccountField().text();
          expect(helpText).toBe(
            'Service accounts represent non-human entities. This is the account that you mention or assign to trigger the flow.',
          );
        });

        it('renders service account docs link in help text', () => {
          const link = findServiceAccountField().findComponent(GlLink);
          expect(link.attributes('href')).toBe('/help/user/profile/service_accounts');
        });
      });
    });
  });
});
