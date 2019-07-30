# frozen_string_literal: true

class CreateMovies < ActiveRecord::Migration[5.2]
  def change
    create_table :movies do |t|
      t.string :title, null: false
      t.string :director, null: false

      t.timestamps
    end
  end
end
