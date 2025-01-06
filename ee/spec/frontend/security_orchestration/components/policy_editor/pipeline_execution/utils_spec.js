import {
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE,
  DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX,
  DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  createPolicyObject,
  fromYaml,
  getInitialPolicy,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import {
  customYaml,
  customYamlObject,
  customYamlObjectFromUrlParams,
  customYamlUrlParams,
  invalidStrategyManifest,
  mockPipelineExecutionObject,
  mockWithScopePipelineExecutionObject,
  mockWithSuffixPipelineExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';

describe('fromYaml', () => {
  it.each`
    title                                                                                        | input                                                                                  | output
    ${'returns the policy object for a supported manifest'}                                      | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }}                                     | ${{ policy: mockPipelineExecutionObject, parsingError: {} }}
    ${'returns the policy object for a supported manifest with scope with validation'}           | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE, validateRuleMode: true }}  | ${{ policy: mockWithScopePipelineExecutionObject, parsingError: {} }}
    ${'returns the policy object for a supported manifest with suffix with validation'}          | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX, validateRuleMode: true }} | ${{ policy: mockWithSuffixPipelineExecutionObject, parsingError: {} }}
    ${'returns the policy object for a policy with an unsupported attribute without validation'} | ${{ manifest: customYaml }}                                                            | ${{ policy: customYamlObject, parsingError: {} }}
    ${'returns the error object for a policy with an unsupported attribute with validation'}     | ${{ manifest: customYaml, validateRuleMode: true }}                                    | ${{ policy: {}, parsingError: { actions: true } }}
  `('$title', ({ input, output }) => {
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  const errorPolicy = {
    content: { include: [{ file: '.pipeline-execution.yml', project: 'GitLab.org/GitLab' }] },
    description: 'triggers all protected branches except main',
    enabled: true,
    name: 'Ci config file',
    pipeline_config_strategy: 'this_is_wrong',
  };

  it.each`
    title                                                                            | input                                           | output                                                                                            | securityPoliciesNewYamlFormat
    ${'returns the policy object and no errors for a supported manifest'}            | ${DEFAULT_PIPELINE_EXECUTION_POLICY}            | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }).policy, parsingError: {} }} | ${false}
    ${'returns the policy object and no errors for a supported manifest new format'} | ${DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT} | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }).policy, parsingError: {} }} | ${true}
    ${'returns the error policy object and the error for an unsupported manifest'}   | ${customYaml}                                   | ${{ policy: {}, parsingError: { actions: true } }}                                                | ${false}
    ${'returns the error policy object and the error for an invalid strategy name'}  | ${invalidStrategyManifest}                      | ${{ policy: errorPolicy, parsingError: { actions: true } }}                                       | ${false}
  `('$title', ({ input, output, securityPoliciesNewYamlFormat }) => {
    window.gon.features = { securityPoliciesNewYamlFormat };
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('policyToYaml', () => {
  it('returns policy object as yaml', () => {
    expect(
      policyToYaml(customYamlObject, POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter),
    ).toBe(customYaml);
  });
});

describe('toYaml', () => {
  it('returns policy object as yaml', () => {
    expect(policyBodyToYaml(customYamlObject)).toBe(customYaml);
  });
});

describe('getInitialPolicy', () => {
  it('updates initialPolicy with passed params if all params are present', () => {
    const expectedYaml = customYamlObjectFromUrlParams(customYamlUrlParams);
    expect(getInitialPolicy(customYaml, customYamlUrlParams)).toBe(expectedYaml);
  });

  it.each(Object.keys(customYamlUrlParams).map((key) => [key]))(
    'ignores other url params if %s is missing',
    (key) => {
      const params = { ...customYamlUrlParams };
      delete params[key];
      expect(getInitialPolicy(customYaml, params)).toBe(customYaml);
    },
  );
});
