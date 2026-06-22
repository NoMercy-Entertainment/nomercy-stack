// -----------------------------------------------------------------------------
//  Copyright (c) NoMercy Entertainment. All rights reserved.
//
//  This file is part of NoMercy and is proprietary and confidential.
//  Unauthorized copying, distribution, or use is prohibited. See LICENSE.
//
//  SPDX-License-Identifier: LicenseRef-NoMercy-Proprietary
// -----------------------------------------------------------------------------

package tv.nomercy.keycloak.auth.passwordless;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;

import jakarta.ws.rs.core.MultivaluedMap;
import jakarta.ws.rs.core.Response;

import org.jboss.logging.Logger;
import org.keycloak.authentication.AuthenticationFlowContext;
import org.keycloak.authentication.AuthenticationFlowError;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorUtil;
import org.keycloak.authentication.authenticators.util.AuthenticatorUtils;
import org.keycloak.common.util.SecretGenerator;
import org.keycloak.models.credential.WebAuthnCredentialModel;
import org.keycloak.email.EmailException;
import org.keycloak.email.EmailSenderProvider;
import org.keycloak.events.Errors;
import org.keycloak.forms.login.LoginFormsProvider;
import org.keycloak.models.AuthenticatorConfigModel;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.RealmModel;
import org.keycloak.models.RoleModel;
import org.keycloak.models.UserCredentialModel;
import org.keycloak.models.UserModel;
import org.keycloak.models.utils.FormMessage;
import org.keycloak.sessions.AuthenticationSessionModel;

/**
 * Browser authenticator that runs as the REQUIRED credential step after the username/email form.
 * It emails a one-time code as the default, and lets the user switch to a password instead.
 * Because the step is REQUIRED and owns both credentials itself, Keycloak never auto-selects
 * the user's stored password over the emailed code.
 */
public class EmailOrPasswordAuthenticator implements Authenticator {

    private static final Logger LOG = Logger.getLogger(EmailOrPasswordAuthenticator.class);

    private static final String NOTE_CODE_HASH = "nm-pwl-code-hash";
    private static final String NOTE_CODE_EXP = "nm-pwl-code-exp";
    private static final String NOTE_ATTEMPTS = "nm-pwl-attempts";
    private static final String NOTE_LAST_SENT = "nm-pwl-last-sent";

    private static final String TEMPLATE_CODE = "nm-code.ftl";
    private static final String TEMPLATE_PASSWORD = "nm-password.ftl";

    private static final int DEFAULT_CODE_LENGTH = 6;
    private static final int DEFAULT_CODE_TTL = 300;
    private static final int DEFAULT_RESEND_COOLDOWN = 30;
    private static final int MAX_CODE_ATTEMPTS = 5;

    /** Realm role that enables the email one-time-code option. Users without it get password-only login. */
    private static final String EMAIL_CODE_ROLE = "email-code-login";

    @Override
    public void authenticate(AuthenticationFlowContext context) {
        if (alreadyAuthenticatedPasswordless(context)) {
            context.success();
            return;
        }
        if (abortIfLockedOut(context)) {
            return;
        }
        UserModel user = context.getUser();
        if (!emailCodeAllowed(context) || !hasEmail(user)) {
            context.challenge(passwordForm(context, null));
            return;
        }
        sendCode(context);
        context.challenge(codeForm(context, null, null));
    }

    private static boolean alreadyAuthenticatedPasswordless(AuthenticationFlowContext context) {
        List<String> used = AuthenticatorUtil.getAuthnCredentials(context.getAuthenticationSession());
        return used != null && used.contains(WebAuthnCredentialModel.TYPE_PASSWORDLESS);
    }

    private static boolean emailCodeAllowed(AuthenticationFlowContext context) {
        RoleModel role = context.getRealm().getRole(EMAIL_CODE_ROLE);
        return role != null && context.getUser().hasRole(role);
    }

    /**
     * Refuses the attempt when Keycloak's brute-force protector has the account locked.
     * The username step only checks at session start, so without this a passed-username session
     * could keep probing password/code attempts after the account is already locked.
     */
    private boolean abortIfLockedOut(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        if (user == null) {
            return false;
        }
        String bruteForceError = AuthenticatorUtils.getDisabledByBruteForceEventError(context, user);
        if (bruteForceError == null) {
            return false;
        }
        context.getEvent().user(user);
        context.getEvent().error(bruteForceError);
        Response challenge = emailCodeAllowed(context) && hasEmail(user)
                ? codeForm(context, "nmTooManyAttempts", null)
                : passwordForm(context, "nmTooManyAttempts");
        context.forceChallenge(challenge);
        return true;
    }

