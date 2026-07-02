<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${kcSanitize(msg("webauthn-registration-title"))?no_esc}</span>
        </span>
    <#elseif section = "form">
        <form id="register" class="nm-form" action="${url.loginAction}" method="post">
            <input type="hidden" id="clientDataJSON" name="clientDataJSON"/>
            <input type="hidden" id="attestationObject" name="attestationObject"/>
            <input type="hidden" id="publicKeyCredentialId" name="publicKeyCredentialId"/>
            <input type="hidden" id="authenticatorLabel" name="authenticatorLabel"/>
            <input type="hidden" id="transports" name="transports"/>
            <input type="hidden" id="error" name="error"/>
            <label class="nm-check">
                <input type="checkbox" id="logout-sessions" name="logout-sessions" value="on"/>
                <span>${msg("logoutOtherSessions")}</span>
            </label>
        </form>

        <div class="nm-btn-stack">
            <button type="button" id="registerWebAuthn" class="nm-btn nm-btn-primary">
                ${msg("doRegister")}
                <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="10" rx="2"/><circle cx="12" cy="16" r="1.5"/><path d="M7 11V8a5 5 0 0 1 9.9-1"/></svg>
            </button>
            <#if !isSetRetry?has_content && isAppInitiatedAction?has_content>
                <form action="${url.loginAction}" id="kc-webauthn-settings-form" method="post">
                    <button type="submit" class="nm-btn nm-btn-ghost" id="cancelWebAuthnAIA" name="cancel-aia" value="true">${msg("doCancel")}</button>
                </form>
            </#if>
        </div>

        <script type="module">
            <#outputformat "JavaScript">
            import { registerByWebAuthn } from "${url.resourcesPath}/js/webauthnRegister.js";

            const input = {
                challenge : ${challenge?c},
                userid : ${userid?c},
                username : ${username?c},
                signatureAlgorithms : [<#list signatureAlgorithms as alg>${alg?c}<#sep>, </#sep></#list>],
                rpEntityName : ${rpEntityName?c},
                rpId : ${rpId?c},
                attestationConveyancePreference : ${attestationConveyancePreference?c},
                authenticatorAttachment : ${authenticatorAttachment?c},
                requireResidentKey : ${requireResidentKey?c},
                userVerificationRequirement : ${userVerificationRequirement?c},
                createTimeout : ${createTimeout?c},
                excludeCredentialIds : ${excludeCredentialIds?c},
                label : ${msg("passkey")?c},
                errmsg : ${msg("webauthn-unsupported-browser-text")?c}
            };

            document.getElementById("registerWebAuthn")
                .addEventListener("click", () => registerByWebAuthn(input));
            </#outputformat>
        </script>
    </#if>
</@layout.registrationLayout>
