class Stock < ApplicationRecord
  validates :ticker, presence: true, uniqueness: true
end
