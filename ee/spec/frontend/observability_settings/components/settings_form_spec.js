import { GlSprintf, GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SettingsBlock from '~/vue_shared/components/settings/settings_block.vue';
import SettingsForm from 'ee/observability_settings/components/settings_form.vue';
import { DOCS_URL_IN_EE_DIR } from '~/lib/utils/url_utility';

describe('SettingsForm', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(SettingsForm, {
      stubs: { GlSprintf, SettingsBlock },
    });
  });

  const findContent = () => wrapper.findByTestId('settings-block-content');
  const findToggleButton = () => wrapper.findByTestId('settings-block-toggle');

  it('renders a title', () => {
    expect(wrapper.findComponent({ ref: 'sectionHeader' }).text()).toBe('Tracing, Metrics & Logs');
  });

  it('renders a subtitle', () => {
    expect(wrapper.findComponent({ ref: 'sectionSubHeader' }).text()).toBe(
      'Enable tracing, metrics, or logs on your project.',
    );
  });

  it('renders an expand button', () => {
    expect(findToggleButton().text()).toContain('Expand');
  });

  it('renders an intro text with link', () => {
    expect(findContent().text()).toBe(
      'View our documentation for further instructions on how to use these features.',
    );
    expect(findContent().findComponent(GlLink).attributes('href')).toBe(
      `${DOCS_URL_IN_EE_DIR}/operations`,
    );
  });
});
