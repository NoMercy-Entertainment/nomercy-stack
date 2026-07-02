<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('recoveryCodeInput'); section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("auth-recovery-code-header")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-recovery-code-login-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="recoveryCodeInput">${msg("auth-recovery-code-prompt", recoveryAuthnCodesInputBean.codeNumber?c)}</label>
                    <div class="nm-input">
                        <input tabindex="1" id="recoveryCodeInput"
                               name="recoveryCodeInput"
                               aria-invalid="<#if messagesPerField.existsError('recoveryCodeInput')>true</#if>"
                               autocomplete="off"
                               type="text"
                               autofocus/>
                    </div>
                    <#if messagesPerField.existsError('recoveryCodeInput')>
                        <span id="input-error" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('recoveryCodeInput'))?no_esc}</span>
                    </#if>
                </div>
            </div>

            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">${msg("doLogIn")}</button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
