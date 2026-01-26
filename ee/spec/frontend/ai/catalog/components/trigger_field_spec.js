import { shallowMount } from '@vue/test-utils';
import { GlToken, GlLink, GlSprintf } from '@gitlab/ui';
import TriggerField from 'ee/ai/catalog/components/trigger_field.vue';
import {
  FLOW_TRIGGERS_EDIT_ROUTE,
  FLOW_TRIGGERS_NEW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import { mockFlow, mockFlowConfigurationForProject } from '../mock_data';

describe('TriggerFieldSpec', () => {
  let wrapper;

  const defaultProps = {
    item: mockFlow,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(TriggerField, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findEditLink = () => wrapper.findComponent(GlLink);

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
      const link = wrapper.findComponent(GlLink);

      expect(wrapper.text()).toBe(
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
        },
      });
    });

    it('renders triggers', () => {
      const tokens = wrapper.findAllComponents(GlToken);

      expect(tokens).toHaveLength(1);
      expect(tokens.at(0).text()).toBe('Mention');
    });

    it('renders trigger edit link', () => {
      const editLink = findEditLink();

      expect(editLink.text()).toBe('Edit');
      expect(editLink.props('to')).toEqual({
        name: FLOW_TRIGGERS_EDIT_ROUTE,
        params: { id: 73 },
      });
    });
  });

  describe('when item is foundational', () => {
    beforeEach(() => {
      createComponent({
        props: {
          item: {
            ...mockFlow,
            foundational: true,
            configurationForProject: mockFlowConfigurationForProject,
          },
        },
      });
    });

    it('does not render trigger edit link', () => {
      expect(findEditLink().exists()).toBe(false);
    });
  });
});
