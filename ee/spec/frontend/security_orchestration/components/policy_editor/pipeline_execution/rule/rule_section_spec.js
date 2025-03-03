import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RuleSection from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/rule_section.vue';
import ScheduleForm from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/schedule_form.vue';

describe('RuleSection', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, provide = {}, isStubbed = true } = {}) => {
    const stubs = isStubbed ? { GlSprintf } : {};

    wrapper = shallowMountExtended(RuleSection, {
      propsData,
      provide,
      stubs,
    });
  };

  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findGlLink = () => wrapper.findComponent(GlLink);
  const findScheduleForm = () => wrapper.findComponent(ScheduleForm);

  describe('rendering', () => {
    describe('when feature flag is off', () => {
      it('renders inject/override message when schedule is not selected', () => {
        createComponent({ propsData: { strategy: 'inject' } });
        expect(wrapper.findComponent(GlSprintf).exists()).toBe(true);
        expect(findScheduleForm().exists()).toBe(false);
      });
    });

    describe('when feature flag is on', () => {
      it('renders schedule form when schedule is selected', () => {
        createComponent({
          propsData: { strategy: 'schedule' },
          provide: { glFeatures: { scheduledPipelineExecutionPolicies: true } },
        });
        expect(wrapper.findComponent(GlSprintf).exists()).toBe(false);
        expect(findScheduleForm().exists()).toBe(true);
      });

      it('renders inject/override message when schedule is not selected', () => {
        createComponent({
          propsData: { strategy: 'inject' },
          provide: { glFeatures: { scheduledPipelineExecutionPolicies: true } },
        });
        expect(wrapper.findComponent(GlSprintf).exists()).toBe(true);
        expect(findScheduleForm().exists()).toBe(false);
      });
    });
  });

  describe('inject/override message', () => {
    it('renders text', () => {
      createComponent({ isStubbed: false });
      expect(findGlSprintf().attributes('message')).toBe(
        'Configure your conditions in the pipeline execution file. %{linkStart}What can pipeline execution do?%{linkEnd}',
      );
    });

    it('renders link', () => {
      createComponent();
      expect(findGlLink().exists()).toBe(true);
      expect(findGlLink().text()).toBe('What can pipeline execution do?');
      expect(findGlLink().attributes('href')).toBe(
        '/help/user/application_security/policies/pipeline_execution_policies',
      );
    });
  });
});
