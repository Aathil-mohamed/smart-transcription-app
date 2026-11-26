# Security Policy

## 1. Firebase Client Keys vs. Secrets

In this application, client configuration identifiers and API keys are strictly partitioned according to their threat models:

### Firebase Client Keys (`firebase_options.dart`, `google-services.json`)
* **Role**: These are public client identifiers, not authorization secrets. They identify the Firebase / Google Cloud project to client SDKs and are embedded into the client app bundle by design.
* **Protection Mechanisms**:
  1. **Backend Security Rules**: Data access is governed by server-side rules (`firestore.rules` and `storage.rules`), enforcing that users can only read, write, and query their own records (`request.auth.uid == userId`).
  2. **Google Cloud API Restrictions**: The keys are restricted in Google Cloud Console to only the required APIs (Identity Toolkit, Token Service, Cloud Firestore, Cloud Storage for Firebase, Firebase Installations). They cannot be used to invoke unrelated or billing-intensive GCP services.

### Third-Party AI API Keys (Groq / Gemini)
* **Role**: These are sensitive server-level authorization secrets with direct billing implications.
* **Storage & Access**:
  1. **Runtime / End-User**: Read exclusively from device-encrypted hardware storage via `flutter_secure_storage`.
  2. **Development / Fallback**: Injected via `--dart-define-from-file=env/secrets.json`. The `env/secrets.json` file is strictly ignored by version control (`.gitignore`).
  3. **Zero Hardcoding Policy**: No API keys, tokens, or credentials may ever be committed to the source code repository or tracked files. Only example templates (`env/secrets.example.json`) are checked in.

---

## 2. Reporting a Vulnerability

If you discover a potential security vulnerability, please report it responsibly by contacting the project maintainers rather than opening a public issue.
