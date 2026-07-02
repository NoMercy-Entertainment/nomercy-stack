<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('password'); section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("doLogIn")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-form-login" class="nm-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="password">${msg("password")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input id="password" name="password" type="password" autocomplete="current-password" autofocus
                               data-pw-length="8" data-pw-digits="1" data-pw-special="1"
                               aria-invalid="<#if messagesPerField.existsError('password')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('password')>
                        <span id="input-error-password" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('password'))?no_esc}</span>
                    </#if>
                    <#if realm.resetPasswordAllowed>
                        <div class="nm-helper"><a href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a></div>
                    </#if>
                </div>
            </div>
            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">
                    ${msg("doLogIn")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
