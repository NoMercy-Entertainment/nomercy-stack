<#import "template.ftl" as layout>
<#import "user-profile-commons.ftl" as userProfileCommons>
<@layout.registrationLayout displayMessage=messagesPerField.exists('global') displayRequiredFields=true; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("loginProfileTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-update-profile-form" class="nm-form" action="${url.loginAction}" method="post">

            <@userProfileCommons.userProfileFormFields/>

            <div class="nm-btn-stack">
                <#if isAppInitiatedAction??>
                    <button class="nm-btn nm-btn-primary" type="submit">${msg("doSubmit")}</button>
                    <button class="nm-btn nm-btn-ghost" type="submit" name="cancel-aia" value="true" formnovalidate>${msg("doCancel")}</button>
                <#else>
                    <button class="nm-btn nm-btn-primary" type="submit">${msg("doSubmit")}</button>
                </#if>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
