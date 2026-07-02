<#import "template.ftl" as layout>
<@layout.registrationLayout displayInfo=true displayMessage=!messagesPerField.existsError('username'); section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("emailForgotTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-reset-password-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="username"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if> <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="text" id="username" name="username" autofocus value="${(auth.attemptedUsername!'')}"
                               aria-invalid="<#if messagesPerField.existsError('username')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('username')>
                        <span id="input-error-username" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('username'))?no_esc}</span>
                    </#if>
                    <div class="nm-helper"><a href="${url.loginUrl}">${kcSanitize(msg("backToLogin"))?no_esc}</a></div>
                </div>
            </div>
            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" type="submit">
                    ${msg("doSubmit")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
            </div>
        </form>
    <#elseif section = "info" >
        <#if realm.duplicateEmailsAllowed>
            ${msg("emailInstructionUsername")}
        <#else>
            ${msg("emailInstruction")}
        </#if>
    </#if>
</@layout.registrationLayout>
