# frozen_string_literal: true

module Security
  class Policy < ApplicationRecord
    include IgnorableColumns
    include EachBatch

    self.table_name = 'security_policies'
    self.inheritance_column = :_type_disabled

    ignore_columns %i[actions approval_settings], remove_with: '17.5', remove_after: '2024-10-17'

    POLICY_CONTENT_FIELDS = {
      approval_policy: %i[actions approval_settings fallback_behavior],
      scan_execution_policy: %i[actions],
      pipeline_execution_policy: %i[content pipeline_config_strategy suffix],
      vulnerability_management_policy: %i[actions]
    }.freeze

    belongs_to :security_orchestration_policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
    has_many :approval_policy_rules, class_name: 'Security::ApprovalPolicyRule', foreign_key: 'security_policy_id',
      inverse_of: :security_policy
    has_many :scan_execution_policy_rules, class_name: 'Security::ScanExecutionPolicyRule',
      foreign_key: 'security_policy_id', inverse_of: :security_policy
    has_many :vulnerability_management_policy_rules, class_name: 'Security::VulnerabilityManagementPolicyRule',
      foreign_key: 'security_policy_id', inverse_of: :security_policy
    has_many :security_policy_project_links, class_name: 'Security::PolicyProjectLink',
      foreign_key: :security_policy_id, inverse_of: :security_policy

    has_many :projects, through: :security_policy_project_links

    enum type: {
      approval_policy: 0,
      scan_execution_policy: 1,
      pipeline_execution_policy: 2,
      vulnerability_management_policy: 3
    }, _prefix: true

    validates :security_orchestration_policy_configuration_id,
      uniqueness: { scope: %i[type policy_index] }

    validates :scope, json_schema: { filename: "security_policy_scope" }
    validates :scope, exclusion: { in: [nil] }

    validates :content, json_schema: { filename: "approval_policy_content" }, if: :type_approval_policy?
    validates :content, json_schema: { filename: "pipeline_execution_policy_content" },
      if: :type_pipeline_execution_policy?
    validates :content, json_schema: { filename: "scan_execution_policy_content" }, if: :type_scan_execution_policy?
    validates :content, json_schema: { filename: "vulnerability_management_policy_content" },
      if: :type_vulnerability_management_policy?

    validates :content, exclusion: { in: [nil] }

    scope :undeleted, -> { where('policy_index >= 0') }
    scope :order_by_index, -> { order(policy_index: :asc) }

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
      policy = policies.find_or_initialize_by(policy_index: policy_index, type: policy_type)
      policy.update!(attributes_from_policy_hash(policy_type, policy_hash, policy_configuration))

      Array.wrap(policy_hash[:rules]).map.with_index do |rule_hash, rule_index|
        policy.upsert_rule(rule_index, rule_hash)
      end

      policy
    end

    def self.delete_by_ids(ids)
      id_in(ids).delete_all
    end

    def upsert_rule(rule_index, rule_hash)
      Security::PolicyRule
        .for_policy_type(type.to_sym)
        .find_or_initialize_by(security_policy_id: id, rule_index: rule_index)
        .update!(
          self.class.rule_attributes_from_rule_hash(type.to_sym, rule_hash, security_orchestration_policy_configuration)
        )
    end

    def to_policy_hash
      {
        name: name,
        description: description,
        enabled: enabled,
        policy_scope: scope,
        metadata: metadata
      }.merge(content_by_type)
    end

    def content_by_type
      content_hash = content.deep_symbolize_keys.slice(*POLICY_CONTENT_FIELDS[type.to_sym])

      case type
      when 'approval_policy', 'scan_execution_policy', 'vulnerability_management_policy'
        content_hash.merge(rules: rules.map(&:typed_content).map(&:deep_symbolize_keys))
      when 'pipeline_execution_policy'
        content_hash
      end
    end

    def rules
      if type_approval_policy?
        approval_policy_rules.undeleted
      elsif type_scan_execution_policy?
        scan_execution_policy_rules.undeleted
      elsif type_vulnerability_management_policy?
        vulnerability_management_policy_rules.undeleted
      else
        []
      end
    end

    def scope_applicable?(project)
      policy_scope_checker = Security::SecurityOrchestrationPolicies::PolicyScopeChecker.new(project: project)

      policy_scope_checker.security_policy_applicable?(self)
    end

    def delete_approval_policy_rules
      relation_in_batch(approval_policy_rules) do |batch|
        delete_approval_rules(batch)
        delete_policy_violations(batch)
        delete_software_license_policies(batch)
      end

      delete_in_batches(approval_policy_rules)
    end

    def delete_scan_execution_policy_rules
      delete_in_batches(scan_execution_policy_rules)
    end

    private

    def delete_approval_rules(rules_batch)
      delete_in_batches(ApprovalProjectRule.where(approval_policy_rule_id: rules_batch.select(:id)))
      delete_in_batches(
        ApprovalMergeRequestRule
          .for_unmerged_merge_requests
          .where(approval_policy_rule_id: rules_batch.select(:id))
      )
    end

    def delete_policy_violations(rules_batch)
      delete_in_batches(Security::ScanResultPolicyViolation.where(approval_policy_rule_id: rules_batch.select(:id)))
    end

    def delete_software_license_policies(rules_batch)
      delete_in_batches(SoftwareLicensePolicy.where(approval_policy_rule_id: rules_batch.select(:id)))
    end

    def delete_in_batches(relation)
      relation_in_batch(relation, &:delete_all)
    end

    def relation_in_batch(relation)
      relation.each_batch(order_hint: :updated_at) do |batch|
        yield batch
      end
    end
  end
end
