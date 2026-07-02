<#import "template.ftl" as layout>
<#import "user-profile-commons.ftl" as userProfileCommons>
<@layout.registrationLayout displayMessage=messagesPerField.exists('global') displayRequiredFields=true; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("loginIdpReviewProfileTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-idp-review-profile-form" class="nm-form" action="${url.loginAction}" method="post">

            <@userProfileCommons.userProfileFormFields/>

            <div class="nm-btn-stack">
                <button class="nm-btn nm-btn-primary" type="submit">${msg("doSubmit")}</button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
