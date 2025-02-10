import { fromYaml } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';

export const mockPipelineExecutionActionManifest = `pipeline_execution_policy:
- name: ''
  description: ''
  enabled: true
  pipeline_config_strategy: inject_policy
  content:
    include:
      - project: ''
`;

export const mockPipelineExecutionObject = fromYaml({
  manifest: mockPipelineExecutionActionManifest,
});
