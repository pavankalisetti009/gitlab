import {
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT,
  PIPELINE_EXECUTION_POLICY_INVALID_STRATEGY,
  PIPELINE_EXECUTION_POLICY_INVALID_CONTENT,
  INJECT_CI_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  createPolicyObject,
  getInitialPolicy,
  validatePolicy,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import {
  customYaml,
  customYamlObject,
  customYamlObjectFromUrlParams,
  customYamlUrlParams,
  invalidStrategyManifest,
  invalidYaml,
  mockPipelineExecutionObject,
  mockWithInjectCiPipelineExecutionObject,
  mockWithSuffixPipelineExecutionObject,
  mockScheduledPipelineExecutionObject,
  mockScheduledPipelineExecutionManifest,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';

describe('fromYaml', () => {
  it.each`
    title                                                                     | input                                                                                                                              | output
    ${'returns the policy object for a supported manifest'}                   | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }}             | ${mockPipelineExecutionObject}
    ${'returns the policy object for a supported manifest with inject_ci'}    | ${{ manifest: INJECT_CI_PIPELINE_EXECUTION_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }}           | ${mockWithInjectCiPipelineExecutionObject}
    ${'returns the policy object for a supported manifest with schedules'}    | ${{ manifest: mockScheduledPipelineExecutionManifest, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }}        | ${mockScheduledPipelineExecutionObject}
    ${'returns the policy object for a supported manifest with suffix'}       | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }} | ${mockWithSuffixPipelineExecutionObject}
    ${'returns the policy object for a policy with an unsupported attribute'} | ${{ manifest: customYaml, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }}                                    | ${{ type: 'pipeline_execution_policy', ...customYamlObject }}
    ${'returns empty object for a policy with an invalid yaml'}               | ${{ manifest: invalidYaml, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }}                                   | ${{}}
  `('$title', ({ input, output }) => {
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('validatePolicy', () => {
  it.each`
    title                                                                | input                                                                                                                                     | output
    ${'returns empty object when there are no errors'}                   | ${fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter })}          | ${{}}
    ${'returns empty object when there are no errors for scheduled PEP'} | ${fromYaml({ manifest: mockScheduledPipelineExecutionManifest, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter })}     | ${{}}
    ${'returns error objects when there are invalid pipeline strategy'}  | ${fromYaml({ manifest: PIPELINE_EXECUTION_POLICY_INVALID_STRATEGY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter })} | ${{ actions: true }}
    ${'returns error objects when there is invalid content'}             | ${fromYaml({ manifest: PIPELINE_EXECUTION_POLICY_INVALID_CONTENT, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter })}  | ${{ actions: true }}
  `('$title', ({ input, output }) => {
    expect(validatePolicy(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  const errorPolicy = {
    content: { include: [{ file: '.pipeline-execution.yml', project: 'GitLab.org/GitLab' }] },
    description: 'triggers all protected branches except main',
    enabled: true,
    name: 'Ci config file',
    pipeline_config_strategy: 'this_is_wrong',
    type: 'pipeline_execution_policy',
  };

  it.each`
    title                                                                                    | input                                           | output
    ${'returns the policy object and no errors for a supported manifest'}                    | ${DEFAULT_PIPELINE_EXECUTION_POLICY}            | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }), parsingError: {} }}
    ${'returns the policy object and no errors for a supported manifest new format'}         | ${DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT} | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }), parsingError: {} }}
    ${'returns the policy object and no errors for a supported manifest with inject_ci'}     | ${INJECT_CI_PIPELINE_EXECUTION_POLICY}          | ${{ policy: fromYaml({ manifest: INJECT_CI_PIPELINE_EXECUTION_POLICY, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }), parsingError: {} }}
    ${'returns the policy object and no errors for a supported manifest with scheduled PEP'} | ${mockScheduledPipelineExecutionManifest}       | ${{ policy: fromYaml({ manifest: mockScheduledPipelineExecutionManifest, type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter }), parsingError: {} }}
    ${'returns the error policy object and the error for an invalid strategy name'}          | ${invalidStrategyManifest}                      | ${{ policy: errorPolicy, parsingError: { actions: true } }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('policyToYaml', () => {
  it('returns policy object as yaml', () => {
    expect(
      policyToYaml(customYamlObject, POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter),
    ).toBe(
      `pipeline_execution_policy:
  - ${customYaml}`,
    );
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
