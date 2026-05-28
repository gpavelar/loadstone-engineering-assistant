class User < ApplicationRecord
  has_many :conversations, dependent: :destroy
  has_many :ideas, dependent: :destroy
  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
end
