import { GlTableLite } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsTable from 'ee/pages/admin/ai/feature_settings/components/feature_settings_table.vue';
import { mockAiFeatureSettings, mockSelfHostedModels } from './mock_data';

describe('FeatureSettingsTable', () => {
  let wrapper;

  const newSelfHostedModelPath = '/admin/ai/self_hosted_models/new';

  const createComponent = ({ props }) => {
    wrapper = mountExtended(FeatureSettingsTable, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent({
      props: {
        featureSettings: mockAiFeatureSettings,
        models: mockSelfHostedModels,
        newSelfHostedModelPath,
      },
    });
  });

  const findTable = () => wrapper.findComponent(GlTableLite);
  const findTableHeaders = () => findTable().findAllComponents('th');
  const findTableRows = () => findTable().findAllComponents('tbody > tr');

  it('renders the table component', () => {
    expect(findTable().exists()).toBe(true);
  });

  it('renders table headers <th>', () => {
    const expectedTableHeaderNames = ['Main feature', 'Sub feature', 'Model name'];

    expect(findTableHeaders().wrappers.map((h) => h.text())).toEqual(expectedTableHeaderNames);
  });

  describe('AI feature settings', () => {
    describe('Code Suggestions', () => {
      it('renders Code Suggestions sub-features', () => {
        const rows = findTableRows().wrappers.map((h) => h.text());

        expect(rows.filter((r) => r.includes('Code generation')).length).toEqual(1);
        expect(rows.filter((r) => r.includes('Code completion')).length).toEqual(1);
      });
    });

    describe('Duo Chat', () => {
      it('renders Duo Chat sub-features', () => {
        const rows = findTableRows().wrappers.map((h) => h.text());

        expect(rows.filter((r) => r.includes('Explain code')).length).toEqual(1);
        expect(rows.filter((r) => r.includes('Epic reader')).length).toEqual(1);
      });
    });
  });
});
