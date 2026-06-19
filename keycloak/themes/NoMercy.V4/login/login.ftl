<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
    <#if section = "header">
        ${msg("loginAccountTitle")}
    <#elseif section = "form">
        <#if realm.password>
            <form id="kc-form-login" class="nm-form" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                <div class="nm-fields">
                    <#if !usernameHidden??>
                    <div class="nm-field">
                        <label for="username"><#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if></label>
                        <div class="nm-input">
                            <input id="username" name="username" value="${(login.username!'')}" type="text" autofocus autocomplete="email"
                                   aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>" placeholder="batman@wayne.co"/>
                        </div>
                    </div>
                    </#if>
                    <div class="nm-field">
                        <label for="password">${msg("password")}</label>
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
                    <a id="social-${p.alias}" class="nm-sbtn" href="${p.loginUrl}">
                        <#if p.iconClasses?has_content><i class="${p.iconClasses}" aria-hidden="true"></i></#if>
                        <span>${p.displayName!}</span>
                    </a>
                </#list>
            </div>
        </#if>
    <#elseif section = "info">
        <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
            <div class="nm-foot"><span class="line"></span><span>${msg("noAccount")}</span><a tabindex="6" href="${url.registrationUrl}">${msg("doRegister")}</a><span class="line"></span></div>
        </#if>
    </#if>
</@layout.registrationLayout>
