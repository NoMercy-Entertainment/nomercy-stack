<#import "template.ftl" as layout>
<#import "password-commons.ftl" as passwordCommons>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('email'); section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("updateEmailTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-update-email-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="email">${msg("email")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="text" id="email" name="email" value="${(email.value!'')}"
                               aria-invalid="<#if messagesPerField.existsError('email')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('email')>
                        <span id="input-error-email" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('email'))?no_esc}</span>
                    </#if>
                </div>
            </div>

            <@passwordCommons.logoutOtherSessions/>

            <div class="nm-btn-stack">
                <#if isAppInitiatedAction??>
                    <button class="nm-btn nm-btn-primary" type="submit">
                        ${msg("doSubmit")}
                        <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                    </button>
                    <button class="nm-btn nm-btn-ghost" type="submit" name="cancel-aia" value="true">${msg("doCancel")}</button>
                <#else>
                    <button class="nm-btn nm-btn-primary" type="submit">
                        ${msg("doSubmit")}
                        <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                    </button>
                </#if>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
