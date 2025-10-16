import { shallowMount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import AiCatalogAgentDetails from 'ee/ai/catalog/components/ai_catalog_agent_details.vue';
import AiCatalogItemField from 'ee/ai/catalog/components/ai_catalog_item_field.vue';
import FormSection from 'ee/ai/catalog/components/form_section.vue';
import { mockAgent, mockAgentVersion, mockToolsTitles } from '../mock_data';

describe('AiCatalogAgentDetails', () => {
  let wrapper;

  const defaultProps = {
    item: {
      ...mockAgent,
      latestVersion: {
        ...mockAgentVersion,
        tools: {
          nodes: mockToolsTitles.map((t) => ({ title: t })),
        },
      },
    },
  };

  const createComponent = ({ props = defaultProps } = {}) => {
    wrapper = shallowMount(AiCatalogAgentDetails, {
      propsData: {
        ...props,
      },
    });
  };

  const findAllSections = () => wrapper.findAllComponents(FormSection);
  const findSection = (index) => findAllSections().at(index);
  const findAllFieldsForSection = (index) =>
    findSection(index).findAllComponents(AiCatalogItemField);
  const findVisibilityBadge = () => wrapper.findComponent(GlBadge);

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

  describe('renders "Access rights" details', () => {
    let accessRightsDetails;
    beforeEach(() => {
      accessRightsDetails = findAllFieldsForSection(1);
    });

    it('renders Visibility', () => {
      expect(accessRightsDetails.at(0).props()).toMatchObject({
        title: 'Visibility',
      });
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

    it('renders Source project', () => {
      expect(accessRightsDetails.at(1).props()).toMatchObject({
        title: 'Source project',
        value: mockAgent.project.nameWithNamespace,
      });
    });
  });

  it('renders "Prompts" details', () => {
    const promptsDetails = findAllFieldsForSection(2);
    expect(promptsDetails.at(0).props()).toMatchObject({
      title: 'System prompt',
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
});
