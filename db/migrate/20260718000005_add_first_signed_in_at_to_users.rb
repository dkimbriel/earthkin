# frozen_string_literal: true

# Tracks the first time a user signs in, so we can alert admins once when a
# family logs into the portal for the first time (a cue to issue enrollment
# forms). Nil means they've never signed in.
class AddFirstSignedInAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :first_signed_in_at, :datetime
  end
end
