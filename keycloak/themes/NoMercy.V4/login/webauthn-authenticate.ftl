<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${kcSanitize(msg("webauthn-login-title"))?no_esc}</span>
        </span>
    <#elseif section = "form">
        <form id="webauth" class="nm-form" action="${url.loginAction}" method="post">
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

        <div class="nm-btn-stack">
            <button type="button" id="authenticateWebAuthnButton" class="nm-btn nm-btn-primary" autofocus>
                <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="10" rx="2"/><circle cx="12" cy="16" r="1.5"/><path d="M7 11V8a5 5 0 0 1 9.9-1"/></svg>
                ${msg("webauthn-doAuthenticate")}
            </button>
        </div>

        <script type="module">
            <#outputformat "JavaScript">
            import { authenticateByWebAuthn } from "${url.resourcesPath}/js/webauthnAuthenticate.js";

            const args = {
                isUserIdentified : ${isUserIdentified},
                challenge : ${challenge?c},
                userVerification : ${userVerification?c},
                rpId : ${rpId?c},
                createTimeout : ${createTimeout?c},
                errmsg : ${msg("webauthn-unsupported-browser-text")?c}
            };

            document.getElementById("authenticateWebAuthnButton")
                .addEventListener("click", () => authenticateByWebAuthn(args));
            </#outputformat>
        </script>
    </#if>
</@layout.registrationLayout>
