# Gmail Integration Setup

Outgoing email is sent through a Gmail mailbox connected via OAuth, configured by
a super-admin under **Integrations** in the app. This avoids SMTP App Passwords
(which the Google account doesn't allow) and uses the Gmail API instead.

There are two one-time setup steps: a Google Cloud project (done in the Google
Console) and two server environment variables. After that, an admin connects the
mailbox from the UI.

## 1. Google Cloud Console (one-time)

Sign in as the owner of **earthkinnatureschool@gmail.com**, then:

1. Go to https://console.cloud.google.com/ and create a project (e.g. "Earthkin App").
2. **APIs & Services → Library →** enable the **Gmail API**.
3. **APIs & Services → OAuth consent screen:**
   - User type: **External**.
   - Fill in app name, support email, developer email.
   - Add scopes: `.../auth/gmail.send`, `openid`, `email`.
   - Add **earthkinnatureschool@gmail.com** as a **Test user** (or publish the app
     to remove the test-user requirement).
4. **APIs & Services → Credentials → Create Credentials → OAuth client ID:**
   - Application type: **Web application**.
   - Authorized redirect URIs — add one per environment:
     - `http://localhost:3000/admin/integrations/gmail/callback` (dev)
     - `https://YOUR_PROD_DOMAIN/admin/integrations/gmail/callback` (prod)
   - Save and copy the **Client ID** and **Client Secret**.

## 2. Credentials

The Client ID and Secret are read from Rails encrypted credentials (preferred), or
from environment variables as a fallback. Edit credentials with
`bin/rails credentials:edit` and add:

```yaml
google:
  oauth_client_id: YOUR_CLIENT_ID
  oauth_client_secret: YOUR_CLIENT_SECRET
  # oauth_redirect_uri: https://YOUR_PROD_DOMAIN/admin/integrations/gmail/callback
```

Resolution order for each value (`GmailOauth`):

| Value | Credentials key | ENV fallback | Notes |
| --- | --- | --- | --- |
| Client ID | `google.oauth_client_id` | `GOOGLE_CLIENT_ID` | required |
| Client Secret | `google.oauth_client_secret` | `GOOGLE_CLIENT_SECRET` | required |
| Redirect URI | `google.oauth_redirect_uri` | `GOOGLE_REDIRECT_URI` | must exactly match a redirect URI from step 1.4; defaults to the localhost URL |

`config.action_mailer.delivery_method = :gmail_api` is already set for production,
so once a mailbox is connected, all mailers send through it.

## 3. Connect the mailbox (in the app)

1. Sign in as a user with `super_admin = true`.
   (Set one in the console: `User.find_by(email: "...").update!(super_admin: true)`.)
2. Go to **Integrations** in the sidebar → **Connect Gmail**.
3. Complete Google's consent screen as **earthkinnatureschool@gmail.com**.
4. You'll return to the Integrations page showing **Connected**.

## How it works

- The OAuth flow (`Admin::IntegrationsController`) stores an encrypted **refresh
  token** in the `gmail_integrations` table (`app/models/gmail_integration.rb`).
  Tokens are encrypted at rest via `EncryptedString` (key derived from
  `secret_key_base`).
- `GmailApiDelivery` (`app/mailers/gmail_api_delivery.rb`) refreshes the access
  token as needed and sends each message through the Gmail API.
- The `from` address on the mailers is `earthkinnatureschool@gmail.com`; Gmail
  sends as the authenticated account, so keep these aligned.

## Notes & limits

- Gmail sending limit is ~500 messages/day for a standard account, ~2,000/day for
  Google Workspace. If volume grows beyond that, switch to a transactional
  provider (SendGrid/Postmark) — only `GmailApiDelivery` would need replacing.
- If a send fails with "Gmail integration is not connected", reconnect the mailbox
  from the Integrations page.
- Disconnecting clears the stored tokens; reconnecting re-runs the consent flow.
