# Security

Human / Duo Fold is an experimental UI and validation prototype. It is **not** a production CAPTCHA or access-control boundary. Challenge generation and validation happen in the app; the website accepts a matching URL callback using browser storage. An attacker who controls the client or crafts the callback can bypass this flow.

Do not rely on this repository to protect accounts, money, private data, or rate-limited services. Production use would require a trusted server to issue one-time challenges, validate proof or trusted device attestations, expire and consume sessions, and bind outcomes to the protected action. The current repository does not implement those controls.

If you find a vulnerability beyond these documented limitations, please use GitHub's private vulnerability reporting if enabled for the repository, or contact the repository owner privately. Avoid including secrets or personal data in a public issue.
