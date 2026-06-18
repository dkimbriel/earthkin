# frozen_string_literal: true

# ActiveRecord attribute type that encrypts the value at rest using a key
# derived from the app's secret_key_base. Used for storing OAuth tokens.
class EncryptedString < ActiveRecord::Type::Text
	def serialize(value)
		return if value.nil?

		encryptor.encrypt_and_sign(value.to_s)
	end

	def deserialize(value)
		return if value.nil?

		encryptor.decrypt_and_verify(value)
	rescue ActiveSupport::MessageEncryptor::InvalidMessage
		nil
	end

	private

	def encryptor
		len = ActiveSupport::MessageEncryptor.key_len
		key = ActiveSupport::KeyGenerator
								.new(Rails.application.secret_key_base)
								.generate_key('gmail_integration_tokens', len)
		ActiveSupport::MessageEncryptor.new(key)
	end
end
