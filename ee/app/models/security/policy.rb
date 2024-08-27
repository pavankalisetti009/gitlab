# frozen_string_literal: true

module Security
  class Policy < ApplicationRecord
    include IgnorableColumns

    self.table_name = 'security_policies'
    self.inheritance_column = :_type_disabled

    ignore_columns %i[actions approval_settings], remove_with: '17.5', remove_after: '2024-10-17'

    POLICY_CONTENT_FIELDS = {
      approval_policy: %i[actions approval_settings fallback_behavior],
      scan_execution_policy: %i[actions],
      pipeline_execution_policy: %i[content pipeline_config_strategy]
    }.freeze

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
    has_many :approval_policy_rules, class_name: 'Security::ApprovalPolicyRule', foreign_key: 'security_policy_id',
      inverse_of: :security_policy
    has_many :scan_execution_policy_rules, class_name: 'Security::ScanExecutionPolicyRule',
      foreign_key: 'security_policy_id', inverse_of: :security_policy
    has_many :security_policy_project_links, class_name: 'Security::PolicyProjectLink',
      foreign_key: :security_policy_id, inverse_of: :security_policy

    has_many :projects, through: :security_policy_project_links

    enum type: {
      approval_policy: 0,
      scan_execution_policy: 1,
      pipeline_execution_policy: 2
    }, _prefix: true

    validates :security_orchestration_policy_configuration_id,
      uniqueness: { scope: %i[type policy_index] }

    validates :scope, json_schema: { filename: "security_policy_scope" }
    validates :scope, exclusion: { in: [nil] }

    validates :content, json_schema: { filename: "approval_policy_content" }, if: :type_approval_policy?
    validates :content, json_schema: { filename: "pipeline_execution_policy_content" },
      if: :type_pipeline_execution_policy?
    validates :content, json_schema: { filename: "scan_execution_policy_content" }, if: :type_scan_execution_policy?

    validates :content, exclusion: { in: [nil] }

    def self.checksum(policy_hash)
      Digest::SHA256.hexdigest(policy_hash.to_json)
    end

    def self.attributes_from_policy_hash(policy_type, policy_hash, policy_configuration)
      {
        type: policy_type,
        name: policy_hash[:name],
        description: policy_hash[:description],
        enabled: policy_hash[:enabled],
        metadata: policy_hash.fetch(:metadata, {}),
        scope: policy_hash.fetch(:policy_scope, {}),
        content: policy_hash.slice(*POLICY_CONTENT_FIELDS[policy_type]),
        checksum: checksum(policy_hash),
        security_policy_management_project_id: policy_configuration.security_policy_management_project_id
      }.compact
    end

    def self.rule_attributes_from_rule_hash(policy_type, rule_hash, policy_configuration)
      Security::PolicyRule.for_policy_type(policy_type).attributes_from_rule_hash(rule_hash, policy_configuration)
    end

    def self.upsert_policy(policy_type, policies, policy_hash, policy_index, policy_configuration)
      transaction do
        policy = policies.find_or_initialize_by(policy_index: policy_index, type: policy_type)
        policy.update!(attributes_from_policy_hash(policy_type, policy_hash, policy_configuration))

        Array.wrap(policy_hash[:rules]).map.with_index do |rule_hash, rule_index|
          Security::PolicyRule.for_policy_type(policy_type)
              .find_or_initialize_by(security_policy_id: policy.id, rule_index: rule_index)
              .update!(rule_attributes_from_rule_hash(policy_type, rule_hash, policy_configuration))
        end
      end
    end

    def self.delete_by_ids(ids)
      id_in(ids).delete_all
    end
  end
end
