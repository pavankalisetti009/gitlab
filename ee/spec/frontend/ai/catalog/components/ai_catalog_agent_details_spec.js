import { shallowMount } from '@vue/test-utils';
import { GlBadge, GlLink, GlToken, GlTruncateText } from '@gitlab/ui';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import AiCatalogItemVisibilityField from 'ee/ai/catalog/components/ai_catalog_item_visibility_field.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import { mockAgent, mockToolsNodes, mockAgentVersion } from '../mock_data';

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  const defaultProps = {
    item: mockAgent,
    versionData: {
      systemPrompt: mockAgentVersion.systemPrompt,
      tools: mockToolsNodes,
    },
  };

  const createComponent = ({ props } = {}) => {
    wrapper = shallowMount(AiCatalogAgentDetails, {
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
  const findVisibilityBadge = () => wrapper.findComponent(GlBadge);
  const findSystemPromptTruncateText = () => wrapper.findComponent(GlTruncateText);
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
      value: mockAgent.name,
    });
    expect(basicInformationDetails.at(1).props()).toMatchObject({
      title: 'Description',
      value: mockAgent.description,
    });
  });

  describe('renders "Visibility & access" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      accessRightsDetails = findAllFieldsForSection(1);
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
      configurationDetails = findAllFieldsForSection(2);
    });

    it('renders "System prompt"', () => {
      expect(configurationDetails.at(0).props()).toMatchObject({
        title: 'System prompt',
      });

      const truncateText = findSystemPromptTruncateText();
      expect(truncateText.props()).toMatchObject({
        lines: 20,
        showMoreText: 'Show more',
        showLessText: 'Show less',
        toggleButtonProps: { class: 'gl-font-regular' },
      });

      expect(configurationDetails.at(0).find('pre').text()).toBe(mockAgentVersion.systemPrompt);
    });

    it('renders "Tools" with sorted values', () => {
      const toolsField = configurationDetails.at(1);
      expect(toolsField.props('title')).toBe('Tools');

      const tokens = toolsField.findAllComponents(GlToken);
      expect(tokens).toHaveLength(3);
      expect(tokens.at(0).text()).toBe('Ci Linter');
      expect(tokens.at(1).text()).toBe('Gitlab Blob Search');
      expect(tokens.at(2).text()).toBe('Run Git Command');
    });
  });
});
