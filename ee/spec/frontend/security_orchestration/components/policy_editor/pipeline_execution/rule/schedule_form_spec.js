import { shallowMount } from '@vue/test-utils';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';

describe('ScheduleForm', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ScheduleForm);
  };

  it('renders the component', () => {
    createComponent();
    expect(wrapper.exists()).toBe(true);
  });

  it('displays the correct message', () => {
    createComponent();
    expect(wrapper.text()).toBe('Schedules');
  });
});
