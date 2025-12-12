class RenamePeToPlInStocks < ActiveRecord::Migration[8.1]
  def change
    rename_column :stocks, :pe, :pl
  end
end
