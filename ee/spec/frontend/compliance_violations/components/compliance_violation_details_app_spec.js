import { shallowMount } from '@vue/test-utils';
import ComplianceViolationDetailsApp from 'ee/compliance_violations/components/compliance_violation_details_app.vue';

describe('ComplianceViolationDetailsApp', () => {
  let wrapper;

  const props = { projectPath: '/path/to/project', violationId: '123' };

  const createComponent = () => {
    wrapper = shallowMount(ComplianceViolationDetailsApp, { propsData: { ...props } });
  };

  it('renders the violation details app', () => {
    createComponent(props);

    expect(wrapper.findComponent(ComplianceViolationDetailsApp).exists()).toBe(true);
  });
});
