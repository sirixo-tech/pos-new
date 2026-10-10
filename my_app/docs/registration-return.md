# Return to POS after registration

App-side support is implemented for Android, iOS, and web. The registration
website must implement the following contract before automatic return works.
Windows/macOS/Linux scheme registration is not implemented.

POS opens `/register?source=pos&return_to=...`. Mobile uses
`selfxpos://registration-complete`; web uses its current deployment URL.

The registration server must validate `return_to`, keep it in the server-side
registration session through account creation/verification, and redirect only
after registration succeeds. Allow only the exact mobile callback (no user info,
port, query, or extra path), or explicitly configured POS web origins and paths.
Do not accept arbitrary return URLs or simply reflect user input into a redirect.
Local development web origins must be explicitly allowed in development only.

The success page should attempt to open the approved callback and also provide a
“Continue to POS” link because mobile browsers may require a user tap. If no
approved return URL is present, retain the website's normal registration flow.

Returning opens the POS login screen. It does not automatically sign in: staff
must use their newly created credentials. No password or bearer token is passed
in the redirect URL. Existing POS sessions are preserved.

Rebuild native apps after the manifest/plist changes. Check on an Android device:

```sh
adb shell am start -a android.intent.action.VIEW -d 'selfxpos://registration-complete'
```

Verify both a running app and a terminated app return to POS. On iOS test the
same callback from Safari on a device. The end-to-end registration redirect
cannot be verified until the registration website implements this contract.
