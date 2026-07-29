# Firebase

- Auth: Phone OTP, Google, Apple (as enabled in the Firebase project)
- API verifies ID tokens; never trust a client-only user id for authorization
- Push: FCM tokens registered via push routes / `push_sender` service

Keep service-account material out of git. Configure via env / secret mount per [../deployment.md](../deployment.md).
