<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('email','username','password','password-confirm','termsAccepted'); section>
    <#if section = "header">
        <div class="nm-tabs">
            <a class="nm-tab" href="${url.loginUrl}">${msg("doLogIn")}</a>
            <span class="nm-tab is-active" aria-current="page">${msg("doRegister")}</span>
        </div>
    <#elseif section = "form">
        <form id="kc-register-form" class="nm-form" action="${url.registrationAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="email">${msg("email")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="text" id="email" name="email" value="${(register.formData.email!'')}" autocomplete="email"
                               aria-invalid="<#if messagesPerField.existsError('email')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('email')>
                        <span id="input-error-email" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('email'))?no_esc}</span>
                    </#if>
                </div>

                <#if !realm.registrationEmailAsUsername>
                <div class="nm-field">
                    <label for="username">${msg("username")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="text" id="username" name="username" value="${(register.formData.username!'')}" autocomplete="username"
                               aria-invalid="<#if messagesPerField.existsError('username')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('username')>
                        <span id="input-error-username" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('username'))?no_esc}</span>
                    </#if>
                </div>
                </#if>

                <#if passwordRequired??>
                <div class="nm-field">
                    <label for="password">${msg("password")} <span class="nm-req">*</span></label>
                    <div class="nm-input">
                        <input type="password" id="password" name="password" autocomplete="new-password"
                               data-pw-length="8" data-pw-digits="1" data-pw-special="1"
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
                               aria-invalid="<#if messagesPerField.existsError('password-confirm')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('password-confirm')>
                        <span id="input-error-password-confirm" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('password-confirm'))?no_esc}</span>
                    </#if>
                </div>
                </#if>
            </div>

            <#if termsAcceptanceRequired??>
            <label class="nm-check">
                <input type="checkbox" id="termsAccepted" name="termsAccepted"
                       aria-invalid="<#if messagesPerField.existsError('termsAccepted')>true</#if>"/>
                <span>${msg("acceptTerms")}</span>
            </label>
            <#if messagesPerField.existsError('termsAccepted')>
                <span id="input-error-terms-accepted" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('termsAccepted'))?no_esc}</span>
            </#if>
            </#if>

            <#if recaptchaRequired??>
                <div class="g-recaptcha" data-size="compact" data-sitekey="${recaptchaSiteKey}"></div>
            </#if>

            <button class="nm-btn nm-btn-primary" id="kc-register" type="submit">
                ${msg("doRegister")}
                <svg class="nm-ico" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>
            </button>
        </form>
    <#elseif section = "socialProviders">
        <#if social?? && social.providers?has_content>
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
