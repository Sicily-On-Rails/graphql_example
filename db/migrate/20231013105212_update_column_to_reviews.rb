class UpdateColumnToReviews < ActiveRecord::Migration[7.0]
  def change
    rename_column :reviews, :raiting, :rating 
  end
end
