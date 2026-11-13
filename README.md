# FamilyFit v3 — Homsi family edition

## What is included
Animated blue/black welcome, Developed by Yaman, Homsi surname gate, four profile choices, Supabase email/password login, password change and reset, admin invitations and member revocation, private personal health logs, foods and recipes, and photo preview (NOT AI analysis).

## Important security and setup
1. Create a **new** Supabase project. Run `schema.sql` in SQL Editor. Never expose the service-role key.
2. Create **Yaman's account first** using a verified email you control. Select `Homsi`, then `Yaman`, then Create account. Complete email verification, sign in, and choose Create family. **Do not publish the website or share the Supabase credentials until Yaman has created the family.** The first-family bootstrap is a first-claim operation, not a cryptographically preassigned admin identity.
3. Sign in as Yaman, generate one-time invitation codes for Lama, Wassim and Talya (Talya as Child / teen). Send each code privately. Each person creates their own Supabase Auth account and joins with their code. If children are too young to consent to their own account, a parent should control setup and access; check local legal requirements.
4. Under Supabase Authentication > URL Configuration, add your GitHub Pages URL as an allowed redirect URL for password recovery. Password resets require configured email delivery.
5. Upload `index.html`, `style.css`, `app.js` to GitHub Pages. On first launch supply your Supabase URL and **publishable / anon** key (never secret or service-role key).
6. Once members have joined, turn off public email signups in Supabase Authentication settings to stop unauthorized account creation. Keep invitation codes confidential.

## Privacy and limitations
Surname and displayed names are **not authentication**; they are UI navigation only. The database enforces per-user health entries through row-level security. Yaman is an organizer who can invite and revoke family membership, but cannot read other users' health entries. Supabase infrastructure administrators may have technical access. No guarantee of zero developer access or end-to-end encryption. Avoid entering sensitive real health information until you have tested and audited your Supabase policies. A parent/guardian should review child consent and data practices.

**Important:** The initial `create_family` SQL function permits the first authenticated user who claims the Yaman name to create the Homsi family. Provision Yaman's account before publishing. For production-grade protection, pre-provision the organizer by exact Auth user UUID in SQL and disable public onboarding. Member names are not proof of identity. The current UI is a prototype, not a medically certified product.

AI photo calorie analysis is **not implemented**. Manual nutrition entry works; estimates are approximate and not medical advice. BMI is shown only for adult profiles.