    @Override
    public void action(AuthenticationFlowContext context) {
        if (abortIfLockedOut(context)) {
            return;
        }
        MultivaluedMap<String, String> form = context.getHttpRequest().getDecodedFormParameters();

        if (!emailCodeAllowed(context)) {
            if (form.containsKey("password")) {
                validatePassword(context, form.getFirst("password"));
            } else {
                context.challenge(passwordForm(context, null));
            }
            return;
        }

        if (form.containsKey("usePassword")) {
            context.challenge(passwordForm(context, null));
            return;
        }
        if (form.containsKey("useCode")) {
            sendCode(context);
            context.challenge(codeForm(context, null, null));
            return;
        }
        if (form.containsKey("resend")) {
            resendCode(context);
            return;
        }
        if (form.containsKey("password")) {
            validatePassword(context, form.getFirst("password"));
            return;
        }
        if (form.containsKey("emailCode")) {
            validateCode(context, form.getFirst("emailCode"));
            return;
        }
        context.challenge(codeForm(context, null, null));
    }

    private void validateCode(AuthenticationFlowContext context, String submitted) {
        AuthenticationSessionModel authSession = context.getAuthenticationSession();
        String expectedHash = authSession.getAuthNote(NOTE_CODE_HASH);
        String expiryNote = authSession.getAuthNote(NOTE_CODE_EXP);

        boolean expired = expiryNote == null || Long.parseLong(expiryNote) < System.currentTimeMillis();
        boolean matches = expectedHash != null && submitted != null
                && MessageDigest.isEqual(expectedHash.getBytes(StandardCharsets.UTF_8),
                        hash(submitted.trim()).getBytes(StandardCharsets.UTF_8));

        if (!expired && matches) {
            clearNotes(authSession);
            context.success();
            return;
        }

        int attempts = readInt(authSession.getAuthNote(NOTE_ATTEMPTS), 0) + 1;
        authSession.setAuthNote(NOTE_ATTEMPTS, Integer.toString(attempts));
        if (attempts >= MAX_CODE_ATTEMPTS) {
            authSession.removeAuthNote(NOTE_CODE_HASH);
        }
        String error = expired ? "nmOtpExpired" : "nmOtpInvalid";
        context.getEvent().error(Errors.INVALID_USER_CREDENTIALS);
        context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS, codeForm(context, error, null));
    }

    private void validatePassword(AuthenticationFlowContext context, String password) {
        UserModel user = context.getUser();
        boolean valid = password != null && !password.isEmpty()
                && user.credentialManager().isValid(UserCredentialModel.password(password));
        if (valid) {
            clearNotes(context.getAuthenticationSession());
            context.success();
            return;
        }
        context.getEvent().error(Errors.INVALID_USER_CREDENTIALS);
        context.failureChallenge(AuthenticationFlowError.INVALID_CREDENTIALS, passwordForm(context, "nmInvalidPassword"));
    }

    private void resendCode(AuthenticationFlowContext context) {
        AuthenticationSessionModel authSession = context.getAuthenticationSession();
        long lastSent = readLong(authSession.getAuthNote(NOTE_LAST_SENT), 0L);
        long cooldownMs = resendCooldown(context) * 1000L;
        long remaining = (lastSent + cooldownMs - System.currentTimeMillis()) / 1000L;
        if (remaining > 0) {
            context.challenge(codeForm(context, null, remaining));
            return;
        }
        sendCode(context);
        context.challenge(codeForm(context, null, null));
    }

    private void sendCode(AuthenticationFlowContext context) {
        UserModel user = context.getUser();
        if (!hasEmail(user)) {
            return;
        }
        KeycloakSession session = context.getSession();
        RealmModel realm = context.getRealm();
        int length = codeLength(context);
        int ttl = codeTtl(context);

        String code = SecretGenerator.getInstance().randomString(length, SecretGenerator.DIGITS);
        AuthenticationSessionModel authSession = context.getAuthenticationSession();
        authSession.setAuthNote(NOTE_CODE_HASH, hash(code));
        authSession.setAuthNote(NOTE_CODE_EXP, Long.toString(System.currentTimeMillis() + ttl * 1000L));
        authSession.setAuthNote(NOTE_ATTEMPTS, "0");
        authSession.setAuthNote(NOTE_LAST_SENT, Long.toString(System.currentTimeMillis()));

        String subject = "Your NoMercy sign-in code";
        String text = "Your one-time sign-in code is " + code + ". It expires in " + (ttl / 60) + " minutes.";
        String html = "<p>Your one-time sign-in code is <strong style=\"font-size:20px;letter-spacing:2px\">"
                + code + "</strong>.</p><p>It expires in " + (ttl / 60) + " minutes.</p>";
        try {
            EmailSenderProvider sender = session.getProvider(EmailSenderProvider.class);
            sender.send(realm.getSmtpConfig(), user, subject, text, html);
        } catch (EmailException e) {
            LOG.errorf(e, "Failed to send NoMercy sign-in code to user %s", user.getId());
        }
    }

    private Response codeForm(AuthenticationFlowContext context, String errorKey, Long cooldownRemaining) {
        LoginFormsProvider form = context.form()
                .setAttribute("maskedEmail", maskEmail(context.getUser().getEmail()))
                .setAttribute("codeLength", codeLength(context));
        if (cooldownRemaining != null) {
            form.setAttribute("resendCooldownRemaining", cooldownRemaining);
        }
        if (errorKey != null) {
            form.addError(new FormMessage("emailCode", errorKey));
        }
        return form.createForm(TEMPLATE_CODE);
    }

    private Response passwordForm(AuthenticationFlowContext context, String errorKey) {
        LoginFormsProvider form = context.form()
                .setAttribute("maskedEmail", maskEmail(context.getUser().getEmail()))
                .setAttribute("allowCode", emailCodeAllowed(context));
        if (errorKey != null) {
            form.addError(new FormMessage("password", errorKey));
        }
        return form.createForm(TEMPLATE_PASSWORD);
    }

    private static boolean hasEmail(UserModel user) {
        return user != null && user.getEmail() != null && !user.getEmail().isBlank();
    }

    private static void clearNotes(AuthenticationSessionModel authSession) {
        authSession.removeAuthNote(NOTE_CODE_HASH);
        authSession.removeAuthNote(NOTE_CODE_EXP);
        authSession.removeAuthNote(NOTE_ATTEMPTS);
        authSession.removeAuthNote(NOTE_LAST_SENT);
    }

    private static String maskEmail(String email) {
        if (email == null) {
            return null;
        }
        int at = email.indexOf('@');
        if (at <= 0) {
            return email;
        }
        String local = email.substring(0, at);
        String domain = email.substring(at);
        if (local.length() <= 2) {
            return local.charAt(0) + "***" + domain;
        }
        return local.charAt(0) + "***" + local.charAt(local.length() - 1) + domain;
    }

    private static String hash(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 unavailable", e);
        }
    }

    private int codeLength(AuthenticationFlowContext context) {
        return configInt(context, EmailOrPasswordAuthenticatorFactory.CONFIG_CODE_LENGTH, DEFAULT_CODE_LENGTH);
    }

    private int codeTtl(AuthenticationFlowContext context) {
        return configInt(context, EmailOrPasswordAuthenticatorFactory.CONFIG_CODE_TTL, DEFAULT_CODE_TTL);
    }

    private int resendCooldown(AuthenticationFlowContext context) {
        return configInt(context, EmailOrPasswordAuthenticatorFactory.CONFIG_RESEND_COOLDOWN, DEFAULT_RESEND_COOLDOWN);
    }

    private int configInt(AuthenticationFlowContext context, String key, int fallback) {
        AuthenticatorConfigModel config = context.getAuthenticatorConfig();
        if (config == null || config.getConfig() == null) {
            return fallback;
        }
        return readInt(config.getConfig().get(key), fallback);
    }

    private static int readInt(String value, int fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    private static long readLong(String value, long fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        try {
            return Long.parseLong(value.trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    @Override
    public boolean requiresUser() {
        return true;
    }

    @Override
    public boolean configuredFor(KeycloakSession session, RealmModel realm, UserModel user) {
        return user != null;
    }

    @Override
    public void setRequiredActions(KeycloakSession session, RealmModel realm, UserModel user) {
        // No enrollment required: any user can receive an email code or use their password.
    }

    @Override
    public void close() {
    }
}
