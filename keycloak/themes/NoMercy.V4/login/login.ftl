<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=false; section>
    <#if section = "header">
        <span class="nm-logo">
            <svg class="nm-logo__mark" viewBox="2 4 44 32" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${msg("loginTitle",(realm.displayName!''))}">
                <path fill="var(--logo-accent)" fill-rule="evenodd" clip-rule="evenodd" d="M19.377 32.271c-1.495 1.01-2.243 1.516-2.864 1.481a1.846 1.846 0 01-1.368-.726c-.376-.495-.376-1.398-.376-3.202V10.176c0-1.804 0-2.707.376-3.202a1.846 1.846 0 011.368-.726c.621-.035 1.369.47 2.864 1.48l14.54 9.824c1.212.82 1.819 1.23 2.031 1.745.185.45.185.956 0 1.406-.212.515-.819.925-2.032 1.745l-14.54 9.823zm23.392-25.81c.68 0 1.231.552 1.231 1.231v24.616c0 .68-.551 1.23-1.23 1.23h-2.924a1.23 1.23 0 01-1.23-1.23V7.692c0-.68.55-1.23 1.23-1.23h2.923z"/>
                <path fill="var(--logo-accent-light)" fill-rule="evenodd" clip-rule="evenodd" d="M6.88 33.439c-1.226.828-2.88-.05-2.88-1.53V8.091c0-1.48 1.654-2.358 2.88-1.53l17.625 11.91a1.846 1.846 0 010 3.059L6.88 33.439zM32 6.462c.68 0 1.23.55 1.23 1.23v24.616c0 .68-.55 1.23-1.23 1.23h-2.923a1.23 1.23 0 01-1.23-1.23V7.692c0-.68.55-1.23 1.23-1.23H32z"/>
            </svg>
            <span class="nm-logo__text">
                <span class="nm-logo__name">NoMercyTV</span>
                <span class="nm-logo__tag">The Effortless Encoder</span>
            </span>
        </span>
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
