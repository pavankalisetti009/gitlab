import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoExtensions from 'ee/pages/projects/get_started/components/duo_extensions.vue';

describe('DuoExtensions component', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(DuoExtensions);
  });

  it('renders correctly', () => {
    expect(wrapper.element).toMatchSnapshot();
  });

  it('shows extension types', () => {
    expect(wrapper.text()).toContain('VS Code');
    expect(wrapper.text()).toContain('Eclipse');
    expect(wrapper.text()).toContain('GitLab CLI');
  });

  it('extensions link to doc url', () => {
    expect(wrapper.findComponent(GlButton).text()).toContain('VS Code');
    expect(wrapper.findComponent(GlButton).attributes('href')).toBe(
      '/help/editor_extensions/visual_studio_code/_index.md',
    );
  });
});
