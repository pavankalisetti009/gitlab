import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FeatureSettingsBlock from 'ee/ai/shared/feature_settings/feature_settings_block.vue';
import FeatureSettings from 'ee/ai/model_selection/feature_settings.vue';

import {
  mockCodeSuggestionsFeatureSettings,
  mockDuoChatFeatureSettings,
  mockMergeRequestFeatureSettings,
  mockIssueFeatureSettings,
  mockOtherDuoFeaturesSettings,
  mockAiFeatureSettings,
  mockDuoAgentPlatformSettings,
} from './mock_data';

describe('FeatureSettings', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(FeatureSettings, {
      propsData: {
        featureSettings: mockAiFeatureSettings,
        isLoading: false,
        ...props,
      },
    });
  };

  const findFeatureSettings = () => wrapper.findComponent(FeatureSettings);
  const findAllSettingsBlock = () => wrapper.findAllComponents(FeatureSettingsBlock);
  const findAllSettingsDescriptions = () => wrapper.findAllComponents(GlSprintf);
  const findDuoChatTable = () => wrapper.findByTestId('duo-chat-table');
  const findCodeSuggestionsTable = () => wrapper.findByTestId('code-suggestions-table');
  const findOtherDuoFeaturesTable = () => wrapper.findByTestId('other-duo-features-table');
  const findDuoIssuesTable = () => wrapper.findByTestId('duo-issues-table');
  const findDuoMergeRequestTable = () => wrapper.findByTestId('duo-merge-requests-table');
  const findDuoAgentPlatformTable = () => wrapper.findByTestId('duo-agent-platform-table');

  it('renders the component', () => {
    createComponent();

    expect(findFeatureSettings().exists()).toBe(true);
  });

  describe('when feature settings data is loading', () => {
    it('passes the correct loading state to `FeatureSettingsTableRows`', () => {
      createComponent({ props: { isLoading: true } });

      expect(findCodeSuggestionsTable().props('isLoading')).toBe(true);
      expect(findDuoChatTable().props('isLoading')).toBe(true);
      expect(findDuoMergeRequestTable().props('isLoading')).toBe(true);
      expect(findDuoIssuesTable().props('isLoading')).toBe(true);
      expect(findDuoAgentPlatformTable().props('isLoading')).toBe(true);
      expect(findOtherDuoFeaturesTable().props('isLoading')).toBe(true);
    });
  });

  describe.each`
    section                         | index | expectedTitle                      | expectedDescription                                                                                                        | findSectionTableFn           | expectedFeatureSettings
    ${'Code Suggestions'}           | ${0}  | ${'Code Suggestions'}              | ${'Assists developers by generating and completing code in real-time.'}                                                    | ${findCodeSuggestionsTable}  | ${mockCodeSuggestionsFeatureSettings}
    ${'Duo Chat'}                   | ${1}  | ${'GitLab Duo Chat'}               | ${'An AI assistant that helps users accelerate software development using real-time conversational AI.'}                   | ${findDuoChatTable}          | ${mockDuoChatFeatureSettings}
    ${'Duo merge request features'} | ${2}  | ${'GitLab Duo for merge requests'} | ${'AI-native features that help users accomplish tasks during the lifecycle of a merge request.'}                          | ${findDuoMergeRequestTable}  | ${mockMergeRequestFeatureSettings}
    ${'Duo issues'}                 | ${3}  | ${'GitLab Duo for issues'}         | ${'An AI-native feature that generates a summary of discussions on an issue.'}                                             | ${findDuoIssuesTable}        | ${mockIssueFeatureSettings}
    ${'GitLab Duo Agent Platform'}  | ${4}  | ${'GitLab Duo Agent Platform'}     | ${'Multiple AI agents that work in parallel to help you create code, research results, and perform tasks simultaneously.'} | ${findDuoAgentPlatformTable} | ${mockDuoAgentPlatformSettings}
    ${'Other Duo features'}         | ${5}  | ${'Other GitLab Duo features'}     | ${'AI-native features that support users outside of Chat or Code Suggestions.'}                                            | ${findOtherDuoFeaturesTable} | ${mockOtherDuoFeaturesSettings}
  `(
    '$section',
    ({
      index,
      expectedTitle,
      expectedDescription,
      findSectionTableFn,
      expectedFeatureSettings,
    }) => {
      beforeEach(() => {
        createComponent();
      });

      it('renders section and table', () => {
        expect(findAllSettingsBlock().at(index).props('title')).toBe(expectedTitle);
        expect(findAllSettingsDescriptions().at(index).attributes('message')).toContain(
          expectedDescription,
        );
        expect(findSectionTableFn().exists()).toBe(true);
      });

      it('passes correct featureSettings to section table', () => {
        expect(findSectionTableFn().props('featureSettings')).toEqual(expectedFeatureSettings);
      });
    },
  );
});
