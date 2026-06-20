<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('totp'); section>
    <#if section="header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("doLogIn")}</span>
        </span>
    <#elseif section="form">
        <form id="kc-otp-reset-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-field">
                <p id="kc-otp-reset-form-description">${msg("otp-reset-description")}</p>
                <div class="nm-otp-creds">
                    <#list configuredOtpCredentials.userOtpCredentials as otpCredential>
                        <label class="nm-check" for="kc-otp-credential-${otpCredential?index}" tabindex="${otpCredential?index}">
                            <input id="kc-otp-credential-${otpCredential?index}" type="radio" name="selectedCredentialId" value="${otpCredential.id}" <#if otpCredential.id == configuredOtpCredentials.selectedCredentialId>checked="checked"</#if>/>
                            <span>${otpCredential.userLabel}</span>
                        </label>
                    </#list>
                </div>
            </div>

            <div class="nm-btn-stack">
                <button id="kc-otp-reset-form-submit" class="nm-btn nm-btn-primary" type="submit">
                    ${msg("doSubmit")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
