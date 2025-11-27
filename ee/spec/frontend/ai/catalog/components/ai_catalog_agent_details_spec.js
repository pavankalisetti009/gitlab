import { shallowMount } from '@vue/test-utils';
import { GlBadge, GlLink, GlTruncateText } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
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
    expect(findAllSections()).toHaveLength(4);
    expect(findSection(0).attributes('title')).toBe('Basic information');
    expect(findSection(1).attributes('title')).toBe('Visibility & access');
    expect(findSection(2).attributes('title')).toBe('Prompts');
    expect(findSection(3).attributes('title')).toBe('Available tools');
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

  it('renders "Prompts" details', () => {
    const promptsDetails = findAllFieldsForSection(2);
    expect(promptsDetails.at(0).props()).toMatchObject({
      title: 'System prompt',
    });

    const truncateText = findSystemPromptTruncateText();
    expect(truncateText.props()).toMatchObject({
      lines: 20,
      showMoreText: 'Show more',
      showLessText: 'Show less',
      toggleButtonProps: { class: 'gl-font-regular' },
    });

    expect(promptsDetails.at(0).find('pre').text()).toBe(mockAgent.latestVersion.systemPrompt);
  });

  it('renders "Tools" details with sorted values', () => {
    const toolsDetails = findAllFieldsForSection(3);
    expect(toolsDetails.at(0).props()).toMatchObject({
      title: 'Tools',
      value: 'Ci Linter, Gitlab Blob Search, Run Git Command',
    });
  });

  describe('agent versions', () => {
    it('renders system prompt and tools given versionData prop values', async () => {
      const mockSystemPrompt = 'a brand new system prompt';
      const mockTools = [
        { id: 1, title: 'Newest tool' },
        { id: 2, title: 'Older tool' },
      ];
      createComponent({
        props: {
          item: mockAgent,
          versionData: {
            systemPrompt: mockSystemPrompt,
            tools: mockTools,
          },
        },
      });
      await waitForPromises();

      const promptsDetails = findAllFieldsForSection(2);
      expect(promptsDetails.at(0).find('pre').text()).toBe(mockSystemPrompt);
      const toolsDetails = findAllFieldsForSection(3);
      expect(toolsDetails.at(0).props()).toMatchObject({
        title: 'Tools',
        value: 'Newest tool, Older tool',
      });
    });
  });
});
