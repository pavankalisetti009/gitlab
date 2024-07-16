# frozen_string_literal: true

module GitlabSubscriptions
  class UserAddOnAssignment < ApplicationRecord
    include EachBatch

    belongs_to :user, inverse_of: :assigned_add_ons
    belongs_to :add_on_purchase, class_name: 'GitlabSubscriptions::AddOnPurchase', inverse_of: :assigned_users

    validates :user, :add_on_purchase, presence: true
    validates :add_on_purchase_id, uniqueness: { scope: :user_id }

    scope :by_user, ->(user) { where(user: user) }
    scope :for_user_ids, ->(user_ids) { where(user_id: user_ids) }
    scope :with_namespaces, -> { includes(add_on_purchase: :namespace) }
    scope :for_active_add_on_purchases, ->(add_on_purchases) do
      joins(:add_on_purchase).merge(add_on_purchases.active)
    end

    scope :for_active_gitlab_duo_pro_purchase, -> do
      for_active_add_on_purchases(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro)
    end

    scope :for_active_add_on_purchase_ids, ->(add_on_purchase_ids) do
      for_active_add_on_purchases(::GitlabSubscriptions::AddOnPurchase.where(id: add_on_purchase_ids))
    end

    scope :order_by_id_desc, -> { order(id: :desc) }

    def self.pluck_user_ids
      pluck(:user_id)
    end
  end
end
