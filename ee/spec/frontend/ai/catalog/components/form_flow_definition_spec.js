import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FormFlowDefinition from 'ee/ai/catalog/components/form_flow_definition.vue';
import ClipboardButton from '~/vue_shared/components/clipboard_button.vue';
import SourceEditor from '~/vue_shared/components/source_editor.vue';

describe('FormFlowDefinition', () => {
  let wrapper;

  const defaultProps = {
    value: 'some YAML content',
    readOnly: false,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FormFlowDefinition, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findHeader = () => wrapper.findByTestId('flow-definition-header');
  const findClipboardButton = () => wrapper.findComponent(ClipboardButton);
  const findSourceEditor = () => wrapper.findComponent(SourceEditor);

  beforeEach(() => {
    createComponent();
  });

  it('renders header with clipboard button', () => {
    expect(findHeader().text()).toBe('config.yaml');
    expect(findClipboardButton().props('text')).toBe(defaultProps.value);
  });

  it('renders source editor with correct props', () => {
    expect(findSourceEditor().props('value')).toBe(defaultProps.value);
    expect(findSourceEditor().props('fileName')).toBe('*.yaml');
    expect(findSourceEditor().props('editorOptions')).toEqual({
      padding: { top: 4 },
      readOnly: defaultProps.readOnly,
    });
  });

  it('emits input event when value is changed', async () => {
    await findSourceEditor().vm.$emit('input', 'updated YAML content');

    expect(wrapper.emitted('input')).toEqual([['updated YAML content']]);
  });
});
