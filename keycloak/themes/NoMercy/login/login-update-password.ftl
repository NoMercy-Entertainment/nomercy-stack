<#import "template.ftl" as layout>
<#import "password-commons.ftl" as passwordCommons>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('password','password-confirm'); section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("updatePasswordTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-passwd-update-form" class="nm-form" action="${url.loginAction}" method="post">
            <input type="text" id="username" name="username" value="${username}" autocomplete="username"
                   readonly="readonly" style="display:none;"/>
            <input type="password" id="password" name="password" autocomplete="current-password" style="display:none;"/>

            <div class="nm-fields">
                <div class="nm-field">
                    <label for="password-new">${msg("passwordNew")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="password" id="password-new" name="password-new"
                               autofocus autocomplete="new-password"
                               aria-invalid="<#if messagesPerField.existsError('password','password-confirm')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('password')>
                        <span id="input-error-password" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('password'))?no_esc}</span>
                    </#if>
                </div>

                <div class="nm-field">
                    <label for="password-confirm">${msg("passwordConfirm")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="password" id="password-confirm" name="password-confirm"
                               autocomplete="new-password"
                               aria-invalid="<#if messagesPerField.existsError('password-confirm')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('password-confirm')>
                        <span id="input-error-password-confirm" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('password-confirm'))?no_esc}</span>
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
