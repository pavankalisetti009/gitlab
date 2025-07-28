import { shallowMount } from '@vue/test-utils';
import ApplySecurityAttributes from 'ee/security_configuration/security_attributes/components/apply_security_attributes.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('ApplySecurityAttributes', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(ApplySecurityAttributes);
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  beforeEach(() => {
    createComponent();
  });

  it('tracks a page view', () => {
    const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

    expect(trackEventSpy).toHaveBeenCalledWith('view_project_security_attributes', {}, undefined);
  });

  it('renders page heading, tab, and description', () => {
    expect(wrapper.text()).toContain(
      'Security attributes help classify and organize your projects',
    );
  });
});
