<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=false; section>
    <#if section = "header">
        <img class="nm-logo" src="${url.resourcesPath}/img/nomercy-login-logo.png" alt="${msg("loginTitle",(realm.displayName!''))}"/>
    <#elseif section = "form">
        <#if realm.password>
            <#if realm.registrationAllowed && !registrationDisabled??>
            <div class="nm-tabs">
                <span class="nm-tab is-active" aria-current="page">${msg("doLogIn")}</span>
                <a class="nm-tab" href="${url.registrationUrl}">${msg("doRegister")}</a>
            </div>
            </#if>
            <form id="kc-form-login" class="nm-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                <div class="nm-fields">
                    <#if !usernameHidden??>
                    <div class="nm-field">
                        <label for="username"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if> <span class="nm-req">*</span></label>
                        <div class="nm-input">
                            <input id="username" name="username" value="${(login.username!'')}" type="text" autofocus autocomplete="email"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
                        </div>
                    </div>
                    </#if>
                    <div class="nm-field">
                        <label for="password">${msg("password")} <span class="nm-req">*</span></label>
                        <div class="nm-input">
                            <input id="password" name="password" type="password" autocomplete="current-password"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
                        </div>
                        <#if realm.resetPasswordAllowed>
                        <div class="nm-helper"><a tabindex="5" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a></div>
                        </#if>
                    </div>
                    <#if messagesPerField.existsError('username','password')>
                        <span id="input-error" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}</span>
                    </#if>
                </div>

                <#if realm.rememberMe && !usernameHidden??>
                <label class="nm-check">
                    <input id="rememberMe" name="rememberMe" type="checkbox" <#if login.rememberMe??>checked</#if>/>
                    <span>${msg("rememberMe")}</span>
                </label>
                </#if>

                <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                <button class="nm-btn nm-btn-primary" name="login" id="kc-login" type="submit">
                    ${msg("doLogIn")}
                    <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
                </button>
            </form>
        </#if>
    <#elseif section = "socialProviders">
        <#if realm.password && social?? && social.providers?has_content>
            <div class="nm-divider"><span class="line"></span><span>${msg("identity-provider-login-label")}</span><span class="line"></span></div>
            <div class="nm-social">
                <#list social.providers as p>
                    <a id="social-${p.alias}" class="nm-sbtn" href="${p.loginUrl}" title="${p.displayName!}">
                        <span class="nm-sicon">
                            <#switch p.alias>
                                <#case "github">
                                    <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2C6.48 2 2 6.58 2 12.25c0 4.53 2.87 8.37 6.84 9.73.5.1.68-.22.68-.49v-1.7c-2.78.62-3.37-1.22-3.37-1.22-.45-1.18-1.11-1.49-1.11-1.49-.91-.64.07-.63.07-.63 1 .07 1.53 1.06 1.53 1.06.9 1.57 2.36 1.12 2.94.85.09-.66.35-1.12.63-1.38-2.22-.26-4.56-1.14-4.56-5.06 0-1.12.39-2.03 1.03-2.75-.1-.26-.45-1.3.1-2.7 0 0 .84-.28 2.75 1.05a9.3 9.3 0 0 1 5 0c1.91-1.33 2.75-1.05 2.75-1.05.55 1.4.2 2.44.1 2.7.64.72 1.03 1.63 1.03 2.75 0 3.93-2.35 4.8-4.58 5.05.36.32.68.95.68 1.92v2.85c0 .27.18.6.69.49A10.27 10.27 0 0 0 22 12.25C22 6.58 17.52 2 12 2Z"/></svg>
                                    <#break>
                                <#case "google">
                                    <svg viewBox="0 0 24 24"><path fill="#EA4335" d="M12 11v3.6h5.1c-.2 1.3-1.6 3.9-5.1 3.9-3.1 0-5.6-2.6-5.6-5.7S8.9 7.1 12 7.1c1.8 0 2.9.8 3.6 1.4l2.5-2.4C16.5 4.6 14.5 3.7 12 3.7 7 3.7 3 7.7 3 12.8s4 9.1 9 9.1c5.2 0 8.6-3.6 8.6-8.7 0-.6-.1-1-.2-1.5H12Z"/></svg>
                                    <#break>
                                <#case "gitlab">
                                    <svg viewBox="0 0 24 24" fill="#FC6D26"><path d="m12 21.6 3.3-10.2H8.7L12 21.6Zm0 0L8.7 11.4H4.1L12 21.6Zm-7.9-10.2-1 3.1c-.1.3 0 .6.3.8l8.6 6.3-7.9-10.2Zm0 0h4.6L6.7 4.2c-.1-.3-.5-.3-.6 0l-2 7.2Zm15.8 0 1 3.1c.1.3 0 .6-.3.8L12 21.6l7.9-10.2Zm0 0h-4.6l2-7.2c.1-.3.5-.3.6 0l2 7.2Z"/></svg>
                                    <#break>
                                <#case "facebook">
                                    <svg viewBox="0 0 24 24" fill="#1877F2"><path d="M22 12a10 10 0 1 0-11.6 9.9v-7H7.9V12h2.5V9.8c0-2.5 1.5-3.9 3.8-3.9 1.1 0 2.2.2 2.2.2v2.5h-1.3c-1.2 0-1.6.8-1.6 1.6V12h2.8l-.4 2.9h-2.4v7A10 10 0 0 0 22 12Z"/></svg>
                                    <#break>
                                <#case "stackoverflow">
                                    <svg viewBox="0 0 24 24" fill="#F48024"><path d="M17.4 21.1v-6.4h2.1V23H4.5v-8.3h2.1v6.4h10.8ZM8.7 13.7l8.4 1.8.4-2-8.4-1.8-.4 2Zm1.1-4.9 7.8 3.6.9-1.9-7.8-3.6-.9 1.9Zm2.2-4.7 6.6 5.5 1.3-1.5-6.6-5.5-1.3 1.5ZM8 18.6h8.6v-2H8v2Z"/></svg>
                                    <#break>
                                <#case "oidc">
                                    <svg viewBox="0 0 24 24"><path fill="#F25022" d="M3 3h8.5v8.5H3z"/><path fill="#7FBA00" d="M12.5 3H21v8.5h-8.5z"/><path fill="#00A4EF" d="M3 12.5h8.5V21H3z"/><path fill="#FFB900" d="M12.5 12.5H21V21h-8.5z"/></svg>
                                    <#break>
                                <#default>
                                    <#if p.iconClasses?has_content><i class="${p.iconClasses}" aria-hidden="true"></i></#if>
                            </#switch>
                        </span>
                        <span>${p.displayName!}</span>
                    </a>
                </#list>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout>
