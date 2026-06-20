<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','email','firstName','lastName'); section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("loginProfileTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-update-profile-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-fields">
                <#if user.editUsernameAllowed>
                    <div class="nm-field">
                        <label for="username">${msg("username")}</label>
                        <div class="nm-input">
                            <input type="text" id="username" name="username" value="${(user.username!'')}"
                                   aria-invalid="<#if messagesPerField.existsError('username')>true</#if>"/>
                        </div>
                        <#if messagesPerField.existsError('username')>
                            <span id="input-error-username" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('username'))?no_esc}</span>
                        </#if>
                    </div>
                </#if>
                <#if user.editEmailAllowed>
                    <div class="nm-field">
                        <label for="email">${msg("email")}</label>
                        <div class="nm-input">
                            <input type="text" id="email" name="email" value="${(user.email!'')}"
                                   aria-invalid="<#if messagesPerField.existsError('email')>true</#if>"/>
                        </div>
                        <#if messagesPerField.existsError('email')>
                            <span id="input-error-email" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('email'))?no_esc}</span>
                        </#if>
                    </div>
                </#if>

                <div class="nm-field">
                    <label for="firstName">${msg("firstName")}</label>
                    <div class="nm-input">
                        <input type="text" id="firstName" name="firstName" value="${(user.firstName!'')}"
                               aria-invalid="<#if messagesPerField.existsError('firstName')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('firstName')>
                        <span id="input-error-firstname" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('firstName'))?no_esc}</span>
                    </#if>
                </div>

                <div class="nm-field">
                    <label for="lastName">${msg("lastName")}</label>
                    <div class="nm-input">
                        <input type="text" id="lastName" name="lastName" value="${(user.lastName!'')}"
                               aria-invalid="<#if messagesPerField.existsError('lastName')>true</#if>"/>
                    </div>
                    <#if messagesPerField.existsError('lastName')>
                        <span id="input-error-lastname" class="nm-error" aria-live="polite">${kcSanitize(messagesPerField.get('lastName'))?no_esc}</span>
                    </#if>
                </div>
            </div>

            <div class="nm-btn-stack">
                <#if isAppInitiatedAction??>
                    <button class="nm-btn nm-btn-primary" type="submit">${msg("doSubmit")}</button>
                    <button class="nm-btn nm-btn-ghost" type="submit" name="cancel-aia" value="true">${msg("doCancel")}</button>
                <#else>
                    <button class="nm-btn nm-btn-primary" type="submit">${msg("doSubmit")}</button>
                </#if>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
