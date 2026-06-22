<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('emailCode'); section>
    <#if section="header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("nmOtpTitle")}</span>
            <#if maskedEmail??>
                <span class="nm-head__sub">${msg("nmOtpEmailSub")} <strong>${kcSanitize(maskedEmail)?no_esc}</strong></span>
            <#else>
                <span class="nm-head__sub">${msg("nmOtpEmailSubGeneric")}</span>
            </#if>
        </span>
    <#elseif section="form">
        <form id="kc-otp-login-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-field">
                <div class="nm-input">
                    <input id="emailCode" name="emailCode" type="text" inputmode="numeric" pattern="[0-9]*"
                           autocomplete="one-time-code" autofocus
                           aria-invalid="<#if messagesPerField.existsError('emailCode')>true</#if>"
                           aria-label="${msg("nmOtpTitle")}"/>
                </div>
                <div class="nm-code" data-nm-otp data-target="#emailCode" data-length="${(codeLength!6)}" data-dash="0"></div>
                <#if messagesPerField.existsError('emailCode')>
                    <span id="input-error-email-code" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('emailCode'))?no_esc}</span>
                </#if>
            </div>

            <div id="email-code-resend" class="nm-status" role="status" aria-live="polite">
                <#if resendCooldownRemaining?? && (resendCooldownRemaining > 0)>
                    ${msg("email-authenticator-resend-cooldown", resendCooldownRemaining)}
                </#if>
            </div>

            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">
                    ${msg("doLogIn")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
            </div>

            <p class="nm-resend">${msg("nmDidntReceive")} <button class="nm-linkbtn" name="resend" type="submit">${msg("nmSendNewCode")}</button></p>
            <p class="nm-alt"><button class="nm-linkbtn" name="usePassword" type="submit">${msg("nmUsePassword")}</button></p>
        </form>
    </#if>
</@layout.registrationLayout>
