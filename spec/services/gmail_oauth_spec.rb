require 'rails_helper'

RSpec.describe GmailOauth do
  describe '.send_scope_granted?' do
    it 'is true when the granted scopes include gmail.send' do
      scopes = 'https://www.googleapis.com/auth/gmail.send email openid'
      expect(described_class.send_scope_granted?(scopes)).to be(true)
    end

    it 'is false for sign-in-only scopes (the failure we hit in production)' do
      scopes = 'email https://www.googleapis.com/auth/userinfo.email openid'
      expect(described_class.send_scope_granted?(scopes)).to be(false)
    end

    it 'is false for blank scopes' do
      expect(described_class.send_scope_granted?('')).to be(false)
      expect(described_class.send_scope_granted?(nil)).to be(false)
    end
  end
end
