<#import "template.ftl" as layout>
<@layout.registrationLayout; section>
    <#if section = "header">
        <span class="nm-head">
            <span class="nm-head__title">${msg("confirmLinkIdpTitle")}</span>
        </span>
    <#elseif section = "form">
        <form id="kc-register-form" class="nm-form" action="${url.loginAction}" method="post">
            <div class="nm-btn-stack">
                <button type="submit" class="nm-btn nm-btn-ghost" name="submitAction" id="updateProfile" value="updateProfile">${msg("confirmLinkIdpReviewProfile")}</button>
                <button type="submit" class="nm-btn nm-btn-primary" name="submitAction" id="linkAccount" value="linkAccount">${msg("confirmLinkIdpContinue", idpDisplayName)}</button>
            </div>
        </form>
    </#if>
</@layout.registrationLayout>
