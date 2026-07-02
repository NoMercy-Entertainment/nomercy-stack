<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=false; section>
    <#if section = "header">
        <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
        <div class="nm-tabs">
            <span class="nm-tab is-active" aria-current="page">${msg("doLogIn")}</span>
            <a class="nm-tab" href="${url.registrationUrl}">${msg("doRegister")}</a>
        </div>
        </#if>
    <#elseif section = "form">
        <#if realm.password>
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
                            <#if p.iconClasses?has_content>
                                <i class="${p.iconClasses}" aria-hidden="true"></i>
                            <#else>
                                <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M12 2a10 10 0 100 20 10 10 0 000-20Zm0 1.8a8.2 8.2 0 016.36 13.38L6.62 5.46A8.16 8.16 0 0112 3.8Zm0 16.4a8.2 8.2 0 01-6.36-13.38l11.74 11.72A8.16 8.16 0 0112 20.2Z"/></svg>
                            </#if>
                        </span>
                        <span>${p.displayName!}</span>
                    </a>
                </#list>
            </div>
        </#if>
    </#if>
</@layout.registrationLayout>
