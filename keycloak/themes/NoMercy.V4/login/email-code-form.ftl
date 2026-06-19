<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('emailCode'); section>
    <#if section="header">
        ${msg("doLogIn")}
    <#elseif section="form">
        <form id="kc-otp-login-form" class="${properties.kcFormClass!}" action="${url.loginAction}"
            method="post">
            <#assign otpLength = (codeLength!6)>

            <div class="${properties.kcFormGroupClass!}">
                <div class="${properties.kcLabelWrapperClass!}">
                    <label for="emailCode" class="${properties.kcLabelClass!}">${msg("emailOtpForm", otpLength)}<#if maskedEmail??>: <strong>${kcSanitize(maskedEmail)?no_esc}</strong></#if></label>
                </div>

                <div class="${properties.kcInputWrapperClass!}">
                    <input id="emailCode" name="emailCode" type="text"
                           inputmode="numeric" pattern="[0-9]*" autocomplete="one-time-code"
                           class="${properties.kcInputClass!}" autofocus
                           aria-invalid="<#if messagesPerField.existsError('emailCode')>true</#if>"
                           aria-describedby="email-code-hint"
                           <#if maxAttemptsReached?? && maxAttemptsReached>disabled</#if>/>
                    <span id="email-code-hint" class="${properties.kcInputHelperTextClass!}">${msg("emailCodeHint")}</span>
                    <#if messagesPerField.existsError('emailCode')>
                        <span id="input-error-email-code" class="${properties.kcInputErrorMessageClass!}" aria-live="polite">
                            ${kcSanitize(messagesPerField.get('emailCode'))?no_esc}
                        </span>
                    </#if>
                </div>
            </div>

            <div id="email-code-resend" role="status" aria-live="polite">
                <#if resendCooldownRemaining?? && (resendCooldownRemaining > 0)>
                    ${msg("email-authenticator-resend-cooldown", resendCooldownRemaining)}
                </#if>
            </div>

            <div class="${properties.kcFormGroupClass!}">
                <div id="kc-form-options" class="${properties.kcFormOptionsClass!}">
                    <div class="${properties.kcFormOptionsWrapperClass!}">
                    </div>
                </div>

                <div id="kc-form-buttons">
                    <div class="${properties.kcFormButtonsWrapperClass!}">
                        <#if !(maxAttemptsReached?? && maxAttemptsReached)>
                            <input class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonLargeClass!}" name="login" type="submit" value="${msg("doLogIn")}"/>
                        </#if>
                        <input class="${properties.kcButtonClass!} <#if maxAttemptsReached?? && maxAttemptsReached>${properties.kcButtonPrimaryClass!}<#else>${properties.kcButtonSecondaryClass!}</#if> ${properties.kcButtonLargeClass!}" name="resend" type="submit" value="${msg("resendCode")}"/>
                        <input class="${properties.kcButtonClass!} ${properties.kcButtonDefaultClass!} ${properties.kcButtonLargeClass!}" name="cancel" type="submit" value="${msg("doCancel")}"/>
                    </div>
                </div>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
