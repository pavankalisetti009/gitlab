# frozen_string_literal: true

module Gitlab
  module Security
    module Orchestration
      ExecutionPolicyConfig = Struct.new(:content, :strategy, :suffix_strategy, :suffix)
    end
  end
end
