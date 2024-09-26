import { GlTableLite, GlDisclosureDropdown } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import SelfHostedModelsTable from 'ee/pages/admin/ai/self_hosted_models/components/self_hosted_models_table.vue';
import DeleteSelfHostedModelDisclosureItem from 'ee/pages/admin/ai/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { mockSelfHostedModelsList } from './mock_data';

describe('SelfHostedModelsTable', () => {
  let wrapper;

  const createComponent = ({ props }) => {
    const basePath = '/admin/ai/self_hosted_models';

    wrapper = extendedWrapper(
      mount(SelfHostedModelsTable, {
        propsData: {
          basePath,
          ...props,
        },
      }),
    );
  };

  beforeEach(() => {
    createComponent({ props: { models: mockSelfHostedModelsList } });
  });

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');
  const findNthTableRow = (idx) => findTableRows().at(idx);
  const findDisclosureDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findEditButtons = () => wrapper.findAllByTestId('model-edit-button');
  const findDeleteDisclosureItems = () =>
    wrapper.findAllComponents(DeleteSelfHostedModelDisclosureItem);

  it('renders the table component', () => {
    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    const expectedTableHeaderNames = [
      'Name',
      'Model',
      'Endpoint',
      'API token',
      '', // The 'edit' column does not have a header name
    ];

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  it('renders self-hosted model entries', () => {
    expect(findTableRows().length).toEqual(2);

    const firstModel = findNthTableRow(0);

    expect(firstModel.text()).toContain('mock-self-hosted-model-1');
    expect(firstModel.text()).toContain('mixtral');
    expect(firstModel.text()).toContain('https://mock-endpoint-1.com');
    expect(firstModel.find('[data-testid="check-circle-icon"]').exists()).toBe(true);
  });

  it('renders a disclosure dropdown for each self-hosted model entry', () => {
    expect(findDisclosureDropdowns().length).toBe(2);
  });

  describe('Editing a model', () => {
    it('renders an edit button for each model', () => {
      expect(findEditButtons().length).toBe(2);

      findEditButtons().wrappers.forEach((button) => {
        expect(button.text()).toEqual('Edit');
      });
    });

    it('routes to the correct path', () => {
      findEditButtons().wrappers.forEach((button, idx) => {
        expect(button.html()).toContain(`href="/admin/ai/self_hosted_models/${idx + 1}/edit"`);
      });
    });
  });

  describe('Deleting a model', () => {
    it('renders a delete button for each model', () => {
      expect(findDeleteDisclosureItems().length).toBe(2);

      findDeleteDisclosureItems().wrappers.forEach((button) => {
        expect(button.text()).toEqual('Delete');
      });
    });
  });
});
