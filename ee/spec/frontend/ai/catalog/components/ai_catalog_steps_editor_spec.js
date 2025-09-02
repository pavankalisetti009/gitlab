import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogStepsEditor from 'ee/ai/catalog/components/ai_catalog_steps_editor.vue';
import AiCatalogNodeField from 'ee/ai/catalog/components/ai_catalog_node_field.vue';

describe('AiCatalogStepsEditor', () => {
  let wrapper;

  const agents = [
    { value: 'gid://gitlab/Ai::Catalog::Item/1', text: 'Test AI Agent 1' },
    { value: 'gid://gitlab/Ai::Catalog::Item/2', text: 'Test AI Agent 2' },
    { value: 'gid://gitlab/Ai::Catalog::Item/3', text: 'Test AI Agent 3' },
  ];

  const selectedSteps = [
    { id: 'gid://gitlab/Ai::Catalog::Item/1', name: 'Test AI Agent 1' },
    { id: 'gid://gitlab/Ai::Catalog::Item/3', name: 'Test AI Agent 3' },
  ];

  const createComponent = ({ steps = [] } = {}) => {
    wrapper = shallowMountExtended(AiCatalogStepsEditor, {
      propsData: {
        steps,
      },
    });
  };

  const findNewNodeButton = () => wrapper.findComponent(GlButton);
  const findNodeFields = () => wrapper.findAllComponents(AiCatalogNodeField);
  const findFirstNodeField = () => findNodeFields().at(0);

  beforeEach(() => {
    createComponent();
  });

  describe('empty state', () => {
    it('renders new node button', () => {
      expect(findNewNodeButton().exists()).toBe(true);
      expect(findNewNodeButton().text()).toEqual('Flow node');
      expect(findNewNodeButton().props('icon')).toEqual('plus');
    });

    it('does not render the AiCatalogNodeField component', () => {
      expect(findNodeFields()).toHaveLength(0);
    });
  });

  describe('with existing steps', () => {
    beforeEach(() => {
      createComponent({ steps: selectedSteps });
    });

    it('renders as many AiCatalogNodeField components as there are steps', () => {
      expect(findNodeFields()).toHaveLength(2);
      expect(findFirstNodeField().props('selected')).toMatchObject(agents[0]);
      expect(findNodeFields().at(1).props('selected')).toMatchObject(agents[2]);
    });
  });

  describe('events', () => {
    it('emits openAgentPanel event on click New flow node button', () => {
      findNewNodeButton().vm.$emit('click');

      expect(wrapper.emitted('openAgentPanel')).toEqual([[0]]);
    });

    describe('with existing steps', () => {
      beforeEach(() => {
        createComponent({ steps: selectedSteps });
      });

      it('emits openAgentPanel event on click New flow node button with next index', () => {
        findNewNodeButton().vm.$emit('click');

        expect(wrapper.emitted('openAgentPanel')).toEqual([[2]]);
      });

      it('emits openAgentPanel event on click Node field primary button with matching index', () => {
        findNodeFields().at(1).vm.$emit('primary');

        expect(wrapper.emitted('openAgentPanel')).toEqual([[1]]);
      });
    });
  });
});
