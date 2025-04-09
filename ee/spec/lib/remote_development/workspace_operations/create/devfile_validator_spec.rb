# frozen_string_literal: true

require 'fast_spec_helper'

RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::DevfileValidator, feature_category: :workspaces do
  include ResultMatchers

  include_context 'with remote development shared fixtures'

  let(:devfile_name) { 'example.flattened-with-entries-devfile.yaml.erb' }
  let(:main_component_indicator_attribute) do
    ::RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::MAIN_COMPONENT_INDICATOR_ATTRIBUTE
  end

  let(:devfile) { yaml_safe_load_symbolized(read_devfile_yaml(devfile_name)) }
  let(:processed_devfile) { yaml_safe_load_symbolized(read_devfile_yaml(devfile_name)) }
  let(:context) { { devfile: processed_devfile, processed_devfile: processed_devfile } }

  subject(:result) do
    described_class.validate(context)
  end

  context 'for devfiles containing no violations' do
    it 'returns an ok Result containing the original context' do
      expect(result).to eq(Gitlab::Fp::Result.ok({ devfile: devfile, processed_devfile: processed_devfile }))
    end

    context 'when devfile has multiple array entries' do
      let(:devfile_name) { 'example.multi-entry-devfile.yaml.erb' }

      it 'returns an ok Result containing the original context' do
        expect(result).to eq(Gitlab::Fp::Result.ok({ devfile: devfile, processed_devfile: processed_devfile }))
      end
    end
  end

  context 'for devfiles containing violations' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- we want single lines for RSpec::Parameterized::TableSyntax
    where(:devfile_name, :error_str) do
      'example.invalid-unsupported-parent-inheritance-devfile.yaml.erb' | "Inheriting from 'parent' is not yet supported"
      'example.invalid-unsupported-schema-version-devfile.yaml.erb' | "'schemaVersion' '2.0.0' is not supported, it must be '2.2.0'"
      'example.invalid-invalid-schema-version-devfile.yaml.erb' | "Invalid 'schemaVersion' 'example'"
      'example.invalid-restricted-prefix-command-apply-component-name-devfile.yaml.erb' | "Component name 'gl-example' for command id 'example' must not start with 'gl-'"
      'example.invalid-restricted-prefix-command-exec-component-name-devfile.yaml.erb' | "Component name 'gl-example' for command id 'example' must not start with 'gl-'"
      'example.invalid-restricted-prefix-command-name-devfile.yaml.erb' | "Command id 'gl-example' must not start with 'gl-'"
      'example.invalid-restricted-prefix-component-container-endpoint-name-devfile.yaml.erb' | "Endpoint name 'gl-example' of component 'example' must not start with 'gl-'"
      'example.invalid-restricted-prefix-component-name-devfile.yaml.erb' | "Component name 'gl-example' must not start with 'gl-'"
      'example.invalid-restricted-prefix-event-type-prestart-name-devfile.yaml.erb' | "Event 'gl-example' of type 'preStart' must not start with 'gl-'"
      'example.invalid-restricted-prefix-variable-name-devfile.yaml.erb' | "Variable name 'gl-example' must not start with 'gl-'"
      'example.invalid-restricted-prefix-variable-name-with-underscore-devfile.yaml.erb' | "Variable name 'gl_example' must not start with 'gl_'"
      'example.invalid-unsupported-component-type-image-devfile.yaml.erb' | "Component type 'image' is not yet supported"
      'example.invalid-unsupported-component-type-kubernetes-devfile.yaml.erb' | "Component type 'kubernetes' is not yet supported"
      'example.invalid-unsupported-component-type-openshift-devfile.yaml.erb' | "Component type 'openshift' is not yet supported"
      'example.invalid-components-entry-empty-devfile.yaml.erb' | "No components present in devfile"
      'example.invalid-components-entry-missing-devfile.yaml.erb' | "No components present in devfile"
      'example.invalid-component-missing-name.yaml.erb' | "Components must have a 'name'"
      'example.invalid-attributes-tools-injector-absent-devfile.yaml.erb' | "No component has '#{main_component_indicator_attribute}' attribute"
      'example.invalid-attributes-tools-injector-multiple-devfile.yaml.erb' | "Multiple components '[\"tooling-container\", \"tooling-container-2\"]' have '#{main_component_indicator_attribute}' attribute"
      'example.invalid-unsupported-component-container-dedicated-pod-devfile.yaml.erb' | "Property 'dedicatedPod' of component 'example' is not yet supported"
      'example.invalid-unsupported-starter-projects-devfile.yaml.erb' | "'starterProjects' is not yet supported"
      'example.invalid-unsupported-projects-devfile.yaml.erb' | "'projects' is not yet supported"
      'example.invalid-unsupported-event-type-poststart-devfile.yaml.erb' | "Event type 'postStart' is not yet supported"
      'example.invalid-unsupported-event-type-prestop-devfile.yaml.erb' | "Event type 'preStop' is not yet supported"
      'example.invalid-unsupported-event-type-poststop-devfile.yaml.erb' | "Event type 'postStop' is not yet supported"
      'example.invalid-root-attributes-pod-overrides-devfile.yaml.erb' | "Attribute 'pod-overrides' is not yet supported"
      'example.invalid-components-attributes-pod-overrides-devfile.yaml.erb' | "Attribute 'pod-overrides' is not yet supported"
      'example.invalid-components-attributes-container-overrides-devfile.yaml.erb' | "Attribute 'container-overrides' is not yet supported"
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it 'returns an err Result containing error details' do
        is_expected.to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateDevfileValidationFailed)
          message.content => { details: String => error_details }
          expect(error_details).to eq(error_str)
        end
      end
    end
  end

  context 'for multi-array-entry devfiles containing violations' do
    # NOTE: This context guards against the incorrect usage of
    #       `return Gitlab::Fp::Result.ok(context) unless condition`
    #       guard clauses within iterator blocks in the validator logic.
    #       Because the behavior of `return` in Ruby is to return from the entire containing method,
    #       regardless of how many blocks you are nexted within, this would result in early returns
    #       which do not process all entries which are being iterated over.

    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- we want single lines for RSpec::Parameterized::TableSyntax
    where(:devfile_name, :error_str) do
      'example.invalid-multi-component-devfile.yaml.erb' | "Component name 'gl-example-invalid-second-component' must not start with 'gl-'"
      'example.invalid-multi-endpoint-devfile.yaml.erb' | "Endpoint name 'gl-example-invalid-second-endpoint' of component 'example-invalid-second-component' must not start with 'gl-'"
      'example.invalid-multi-command-devfile.yaml.erb' | "Component name 'gl-example-invalid-component' for command id 'example-invalid-second-component-command' must not start with 'gl-'"
      'example.invalid-multi-event-devfile.yaml.erb' | "Event 'gl-example' of type 'preStart' must not start with 'gl-'"
      'example.invalid-multi-variable-devfile.yaml.erb' | "Variable name 'gl-example-invalid' must not start with 'gl-'"
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it 'returns an err Result containing error details' do
        is_expected.to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreateDevfileValidationFailed)
          message.content => { details: String => error_details }
          expect(error_details).to eq(error_str)
        end
      end
    end
  end
end
