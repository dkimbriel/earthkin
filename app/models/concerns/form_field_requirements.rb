# Parses required-field rules out of a structured form body:
#   [[text:key|Label*]]                 label ending in * -> required
#   [[require-one:key1,key2|Message]]   at least one of the keys must be checked
#   [[waive-required-if:key]]           checking key waives every requirement
#                                       (e.g. "my child has no medication")
module FormFieldRequirements
  REQUIRED_TEXT_RE = /\[\[(?:text|textarea):([\w-]+)\|([^\]]*)\*\]\]/
  REQUIRE_ONE_RE = /\[\[require-one:([\w,-]+)(?:\|([^\]]*))?\]\]/
  WAIVE_RE = /\[\[waive-required-if:([\w-]+)\]\]/

  def self.errors_for(body, fields)
    fields = (fields || {}).stringify_keys
    return [] if body.to_s.scan(WAIVE_RE).flatten.any? { |key| checked?(fields[key]) }

    errors = []

    body.to_s.scan(REQUIRED_TEXT_RE) do |key, label|
      errors << label if fields[key].to_s.strip.empty?
    end

    body.to_s.scan(REQUIRE_ONE_RE) do |keys, message|
      chosen = keys.split(',').any? { |k| checked?(fields[k]) }
      errors << (message.presence || 'a required choice') unless chosen
    end

    errors
  end

  def self.checked?(value)
    value == true || value.to_s == 'true'
  end
end
