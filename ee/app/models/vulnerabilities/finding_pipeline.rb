# frozen_string_literal: true

module Vulnerabilities
  class FindingPipeline < ApplicationRecord
    include EachBatch

    self.table_name = "vulnerability_occurrence_pipelines"

    alias_attribute :finding_id, :occurrence_id

    belongs_to :finding, class_name: 'Vulnerabilities::Finding', inverse_of: :finding_pipelines, foreign_key: 'occurrence_id'
    belongs_to :pipeline, class_name: '::Ci::Pipeline'

    validates :finding, presence: true
    validates :pipeline, presence: true
    validates :pipeline_id, uniqueness: { scope: [:occurrence_id] }

    scope :by_finding_id, ->(finding_ids) { where(occurrence_id: finding_ids) }
  end
end
