class Review < ApplicationRecord
  belongs_to :repo
  belongs_to :user
  validates :rating, presence: true, numericality: {in: 1..5}
  validates :comment, presence: true

end
