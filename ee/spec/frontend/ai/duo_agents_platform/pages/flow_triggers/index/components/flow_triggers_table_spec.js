import { GlToken, GlAvatar } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FlowTriggersTable from 'ee/ai/duo_agents_platform/pages/flow_triggers/index/components/flow_triggers_table.vue';
import { FLOW_TRIGGERS_EDIT_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';
import {
  mockTriggers,
  mockTriggersWithoutUser,
  mockTriggersConfigPath,
  eventTypeOptions,
} from '../../mocks';

describe('FlowTriggersTable', () => {
  let wrapper;

  const findAvatar = () => wrapper.findComponent(GlAvatar);
  const findTokens = () => wrapper.findAllComponents(GlToken);
  const findConfigPath = () => wrapper.findByTestId('flow-trigger-config-path');
  const findConfigPathFallback = () => wrapper.findByTestId('flow-trigger-config-path-fallback');
  const findEditButton = () => wrapper.findByTestId('flow-trigger-edit-action');
  const findDeleteButton = () => wrapper.findByTestId('flow-trigger-delete-action');

  const createComponent = (props = {}) => {
    wrapper = mountExtended(FlowTriggersTable, {
      propsData: {
        aiFlowTriggers: mockTriggers,
        eventTypeOptions,
        ...props,
      },
    });
  };

  describe('Rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('displays correct event type tokens', () => {
      const tokens = findTokens();

      expect(tokens).toHaveLength(2);
      expect(tokens.at(0).text()).toBe('Mention');
      expect(tokens.at(1).text()).toBe('Assign');
    });

    it('sets a link to edit the item', () => {
      expect(findEditButton().props('to')).toEqual({
        name: FLOW_TRIGGERS_EDIT_ROUTE,
        params: { id: 1 },
      });
    });

    describe('when there is a config path', () => {
      it('displays the config path', () => {
        expect(findConfigPath().exists()).toBe(true);
      });

      it('does not display the fallback string', () => {
        expect(findConfigPathFallback().exists()).toBe(false);
      });
    });

    describe('when there is no config path', () => {
      beforeEach(() => {
        createComponent({ aiFlowTriggers: mockTriggersConfigPath });
      });

      it('displays the fallback string', () => {
        expect(findConfigPathFallback().exists()).toBe(true);
      });

      it('does not display the config path', () => {
        expect(findConfigPath().exists()).toBe(false);
      });
    });

    describe('when there is user information', () => {
      it('displays the user avatar', () => {
        expect(findAvatar().exists()).toBe(true);
      });
    });

    describe('when there is no user information', () => {
      beforeEach(() => {
        createComponent({ aiFlowTriggers: mockTriggersWithoutUser });
      });

      it('does not display the user avatar', () => {
        expect(findAvatar().exists()).toBe(false);
      });
    });
  });

  describe('Interactions', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('when user clicks on delete button', () => {
      beforeEach(() => {
        findDeleteButton().vm.$emit('click');
      });

      it('emits the event', () => {
        expect(wrapper.emitted('delete-trigger')).toHaveLength(1);
      });
    });
  });
});
