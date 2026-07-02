<#-- Passkey integration for the username screen (Keycloak 26.4+ seamless conditional UI).
     Rendered only when the authenticator exposes enableWebAuthnConditionalUI. Uses our
     native WebAuthn ceremony (no rfc4648): conditional-mediation autofill on page load,
     plus the grey button below as the explicit trigger. Both share one AbortController. -->

<#macro passkeyButton>
    <#if enableWebAuthnConditionalUI?has_content>
        <button type="button" id="authenticateWebAuthnButton" class="nm-btn nm-btn-passkey">
            <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="10" rx="2"/><circle cx="12" cy="16" r="1.5"/><path d="M7 11V8a5 5 0 0 1 9.9-1"/></svg>
            ${msg("webauthn-doAuthenticate")}
        </button>
    </#if>
</#macro>

<#macro conditionalUIData>
    <#if enableWebAuthnConditionalUI?has_content>
        <form id="webauth" action="${url.loginAction}" method="post" style="display:none">
            <input type="hidden" id="clientDataJSON" name="clientDataJSON"/>
            <input type="hidden" id="authenticatorData" name="authenticatorData"/>
            <input type="hidden" id="signature" name="signature"/>
            <input type="hidden" id="credentialId" name="credentialId"/>
            <input type="hidden" id="userHandle" name="userHandle"/>
            <input type="hidden" id="error" name="error"/>
        </form>
        <#if authenticators??>
            <form id="authn_select" style="display:none">
                <#list authenticators.authenticators as authenticator>
                    <input type="hidden" name="authn_use_chk" value="${authenticator.credentialId}"/>
                </#list>
            </form>
        </#if>
        <script type="module">
            <#outputformat "JavaScript">
            import { authenticateByWebAuthn } from "${url.resourcesPath}/js/webauthnAuthenticate.js";
            import { initAuthenticate } from "${url.resourcesPath}/js/passkeysConditionalAuth.js";

            const args = {
                isUserIdentified : ${isUserIdentified},
                challenge : ${challenge?c},
                userVerification : ${userVerification?c},
                rpId : ${rpId?c},
                createTimeout : ${createTimeout?c},
                errmsg : ${msg("webauthn-unsupported-browser-text")?c}
            };

            document.addEventListener("DOMContentLoaded", () => initAuthenticate(args));

            const authButton = document.getElementById("authenticateWebAuthnButton");
            if (authButton) {
                authButton.addEventListener("click", (event) => {
                    event.preventDefault();
                    authenticateByWebAuthn(args);
                }, { once: true });
            }
            </#outputformat>
        </script>
    </#if>
</#macro>
