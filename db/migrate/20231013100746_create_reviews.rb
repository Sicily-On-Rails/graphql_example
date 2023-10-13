class CreateReviews < ActiveRecord::Migration[7.0]
  def change
    create_table :reviews do |t|
      t.references :repo, null: false, foreign_key: true
      t.integer :raiting
      t.text :comment

      t.timestamps
    end
  end
end
