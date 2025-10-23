class CreateStocks < ActiveRecord::Migration[8.1]
  def change
    create_table :stocks do |t|
      t.string :ticker
      t.decimal :price
      t.decimal :pe
      t.decimal :roe
      t.decimal :p_vp
      t.decimal :div_yield
      t.datetime :fetched_at
      t.text :raw_html

      t.timestamps
    end
  end
end
