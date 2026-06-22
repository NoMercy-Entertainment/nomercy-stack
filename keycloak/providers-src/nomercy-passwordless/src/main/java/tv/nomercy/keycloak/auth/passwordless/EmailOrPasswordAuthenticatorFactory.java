// -----------------------------------------------------------------------------
//  Copyright (c) NoMercy Entertainment. All rights reserved.
//
//  This file is part of NoMercy and is proprietary and confidential.
//  Unauthorized copying, distribution, or use is prohibited. See LICENSE.
//
//  SPDX-License-Identifier: LicenseRef-NoMercy-Proprietary
// -----------------------------------------------------------------------------

package tv.nomercy.keycloak.auth.passwordless;

import java.util.List;

import org.keycloak.Config;
import org.keycloak.authentication.Authenticator;
import org.keycloak.authentication.AuthenticatorFactory;
import org.keycloak.models.AuthenticationExecutionModel.Requirement;
import org.keycloak.models.KeycloakSession;
import org.keycloak.models.KeycloakSessionFactory;
import org.keycloak.provider.ProviderConfigProperty;

public class EmailOrPasswordAuthenticatorFactory implements AuthenticatorFactory {

    public static final String PROVIDER_ID = "nomercy-email-or-password";

    public static final String CONFIG_CODE_LENGTH = "codeLength";
    public static final String CONFIG_CODE_TTL = "codeTtl";
    public static final String CONFIG_RESEND_COOLDOWN = "resendCooldown";

    private static final EmailOrPasswordAuthenticator INSTANCE = new EmailOrPasswordAuthenticator();

    private static final Requirement[] REQUIREMENT_CHOICES = {
            Requirement.REQUIRED,
            Requirement.ALTERNATIVE,
            Requirement.DISABLED,
    };

    private static final List<ProviderConfigProperty> CONFIG_PROPERTIES = List.of(
            property(CONFIG_CODE_LENGTH, "Code length", "Number of digits in the emailed one-time code.",
                    ProviderConfigProperty.STRING_TYPE, "6"),
            property(CONFIG_CODE_TTL, "Code time-to-live (seconds)", "How long an emailed code stays valid.",
                    ProviderConfigProperty.STRING_TYPE, "300"),
            property(CONFIG_RESEND_COOLDOWN, "Resend cooldown (seconds)", "Minimum wait before a new code can be sent.",
                    ProviderConfigProperty.STRING_TYPE, "30"));

    private static ProviderConfigProperty property(String name, String label, String help, String type, String defaultValue) {
        ProviderConfigProperty property = new ProviderConfigProperty();
        property.setName(name);
        property.setLabel(label);
        property.setHelpText(help);
        property.setType(type);
        property.setDefaultValue(defaultValue);
        return property;
    }

    @Override
    public String getId() {
        return PROVIDER_ID;
    }

    @Override
    public Authenticator create(KeycloakSession session) {
        return INSTANCE;
    }

    @Override
    public String getDisplayType() {
        return "NoMercy Email Code or Password";
    }

    @Override
    public String getReferenceCategory() {
        return "passwordless";
    }

    @Override
    public boolean isConfigurable() {
        return true;
    }

    @Override
    public Requirement[] getRequirementChoices() {
        return REQUIREMENT_CHOICES;
    }

    @Override
    public boolean isUserSetupAllowed() {
        return false;
    }

    @Override
    public String getHelpText() {
        return "Emails a one-time code as the default credential step, with a user-selectable password fallback. "
                + "Run as REQUIRED after the username/email form.";
    }

    @Override
    public List<ProviderConfigProperty> getConfigProperties() {
        return CONFIG_PROPERTIES;
    }

    @Override
    public void init(Config.Scope config) {
    }

    @Override
    public void postInit(KeycloakSessionFactory factory) {
    }

    @Override
    public void close() {
    }
}
