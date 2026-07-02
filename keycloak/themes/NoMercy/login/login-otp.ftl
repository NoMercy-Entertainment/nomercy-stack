<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('totp'); section>
    <#if section="header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("nmOtpTitle")}</span>
            <span class="nm-head__sub">${msg("nmOtpAuthApp")}</span>
        </span>
    <#elseif section="form">
        <form id="kc-otp-login-form" class="nm-form" action="${url.loginAction}" method="post">
            <#if otpLogin.userOtpCredentials?size gt 1>
                <div class="nm-field">
                    <label>${msg("loginChooseAuthenticator")}</label>
                    <div class="nm-otp-creds">
                        <#list otpLogin.userOtpCredentials as otpCredential>
                            <label class="nm-check">
                                <input type="radio" name="selectedCredentialId" value="${otpCredential.id}"
                                       <#if otpCredential.id == otpLogin.selectedCredentialId>checked="checked"</#if>/>
                                <span>${otpCredential.userLabel}</span>
                            </label>
                        </#list>
                    </div>
                </div>
            </#if>

            <div class="nm-field">
                <div class="nm-input">
                    <input id="otp" name="otp" type="text" inputmode="numeric" autocomplete="one-time-code" autofocus
                           aria-label="${msg("nmOtpTitle")}"
                           aria-invalid="<#if messagesPerField.existsError('totp')>true</#if>"/>
                </div>
                <div class="nm-code" data-nm-otp data-target="#otp" data-length="6" data-dash="3"></div>
                <#if messagesPerField.existsError('totp')>
                    <span id="input-error-otp-code" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('totp'))?no_esc}</span>
                </#if>
            </div>

            <div class="nm-row">
                <a class="nm-btn nm-btn-ghost" href="${url.loginRestartFlowUrl}">${msg("doCancel")}</a>
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">
                    ${msg("doLogIn")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
