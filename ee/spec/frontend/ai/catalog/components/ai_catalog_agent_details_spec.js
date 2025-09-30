import { shallowMount } from '@vue/test-utils';
import Markdown from '~/vue_shared/components/markdown/markdown_content.vue';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import { mockAgent, mockAgentVersion } from '../mock_data';

const TOOLS = ['A Tool', 'Another Tool'];

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  const defaultProps = {
    item: {
      ...mockAgent,
      latestVersion: {
        ...mockAgentVersion,
        tools: {
          nodes: TOOLS.map((t) => ({ title: t })),
        },
      },
    },
  };

  const createComponent = () => {
    wrapper = shallowMount(AiCatalogAgentDetails, {
      propsData: {
        ...defaultProps,
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
    expect(findAllSections()).toHaveLength(4);
    expect(findSection(0).attributes('title')).toBe('Basic information');
    expect(findSection(1).attributes('title')).toBe('Access rights');
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

  it('renders "Access rights" details', () => {
    const accessRightsDetails = findAllFieldsForSection(1);
    expect(accessRightsDetails.at(0).props()).toMatchObject({
      title: 'Source project',
      value: mockAgent.project.nameWithNamespace,
    });
  });

  it('renders "Prompts" details', () => {
    const promptsDetails = findAllFieldsForSection(2);
    expect(promptsDetails.at(0).findComponent(Markdown).props()).toMatchObject({
      value: mockAgent.latestVersion.systemPrompt,
      fallbackOnError: true,
    });
    expect(promptsDetails.at(1).findComponent(Markdown).props()).toMatchObject({
      value: mockAgent.latestVersion.userPrompt,
      fallbackOnError: true,
    });
  });

  it('renders "Tools" details', () => {
    const toolsDetails = findAllFieldsForSection(3);
    expect(toolsDetails.at(0).props()).toMatchObject({
      title: 'Tools',
      value: TOOLS.join(', '),
    });
  });
});
