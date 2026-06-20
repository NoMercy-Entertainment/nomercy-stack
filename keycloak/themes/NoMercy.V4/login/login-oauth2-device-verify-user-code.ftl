<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("oauth2DeviceVerificationTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-user-verify-device-user-code-form" class="nm-form" action="${url.oauth2DeviceVerificationAction}" method="post">
            <div class="nm-fields">
                <div class="nm-field">
                    <label for="device-user-code">${msg("verifyOAuth2DeviceUserCode")}</label>
                    <div class="nm-input">
                        <input id="device-user-code" name="device_user_code" autocomplete="off" type="text" autofocus />
                    </div>
                </div>
            </div>

            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" type="submit">${msg("doSubmit")}</button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
