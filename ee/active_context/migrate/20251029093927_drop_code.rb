# frozen_string_literal: true

class DropCode < ActiveContext::Migration[1.0]
  milestone '18.6'

  def migrate!
    drop_collection :code
  end
end
