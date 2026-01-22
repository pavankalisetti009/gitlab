# frozen_string_literal: true

module Ai
  module ActiveContext
    module Migrations
      class CreateProjects
        def migrate!
          create_collection :projects, number_of_partitions: 3 do |c|
            c.bigint :id
            c.vector :embeddings, dimensions: 768
          end
        end

        def completed?
          true
        end
      end
    end
  end
end
