<#import "template.ftl" as layout>
<#import "passkeys.ftl" as passkeys>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username') displayInfo=false; section>
    <#if section = "header">
        <#if realm.registrationAllowed && !registrationDisabled??>
        <div class="nm-tabs">
            <span class="nm-tab is-active" aria-current="page">${msg("doLogIn")}</span>
            <a class="nm-tab" href="${url.registrationUrl}">${msg("doRegister")}</a>
        </div>
        </#if>
    <#elseif section = "form">
        <form id="kc-form-login" class="nm-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <#if !usernameHidden??>
                <div class="nm-field">
                    <label for="username"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if> <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input id="username" name="username" value="${(login.username!'')}" type="text" autofocus
                               autocomplete="${(enableWebAuthnConditionalUI?has_content)?then('username webauthn', 'email')}"
                               aria-invalid="<#if messagesPerField.existsError('username')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('username')>
                        <span id="input-error-username" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('username'))?no_esc}</span>
                    </#if>
                </div>
                </#if>
            </div>
            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">
                    ${msg("doLogIn")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
                <@passkeys.passkeyButton />
            </div>
        </form>
        <@passkeys.conditionalUIData />
    <#elseif section = "socialProviders">
        <#if social?? && social.providers?has_content>
            <div class="nm-divider"><span class="line"></span><span>${msg("identity-provider-login-label")}</span><span class="line"></span></div>
            <div class="nm-social">
                <#list social.providers as p>
                    <a id="social-${p.alias}" class="nm-sbtn" href="${p.loginUrl}" title="${p.displayName!}">
                        <span class="nm-sicon">
                            <#if p.iconClasses?has_content>
                                <i class="${p.iconClasses}" aria-hidden="true"></i>
                            <#else>
                                <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2a10 10 0 100 20 10 10 0 000-20Zm0 1.8a8.2 8.2 0 016.36 13.38L6.62 5.46A8.16 8.16 0 0112 3.8Zm0 16.4a8.2 8.2 0 01-6.36-13.38l11.74 11.72A8.16 8.16 0 0112 20.2Z"/></svg>
                            </#if>
                        </span>
                        <span>${p.displayName!}</span>
                    </a>
                </#list>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout>
