import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlForm, GlFormInput, GlFormTextarea, GlCollapsibleListbox } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UserSelect from '~/vue_shared/components/user_select/user_select.vue';
import FlowTriggerForm from 'ee/ai/duo_agents_platform/pages/flow_triggers/components/flow_trigger_form.vue';
import { mockTrigger, eventTypeOptions } from '../mocks';

Vue.use(VueApollo);

describe('FlowTriggerForm', () => {
  let wrapper;

  const findErrorAlert = () => wrapper.findComponent(GlAlert);
  const findForm = () => wrapper.findComponent(GlForm);
  const findDescription = () => wrapper.findComponent(GlFormTextarea);
  const findConfigPath = () => wrapper.findComponent(GlFormInput);
  const findEventTypes = () => wrapper.findComponent(GlCollapsibleListbox);
  const findUserSelect = () => wrapper.findComponent(UserSelect);

  const defaultProps = {
    mode: 'create',
    isLoading: false,
    errorMessages: [],
    eventTypeOptions: [],
    projectPath: 'myProject',
  };

  const createWrapper = () => {
    wrapper = shallowMountExtended(FlowTriggerForm, {
      apolloProvider: createMockApollo(),
      propsData: defaultProps,
      stubs: {
        UserSelect,
      },
    });
  };

  describe('Rendering', () => {
    it('does not render error alert', () => {
      createWrapper();

      expect(findErrorAlert().exists()).toBe(false);
    });
  });

  describe('with error messages', () => {
    const mockErrorMessage = 'The flow could not be created';

    beforeEach(async () => {
      window.scrollTo = jest.fn();
      createWrapper();
      await wrapper.setProps({
        errorMessages: [mockErrorMessage],
      });
    });

    it('renders error alert', () => {
      expect(findErrorAlert().find('li').text()).toBe(mockErrorMessage);
    });

    it('scrolls to the top', () => {
      expect(window.scrollTo).toHaveBeenCalledWith({
        top: 0,
        left: 0,
        behavior: 'smooth',
      });
    });

    it('customSearchUsersProcessor handles project service account response mapping', () => {
      const user1 = { id: 1, name: 'a' };
      const user2 = { id: 2, name: 'b' };
      const data = { project: { projectMembers: { nodes: [{ user: user1 }, { user: user2 }] } } };

      expect(findUserSelect().props('customSearchUsersProcessor')(data)).toContain(user1, user2);
    });

    it('renders error alert with list for multiple errors', async () => {
      await wrapper.setProps({
        errorMessages: ['error1', 'error2'],
      });

      expect(findErrorAlert().findAll('li')).toHaveLength(2);
    });

    it('emits dismiss-errors event', () => {
      findErrorAlert().vm.$emit('dismiss');

      expect(wrapper.emitted('dismiss-errors')).toHaveLength(1);
    });
  });

  describe('Form Submit', () => {
    beforeEach(() => {
      createWrapper();
    });

    describe('when using the submit button', () => {
      it('submits the form', async () => {
        const description = 'My description';
        const configPath = 'my/config/path';
        const eventTypes = [eventTypeOptions[0].value];
        await findDescription().vm.$emit('input', description);
        await findConfigPath().vm.$emit('input', configPath);
        await findEventTypes().vm.$emit('select', eventTypes);
        await findUserSelect().vm.$emit('input', [mockTrigger.user]);

        findForm().vm.$emit('submit', { preventDefault: () => {} });

        expect(wrapper.emitted('submit')).toEqual([
          [{ configPath, description, eventTypes, userId: 'gid://gitlab/User/1' }],
        ]);
      });
    });
  });
});
