# frozen_string_literal: true

class CreateComplexityRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :complexity_requests, id: :uuid do |t|
      t.string :status, null: false, default: "pending"
      t.jsonb :words, null: false, default: []
      t.jsonb :result, null: false, default: {}
      t.jsonb :word_errors, null: false, default: {}
      t.string :error

      t.timestamps
    end
  end
end
