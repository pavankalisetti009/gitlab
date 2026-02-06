import { GlBadge, GlLink, GlToken, GlTruncateText, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import TriggerField from 'ee/ai/catalog/components/trigger_field.vue';
import { VERSION_LATEST } from 'ee/ai/catalog/constants';
import {
  mockAgent,
  mockAgentVersion,
  mockThirdPartyFlow,
  mockThirdPartyFlowVersion,
  mockThirdPartyFlowConfigurationForProject,
  mockAiCatalogBuiltInToolsNodes,
  mockServiceAccount,
  mockItemConfigurationForGroup,
} from '../mock_data';

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  // Sorted non-alphabetically to test sorting functionality
  const mockToolNodes = {
    nodes: [
      mockAiCatalogBuiltInToolsNodes[2], // Run Git Command
      mockAiCatalogBuiltInToolsNodes[1], // Gitlab Blob Search
      mockAiCatalogBuiltInToolsNodes[0], // Ci Linter
    ],
  };

  const defaultProps = {
    item: {
      ...mockAgent,
      latestVersion: {
        ...mockAgentVersion,
        tools: mockToolNodes,
      },
    },
    versionKey: VERSION_LATEST,
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMountExtended(AiCatalogAgentDetails, {
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
  const findVisibilityBadge = () => wrapper.findComponent(GlBadge);
  const findSystemPromptTruncateText = () => wrapper.findComponent(GlTruncateText);
  const findSourceProjectLink = () => wrapper.findComponent(GlLink);
  const findTriggerField = () => wrapper.findComponent(TriggerField);
  const findServiceAccountField = () => wrapper.findByTestId('service-account-field');
  const findManagedByField = () => wrapper.findByTestId('managed-by-field');

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders sections', () => {
      expect(findAllSections()).toHaveLength(2);
      expect(findSection(0).attributes('title')).toBe('Visibility & access');
      expect(findSection(1).attributes('title')).toBe('Configuration');
    });
  });

  describe('renders "Visibility & access" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      createComponent();
      accessRightsDetails = findAllFieldsForSection(0);
    });

    it('renders Visibility', () => {
      expect(accessRightsDetails.at(1).props('title')).toBe('Visibility');
      expect(accessRightsDetails.at(1).text()).toContain('Public');
      expect(findVisibilityBadge().exists()).toBe(true);
    });

    it.each`
      isPublic | badgeLabel   | badgeIcon
      ${false} | ${'Private'} | ${'lock'}
      ${true}  | ${'Public'}  | ${'earth'}
    `(
      'displays badge with $badgeLabel label and icon $badgeIcon when agent public prop is $isPublic',
      ({ isPublic, badgeLabel, badgeIcon }) => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              public: isPublic,
            },
          },
        });

        expect(findVisibilityBadge().text()).toBe(badgeLabel);
        expect(findVisibilityBadge().props('icon')).toBe(badgeIcon);
      },
    );

    it('renders "Managed by" with link', () => {
      const sourceProjectField = accessRightsDetails.at(0);
      const link = findSourceProjectLink();

      expect(sourceProjectField.props('title')).toBe('Managed by');
      expect(link.attributes('href')).toBe(mockAgent.project.webUrl);
      expect(link.text()).toBe(mockAgent.project.nameWithNamespace);
    });
  });

  describe('renders "Configuration" details', () => {
    let configurationDetails;

    beforeEach(() => {
      createComponent();
      configurationDetails = findAllFieldsForSection(1);
    });

    it('renders "Type" field with "Custom" value', () => {
      expect(configurationDetails.at(0).props()).toMatchObject({
        title: 'Type',
        value: 'Custom',
      });
    });

    it('does not render "Service account" field', () => {
      expect(findServiceAccountField().exists()).toBe(false);
    });

    it('renders "System prompt"', () => {
      expect(configurationDetails.at(2).props()).toMatchObject({
        title: 'System prompt',
      });

      const truncateText = findSystemPromptTruncateText();
      expect(truncateText.props()).toMatchObject({
        lines: 20,
        showMoreText: 'Show more',
        showLessText: 'Show less',
        toggleButtonProps: { class: 'gl-font-regular' },
      });

      expect(configurationDetails.at(2).find('pre').text()).toBe(mockAgentVersion.systemPrompt);
    });

    it('renders "Tools" with sorted values', () => {
      const toolsField = configurationDetails.at(1);
      expect(toolsField.props('title')).toBe('Tools');

      const tokens = toolsField.findAllComponents(GlToken);
      expect(tokens).toHaveLength(3);
      expect(tokens.at(0).text()).toBe('Ci Linter');
      expect(tokens.at(1).text()).toBe('Gitlab Blob Search');
      expect(tokens.at(2).text()).toBe('Run Git Command');

      const tokensTooltips = wrapper.findAllByTestId('tool-description-tooltip');
      expect(tokensTooltips).toHaveLength(3);
      expect(tokensTooltips.at(0).attributes('title')).toBe('Ci Linter Tool description');
      expect(tokensTooltips.at(1).attributes('title')).toBe('Gitlab Blob Search Tool description');
      expect(tokensTooltips.at(2).attributes('title')).toBe('Run Git Command Tool description');
    });
  });

  describe('when the item is a third-party flow', () => {
    let configurationDetails;

    beforeEach(() => {
      createComponent({
        props: {
          item: {
            ...mockThirdPartyFlow,
            latestVersion: {
              ...mockThirdPartyFlowVersion,
            },
            configurationForProject: {
              ...mockThirdPartyFlowConfigurationForProject,
            },
          },
        },
      });

      configurationDetails = findAllFieldsForSection(1);
    });

    it('renders the trigger field', () => {
      expect(findTriggerField().exists()).toBe(true);
    });

    it('renders "Type" field with "External" value', () => {
      expect(configurationDetails.at(0).props()).toMatchObject({
        title: 'Type',
        value: 'External',
      });
    });

    it('renders "Service account" field', () => {
      expect(findServiceAccountField().props()).toMatchObject({
        serviceAccount: mockServiceAccount,
        itemType: 'THIRD_PARTY_FLOW',
      });
    });

    it('renders "Configuration" field', () => {
      const configurationField = configurationDetails.at(1);
      expect(configurationField.props('title')).toBe('Configuration');
      expect(configurationField.findComponent(FormFlowDefinition).props('value')).toBe(
        mockThirdPartyFlowVersion.definition,
      );
    });
  });

  describe('when the item is a foundational agent', () => {
    describe('and has configurationForGroup', () => {
      let configurationDetails;

      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              foundational: true,
              configurationForGroup: mockItemConfigurationForGroup,
            },
          },
        });

        configurationDetails = findAllFieldsForSection(1);
      });

      it('renders "Type" field with "Foundational" value', () => {
        expect(configurationDetails.at(0).props()).toMatchObject({
          title: 'Type',
          value: 'Foundational',
        });
      });

      it('renders "Tools" field', () => {
        const toolsField = configurationDetails.at(1);
        expect(toolsField.props('title')).toBe('Tools');
        expect(toolsField.text()).toContain(
          'Tools are built and maintained by GitLab. What are tools?',
        );
        expect(toolsField.text()).toContain('None');
      });

      it('renders "System prompt"', () => {
        expect(configurationDetails.at(2).props()).toMatchObject({
          title: 'System prompt',
        });
      });

      it('renders "Managed by" field', () => {
        expect(findManagedByField().props('title')).toBe('Managed by');
        expect(findManagedByField().text()).toBe(
          'Foundational agents are managed by the top-level group.',
        );
      });

      it('renders link to correct group settings URL', () => {
        const managedByLink = findManagedByField().findComponent(GlLink);
        expect(managedByLink.attributes('href')).toBe(
          '/groups/mock-group/-/settings/gitlab_duo/configuration',
        );
      });
    });

    describe('and does not have configurationForGroup', () => {
      beforeEach(() => {
        createComponent({
          props: {
            item: {
              ...mockAgent,
              foundational: true,
              configurationForGroup: null,
            },
          },
        });
      });

      it('renders link to help documentation', () => {
        const managedByLink = findManagedByField().findComponent(GlLink);
        expect(managedByLink.attributes('href')).toContain('/help/');
      });
    });
  });
});
